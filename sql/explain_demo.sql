-- Read-only execution-plan examples. Seed data is intentionally tiny.
ANALYZE employee;
ANALYZE enrollment;
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM employee WHERE department_id=1;
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM enrollment WHERE session_id=6 AND status<>'Cancelled';
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM training_session WHERE start_date>CURRENT_DATE ORDER BY start_date;
-- A sequential scan is often optimal for 20/30 rows. Compare costs and actual rows.
-- Diagnostic only, rollback restores planner settings:
BEGIN;
SET LOCAL enable_seqscan=off;
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM employee WHERE department_id=1;
ROLLBACK;
-- Do not disable sequential scans in the application.
