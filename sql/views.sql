-- GENERATED REFERENCE ONLY. Apply prisma migrations, never these copies.
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
