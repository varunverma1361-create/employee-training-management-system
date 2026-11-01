-- GENERATED REFERENCE ONLY. Apply prisma migrations, never these copies.
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
