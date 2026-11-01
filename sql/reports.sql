-- Run with psql -d etms -f sql/reports.sql. Fixed example IDs may differ after rollbacks.
-- 1 SELECT, INNER JOIN, ORDER BY: all employees and their departments.
SELECT e.employee_id,e.employee_name,d.department_name FROM employee e JOIN department d USING(department_id) ORDER BY e.employee_name;
-- 2 WHERE: participants for an example session.
SELECT e.employee_name,n.status FROM employee e JOIN enrollment n USING(employee_id) WHERE n.session_id=1;
-- 3 BETWEEN and a trainer filter.
SELECT * FROM training_session WHERE trainer_id=1 AND start_date BETWEEN CURRENT_DATE-90 AND CURRENT_DATE+90;
-- 4 LEFT JOIN and COUNT: include empty departments.
SELECT d.department_name,count(e.employee_id) FROM department d LEFT JOIN employee e USING(department_id) GROUP BY d.department_id;
-- 5 Multi-table joins: enrollment counts per program, including cancelled.
SELECT p.title,count(n.enrollment_id) FROM training_program p LEFT JOIN training_session s USING(program_id) LEFT JOIN enrollment n USING(session_id) GROUP BY p.program_id;
-- 6 IN: completed employees (attendance, regardless of evaluation).
SELECT * FROM employee WHERE employee_id IN(SELECT employee_id FROM enrollment WHERE status='Completed');
-- 7 Correlated NOT EXISTS: employees with no enrollment history.
SELECT * FROM employee e WHERE NOT EXISTS(SELECT 1 FROM enrollment n WHERE n.employee_id=e.employee_id);
-- 8 View and WHERE: only future sessions that are open for enrollment.
SELECT * FROM training_session_availability WHERE available_seats>0 AND start_date>CURRENT_DATE ORDER BY start_date;
-- 9 AVG, MIN, MAX, SUM: score distribution by program.
SELECT p.title,round(avg(r.score),2) AS average,min(r.score),max(r.score),sum(r.score) FROM training_program p JOIN training_session s USING(program_id) JOIN enrollment n USING(session_id) JOIN training_result r USING(enrollment_id) GROUP BY p.program_id;
-- 10 Correlated subquery: above own program average, across sessions.
SELECT * FROM employee_training_summary h WHERE h.score>(SELECT avg(h2.score) FROM employee_training_summary h2 WHERE h2.program_id=h.program_id);
-- 11 HAVING and COUNT DISTINCT: departments with over 2 active/completed participants.
SELECT d.department_name,count(DISTINCT e.employee_id) FROM department d JOIN employee e USING(department_id) JOIN enrollment n USING(employee_id) WHERE n.status<>'Cancelled' GROUP BY d.department_id HAVING count(DISTINCT e.employee_id)>2;
-- 12 LEFT JOIN / IS NULL: programs with no sessions.
SELECT p.title FROM training_program p LEFT JOIN training_session s USING(program_id) WHERE s.session_id IS NULL;
-- 13 NOT EXISTS: trainers without scheduled sessions.
SELECT t.trainer_name FROM trainer t WHERE NOT EXISTS(SELECT 1 FROM training_session s WHERE s.trainer_id=t.trainer_id);
-- 14 Scalar subquery / MAX: highest score, retaining ties.
SELECT * FROM employee_training_summary WHERE score=(SELECT max(score) FROM training_result);
-- 15 Complete history for one employee: multi-table view.
SELECT * FROM employee_training_summary WHERE employee_id=1 ORDER BY start_date;
-- 16 LIKE: text search (ILIKE can be used for case-insensitivity).
SELECT * FROM employee WHERE employee_name LIKE 'A%';
-- 17 EXISTS: departments with at least one failed evaluation.
SELECT d.department_name FROM department d WHERE EXISTS(SELECT 1 FROM employee e JOIN enrollment n USING(employee_id) JOIN training_result r USING(enrollment_id) WHERE e.department_id=d.department_id AND r.completion_status='Failed');
