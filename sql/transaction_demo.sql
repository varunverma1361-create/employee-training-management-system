-- Run on the lab database with psql. Everything here is rolled back.
BEGIN;
INSERT INTO department(department_name) VALUES('Rollback demonstration');
SAVEPOINT before_failure;
INSERT INTO training_program(title,duration_hours) VALUES('Invalid demo',0);
-- psql reports SQLSTATE 23514; rollback recovers this transaction.
ROLLBACK TO SAVEPOINT before_failure;
SELECT * FROM department WHERE department_name='Rollback demonstration';
ROLLBACK;
SELECT count(*) AS must_be_zero FROM department WHERE department_name='Rollback demonstration';

-- Durable transaction example (uncomment intentionally):
-- BEGIN;
-- SELECT enroll_employee(:employee_id,:session_id);
-- COMMIT;
-- For two-connection last-seat and capacity-race tests: npm run test:db.
-- Reproduce manually using fixture IDs in TWO terminals:
-- A: BEGIN; SELECT enroll_employee(employee_a, future_one_seat_session);
-- B: BEGIN; SELECT enroll_employee(employee_b, same_session); -- waits
-- A: COMMIT;
-- B: -- Session is full (23514); ROLLBACK;
