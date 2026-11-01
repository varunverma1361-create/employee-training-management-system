-- GENERATED REFERENCE ONLY. Apply prisma migrations, never these copies.
-- Authoritative migration: schema, constraints, functions, triggers, views, indexes.
-- SECTION schema
CREATE TABLE department (
 department_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 department_name VARCHAR(100) NOT NULL UNIQUE, location VARCHAR(100)
);
CREATE TABLE employee (
 employee_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 employee_name VARCHAR(100) NOT NULL, email VARCHAR(150) NOT NULL UNIQUE,
 department_id INTEGER NOT NULL REFERENCES department ON DELETE RESTRICT ON UPDATE RESTRICT,
 designation VARCHAR(100), joining_date DATE NOT NULL DEFAULT CURRENT_DATE
);
CREATE TABLE trainer (
 trainer_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 trainer_name VARCHAR(100) NOT NULL, email VARCHAR(150) NOT NULL UNIQUE, specialization VARCHAR(150)
);
CREATE TABLE training_program (
 program_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 title VARCHAR(150) NOT NULL, description TEXT,
 duration_hours INTEGER NOT NULL CHECK (duration_hours > 0)
);
CREATE TABLE training_session (
 session_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 program_id INTEGER NOT NULL REFERENCES training_program ON DELETE RESTRICT ON UPDATE RESTRICT,
 trainer_id INTEGER NOT NULL REFERENCES trainer ON DELETE RESTRICT ON UPDATE RESTRICT,
 start_date DATE NOT NULL, end_date DATE NOT NULL,
 capacity INTEGER NOT NULL CHECK (capacity > 0), CHECK (end_date >= start_date)
);
CREATE TABLE enrollment (
 enrollment_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 employee_id INTEGER NOT NULL REFERENCES employee ON DELETE RESTRICT ON UPDATE RESTRICT,
 session_id INTEGER NOT NULL REFERENCES training_session ON DELETE RESTRICT ON UPDATE RESTRICT,
 enrollment_date DATE NOT NULL DEFAULT CURRENT_DATE,
 status VARCHAR(20) NOT NULL DEFAULT 'Enrolled' CHECK (status IN ('Enrolled','Cancelled','Completed')),
 UNIQUE(employee_id,session_id)
);
CREATE TABLE training_result (
 result_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 enrollment_id INTEGER NOT NULL UNIQUE REFERENCES enrollment ON DELETE RESTRICT ON UPDATE RESTRICT,
 score NUMERIC(5,2) NOT NULL CHECK (score BETWEEN 0 AND 100),
 completion_status VARCHAR(20) NOT NULL CHECK (completion_status IN ('Passed','Failed')), feedback TEXT
);
CREATE TABLE audit_log (
 log_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 table_name VARCHAR(100) NOT NULL, record_id INTEGER NOT NULL,
 operation VARCHAR(10) NOT NULL CHECK(operation IN ('INSERT','UPDATE','DELETE')),
 old_data JSONB, new_data JSONB, changed_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
-- SECTION functions
-- A small lab-wide transaction mutex gives direct DML and functions the same
-- lock order: advisory guard -> session row -> enrollment row. This deliberately
-- serializes training writes, including multi-row DML, for simple reliable demos.
CREATE FUNCTION training_write_guard() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
 IF current_setting('transaction_isolation') <> 'read committed' THEN
  RAISE EXCEPTION 'Training writes require READ COMMITTED isolation' USING ERRCODE='25000';
 END IF;
 PERFORM pg_advisory_xact_lock(72401);
 RETURN NULL;
END $$;

CREATE FUNCTION enroll_employee(p_employee_id INTEGER, p_session_id INTEGER)
RETURNS INTEGER LANGUAGE plpgsql AS $$
DECLARE s training_session%ROWTYPE; e enrollment%ROWTYPE; answer INTEGER;
BEGIN
 IF current_setting('transaction_isolation') <> 'read committed' THEN
  RAISE EXCEPTION 'Enrollment requires READ COMMITTED isolation' USING ERRCODE='25000';
 END IF;
 PERFORM pg_advisory_xact_lock(72401);
 PERFORM 1 FROM employee WHERE employee_id=p_employee_id FOR KEY SHARE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Employee does not exist' USING ERRCODE='23503'; END IF;
 SELECT * INTO s FROM training_session WHERE session_id=p_session_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Session does not exist' USING ERRCODE='23503'; END IF;
 IF s.start_date <= CURRENT_DATE THEN RAISE EXCEPTION 'Enrollment closes when a session starts' USING ERRCODE='23514'; END IF;
 SELECT * INTO e FROM enrollment WHERE employee_id=p_employee_id AND session_id=p_session_id FOR UPDATE;
 IF FOUND AND e.status <> 'Cancelled' THEN RAISE EXCEPTION 'Employee already enrolled' USING ERRCODE='23505'; END IF;
 IF (SELECT count(*) FROM enrollment WHERE session_id=p_session_id AND status <> 'Cancelled') >= s.capacity
 THEN RAISE EXCEPTION 'Session is full' USING ERRCODE='23514'; END IF;
 IF e.enrollment_id IS NOT NULL THEN
  UPDATE enrollment SET status='Enrolled',enrollment_date=CURRENT_DATE WHERE enrollment_id=e.enrollment_id RETURNING enrollment_id INTO answer;
 ELSE
  INSERT INTO enrollment(employee_id,session_id) VALUES(p_employee_id,p_session_id) RETURNING enrollment_id INTO answer;
 END IF;
 RETURN answer;
END $$;

CREATE FUNCTION record_training_result(p_enrollment_id INTEGER,p_score NUMERIC,p_completion_status VARCHAR,p_feedback TEXT)
RETURNS training_result LANGUAGE plpgsql AS $$
DECLARE e enrollment%ROWTYPE; answer training_result%ROWTYPE;
BEGIN
 PERFORM pg_advisory_xact_lock(72401);
 SELECT * INTO e FROM enrollment WHERE enrollment_id=p_enrollment_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Enrollment does not exist' USING ERRCODE='23503'; END IF;
 IF e.status <> 'Completed' THEN RAISE EXCEPTION 'Only completed enrollments can receive results' USING ERRCODE='23514'; END IF;
 INSERT INTO training_result(enrollment_id,score,completion_status,feedback)
 VALUES(p_enrollment_id,p_score,p_completion_status,p_feedback) RETURNING * INTO answer;
 RETURN answer;
EXCEPTION WHEN unique_violation THEN
 RAISE EXCEPTION 'This enrollment already has a result' USING ERRCODE='23505';
END $$;
-- SECTION triggers
CREATE TRIGGER a_training_guard BEFORE INSERT OR UPDATE OR DELETE ON training_session FOR EACH STATEMENT EXECUTE FUNCTION training_write_guard();
CREATE TRIGGER a_enrollment_guard BEFORE INSERT OR UPDATE OR DELETE ON enrollment FOR EACH STATEMENT EXECUTE FUNCTION training_write_guard();
CREATE TRIGGER a_result_guard BEFORE INSERT OR UPDATE OR DELETE ON training_result FOR EACH STATEMENT EXECUTE FUNCTION training_write_guard();

CREATE FUNCTION validate_enrollment() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE s training_session%ROWTYPE; activating BOOLEAN;
BEGIN
 IF TG_OP='DELETE' THEN RAISE EXCEPTION 'Cancel enrollments to preserve history' USING ERRCODE='23514'; END IF;
 IF TG_OP='UPDATE' THEN
  IF (NEW.employee_id,NEW.session_id,NEW.enrollment_id) IS DISTINCT FROM (OLD.employee_id,OLD.session_id,OLD.enrollment_id)
  THEN RAISE EXCEPTION 'Enrollment identity cannot be changed' USING ERRCODE='23514'; END IF;
  IF OLD.status='Completed' AND NEW.status<>'Completed' THEN RAISE EXCEPTION 'Completed enrollments are final' USING ERRCODE='23514'; END IF;
  IF OLD.status='Cancelled' AND NEW.status='Completed' THEN RAISE EXCEPTION 'Reactivate before completing training' USING ERRCODE='23514'; END IF;
 END IF;
 SELECT * INTO s FROM training_session WHERE session_id=NEW.session_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Session does not exist' USING ERRCODE='23503'; END IF;
 activating := TG_OP='INSERT';
 IF TG_OP='UPDATE' THEN activating := OLD.status='Cancelled' AND NEW.status<>'Cancelled'; END IF;
 IF TG_OP='INSERT' AND NEW.status<>'Enrolled' THEN RAISE EXCEPTION 'New enrollment must start as Enrolled' USING ERRCODE='23514'; END IF;
 IF activating THEN
  IF s.start_date<=CURRENT_DATE THEN RAISE EXCEPTION 'Enrollment closes when a session starts' USING ERRCODE='23514'; END IF;
  IF (SELECT count(*) FROM enrollment WHERE session_id=NEW.session_id AND status<>'Cancelled' AND enrollment_id<>NEW.enrollment_id)>=s.capacity
  THEN RAISE EXCEPTION 'Session is full' USING ERRCODE='23514'; END IF;
  NEW.enrollment_date:=CURRENT_DATE;
 END IF;
 IF NEW.status='Completed' AND s.end_date>CURRENT_DATE THEN RAISE EXCEPTION 'Training can only be completed on or after the end date' USING ERRCODE='23514'; END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER validate_enrollment_row BEFORE INSERT OR UPDATE OR DELETE ON enrollment FOR EACH ROW EXECUTE FUNCTION validate_enrollment();

CREATE FUNCTION validate_capacity() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
 IF NEW.capacity < (SELECT count(*) FROM enrollment WHERE session_id=OLD.session_id AND status<>'Cancelled')
 THEN RAISE EXCEPTION 'Capacity cannot be below occupied seats' USING ERRCODE='23514'; END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER validate_session_capacity BEFORE UPDATE ON training_session FOR EACH ROW EXECUTE FUNCTION validate_capacity();

CREATE FUNCTION validate_result() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE state VARCHAR;
BEGIN
 SELECT status INTO state FROM enrollment WHERE enrollment_id=NEW.enrollment_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Enrollment does not exist' USING ERRCODE='23503'; END IF;
 IF state<>'Completed' THEN RAISE EXCEPTION 'Only completed enrollments can receive results' USING ERRCODE='23514'; END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER validate_training_result BEFORE INSERT OR UPDATE ON training_result FOR EACH ROW EXECUTE FUNCTION validate_result();

CREATE FUNCTION audit_changes() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE before_row JSONB; after_row JSONB; key_name TEXT;
BEGIN
 key_name:=TG_ARGV[0];
 IF TG_OP<>'INSERT' THEN before_row:=to_jsonb(OLD); END IF;
 IF TG_OP<>'DELETE' THEN after_row:=to_jsonb(NEW); END IF;
 INSERT INTO audit_log(table_name,record_id,operation,old_data,new_data)
 VALUES(TG_TABLE_NAME,coalesce(after_row->>key_name,before_row->>key_name)::INTEGER,TG_OP,before_row,after_row);
 RETURN NULL;
END $$;
CREATE TRIGGER audit_employee AFTER INSERT OR UPDATE OR DELETE ON employee FOR EACH ROW EXECUTE FUNCTION audit_changes('employee_id');
CREATE TRIGGER audit_enrollment AFTER INSERT OR UPDATE OR DELETE ON enrollment FOR EACH ROW EXECUTE FUNCTION audit_changes('enrollment_id');
-- SECTION views
CREATE VIEW employee_training_summary AS
SELECT e.employee_id,e.employee_name,d.department_name,p.program_id,p.title AS program,
 s.session_id,s.start_date,s.end_date,t.trainer_name,n.enrollment_id,n.status,r.score,r.completion_status,r.feedback
FROM employee e JOIN department d USING(department_id)
JOIN enrollment n USING(employee_id) JOIN training_session s USING(session_id)
JOIN training_program p USING(program_id) JOIN trainer t USING(trainer_id)
LEFT JOIN training_result r USING(enrollment_id);

-- Independent aggregation prevents fan-out from inflating employee counts.
CREATE VIEW department_training_statistics AS
SELECT d.department_id,d.department_name,
 (SELECT count(*) FROM employee e WHERE e.department_id=d.department_id) AS total_employees,
 (SELECT count(DISTINCT e.employee_id) FROM employee e JOIN enrollment n USING(employee_id)
  WHERE e.department_id=d.department_id AND n.status<>'Cancelled') AS employees_enrolled,
 (SELECT count(*) FROM employee e JOIN enrollment n USING(employee_id)
  WHERE e.department_id=d.department_id AND n.status='Completed') AS completed_enrollments,
 (SELECT round(avg(r.score),2) FROM employee e JOIN enrollment n USING(employee_id)
  JOIN training_result r USING(enrollment_id) WHERE e.department_id=d.department_id) AS average_score
FROM department d;

CREATE VIEW training_session_availability AS
SELECT s.session_id,p.title,t.trainer_name,s.start_date,s.end_date,s.capacity,
 count(n.enrollment_id) FILTER(WHERE n.status<>'Cancelled') AS active_enrollments,
 s.capacity-count(n.enrollment_id) FILTER(WHERE n.status<>'Cancelled') AS available_seats
FROM training_session s JOIN training_program p USING(program_id) JOIN trainer t USING(trainer_id)
LEFT JOIN enrollment n USING(session_id)
GROUP BY s.session_id,p.title,t.trainer_name;
-- SECTION indexes
CREATE INDEX employee_department_id_idx ON employee(department_id);
CREATE INDEX training_session_program_id_idx ON training_session(program_id);
CREATE INDEX training_session_trainer_id_idx ON training_session(trainer_id);
CREATE INDEX training_session_start_date_idx ON training_session(start_date);
CREATE INDEX enrollment_session_id_idx ON enrollment(session_id);
-- UNIQUE(employee_id,session_id) already supports employee_id lookups.
