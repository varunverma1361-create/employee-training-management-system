-- GENERATED REFERENCE ONLY. Apply prisma migrations, never these copies.
CREATE INDEX employee_department_id_idx ON employee(department_id);
CREATE INDEX training_session_program_id_idx ON training_session(program_id);
CREATE INDEX training_session_trainer_id_idx ON training_session(trainer_id);
CREATE INDEX training_session_start_date_idx ON training_session(start_date);
CREATE INDEX enrollment_session_id_idx ON enrollment(session_id);
-- UNIQUE(employee_id,session_id) already supports employee_id lookups.
