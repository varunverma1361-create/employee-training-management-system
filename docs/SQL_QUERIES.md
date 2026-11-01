# SQL query walkthrough

`sql/reports.sql` contains 17 executable, commented statements. Use psql or a
PostgreSQL GUI to execute them. IDs in examples assume a fresh seed; use the UI
to discover IDs if sequences advanced. Queries 1–15 cover the requested reports;
16 adds LIKE and 17 correlated EXISTS. Query 9 includes SUM/AVG/MIN/MAX, query 11
HAVING and COUNT DISTINCT, query 10 a correlated average by program.

Expected results on an untouched fresh seed:

| Query / report | Expected result |
|---|---|
| Employees with departments | 20 rows, 4 employees per department |
| Never enrolled | Reva Kulkarni and Aditya Jain |
| Attendance completed | 15 distinct employees |
| Program with no sessions | Workplace wellbeing |
| Trainer with no sessions | Ritu Sood |
| Highest score | Neil Bhat, 90, Passed |
| Results | 15; scores 48,51,...,90; 11 Passed and 4 Failed |
| Summary view | 30 rows; 15 scores present, 15 NULL |
| Department statistics | 5 rows, total_employees=4 each; completed_enrollments=3 each |
| Session availability | 12 rows; sixth session full, 3 occupied seats |

Department statistics uses separate correlated aggregates so joining an employee
with multiple enrollments cannot multiply the employee count. employees_enrolled
means distinct employees with at least one non-cancelled enrollment; cancelled-only
history is excluded. average_score ignores NULLs and includes Passed/Failed.

The summary view joins employee, department, enrollment, session, program and
trainer; LEFT JOIN results preserves enrollments without evaluations. Unenrolled
employees appear in query 7, not the enrollment-grained summary view.
Program participation in the Reports page includes all enrollment history;
session occupied counts exclude Cancelled and include Completed.
Database integration tests execute all 17 report statements, and assert the
three views against controlled fixtures with known counts and average 70.
