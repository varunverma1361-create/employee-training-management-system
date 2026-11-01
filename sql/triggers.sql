-- GENERATED REFERENCE ONLY. Apply prisma migrations, never these copies.
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
