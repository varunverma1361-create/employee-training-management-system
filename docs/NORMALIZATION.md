# Normalization proof

## UNF and anomalies
Begin with EmployeeTraining(employee_id, employee_name, email, department_id,
department_name, location, designation, joining_date, trainings={session_id,
program_id, title, description, duration_hours, trainer_id, trainer_name,
trainer_email, specialization, start_date, end_date, capacity, enrollment_date,
status, score, completion_status, feedback}). The trainings set repeats.
Updating a department location in many records can create inconsistent locations.
A trainer without employees cannot be inserted; deleting the last participant
could erase the only copy of a program. These are update, insertion, deletion anomalies.

## 1NF
Flatten the repeating group to one row per (employee_id, session_id). All values
are atomic for their domains. This relation's candidate key is that pair;
employee email plus session ID is an alternate candidate key. Employee details
depend only on employee_id, session details only on session_id: partial dependencies.
Training score is optional because an enrollment need not have an evaluation.

## 2NF
Separate Employee(employee_id, employee_name, email, department_id, department_name,
location, designation, joining_date), Session(session_id, program_id, title,
description, duration_hours, trainer_id, trainer_name, trainer_email,
specialization, start_date, end_date, capacity), Enrollment(employee_id,
session_id, enrollment_date, status, score, completion_status, feedback).
Every remaining non-key attribute depends on the whole candidate key.
Introduce enrollment_id as an alternate identifier, preserving UNIQUE(employee_id,session_id).

## 3NF
Remove Employee's transitive department_id -> department_name, location;
Session's program_id -> title, description, duration_hours; Session's trainer_id
-> trainer_name, trainer_email, specialization. Split optional evaluation into
TrainingResult with enrollment_id unique, ensuring one optional result.
This optional split expresses participation and keeps result validation local;
it is not necessary to claim that optional fields alone violate 3NF.

## Final relations, candidate keys and declared functional dependencies

For each row below, every candidate key determines **all** attributes in the
relation. The listed non-key attributes have no other declared determinants.
This assumes names, titles, designations, dates and locations have no hidden
uniqueness or business dependencies. A score does not determine pass/fail:
evaluators choose the outcome explicitly; no universal pass threshold is declared.

| Relation | Candidate keys (each separately) | Remaining attributes determined |
|---|---|---|
| department | department_id; department_name | location |
| employee | employee_id; email | employee_name, department_id, designation, joining_date |
| trainer | trainer_id; email | trainer_name, specialization |
| training_program | program_id | title, description, duration_hours |
| training_session | session_id | program_id, trainer_id, start_date, end_date, capacity |
| enrollment | enrollment_id; (employee_id, session_id) | enrollment_date, status |
| training_result | result_id; enrollment_id | score, completion_status, feedback |
| audit_log | log_id | table_name, record_id, operation, old_data, new_data, changed_at |

3NF requires that for every nontrivial FD X -> A, X is a superkey or A is prime.
Under the dependencies above every determinant is a candidate key (or its
superset), so all eight relations actually satisfy BCNF as well as 3NF.
Foreign keys express inclusion dependencies, not additional intra-table FDs.
Department and trainer names do not appear in employee/session records.

The decompositions are lossless: each shared department/program/trainer key
determines one entire side. Employee/session/enrollment joins use the corresponding
keys; optional results require LEFT JOIN. Original FDs are preserved in their
own relations and checked with PK/UNIQUE constraints. Results exist only for
completed enrollments through triggers, an inter-relation rule beyond normalization.

JSONB audit snapshots are deliberately historical domain values. They record
OLD/NEW state, not current copies to be maintained in sync. No dependencies
between fields inside snapshots are declared in the relational schema.
