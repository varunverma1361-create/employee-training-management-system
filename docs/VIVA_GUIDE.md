# Viva guide

ETMS manages departments, employees, trainers, reusable programs, scheduled
sessions, enrollment, evaluations and an automatic audit trail. Next.js provides
the interface; Route Handlers use Prisma for CRUD and pg for parameterized SQL.
PostgreSQL owns critical business rules. See ER_DIAGRAM.md for the eight entities
and participation, NORMALIZATION.md for the formal dependency proof,
DATABASE_CONCEPTS.md for implementation locations, and TRANSACTIONS.md for locks.

Suggested walkthrough: Overview counts → create a department/employee → schedule
a future session → enroll → cancel/reactivate → inspect Audit logs → Reports. Use seeded past completions to inspect evaluations; new results require a completed enrollment without an existing result.
future training cannot be marked completed before its end date. Show the actual
migration functions and triggers, then run test:db for the two-client race.

## 1. Why use a database function for booking?
It validates and locks within one atomic database operation, shared by every caller.

## 2. What prevents duplicate enrollment?
UNIQUE(employee_id,session_id), even when the earlier record was cancelled.

## 3. How does reactivation work?
enroll_employee updates the existing cancelled row after eligibility and capacity checks.

## 4. Why is enrollment a separate entity?
It resolves the M:N relationship and holds enrollment-specific date/status.

## 5. What does Completed mean?
Attendance/training completion, independent of Passed or Failed evaluation.

## 6. Can a cancelled enrollment receive a result?
No, the result trigger locks its enrollment and requires Completed.

## 7. What is 3NF?
For every nontrivial X -> A, X is a superkey or A is prime.

## 8. Give a partial dependency.
In flattened (employee_id,session_id), employee_name depends only on employee_id.

## 9. Give a transitive dependency.
employee_id -> department_id -> department_name; department is decomposed.

## 10. What is a candidate key?
A minimal set determining the row, such as employee.email or the enrollment pair.

## 11. Why RESTRICT deletion?
It prevents removing parent records that are needed by training history.

## 12. What is a CHECK constraint?
A database predicate restricting row values, such as score BETWEEN 0 AND 100.

## 13. Why are NOT NULL checks separate?
CHECK accepts UNKNOWN for NULL; NOT NULL makes required values mandatory.

## 14. How are audit entries created?
AFTER row triggers write to_jsonb(OLD/NEW) within the same transaction.

## 15. Do rollback operations leave audit records?
No, audit writes roll back too, but identity sequences can have gaps.

## 16. What is a view?
A stored SELECT definition queried like a relation; these views are not materialized.

## 17. Why a LEFT JOIN to results?
It preserves enrollments with no evaluation.

## 18. Why COUNT DISTINCT?
It counts employees once even if each has several enrollments.

## 19. What does FOR UPDATE do?
It locks selected rows against conflicting writes until transaction end.

## 20. How is overbooking prevented?
Consistent guard/row locks, followed by counting non-cancelled enrollments before activation.

## 21. Why the advisory guard?
Statement triggers acquire it before row locks, coordinating arbitrary direct DML with functions.

## 22. What is the lock tradeoff?
Training writes across unrelated sessions are serialized, reducing throughput for simpler correctness.

## 23. What isolation is used?
READ COMMITTED, where successive statements can see newly committed changes.

## 24. What is atomicity?
All operations in a transaction succeed together or are rolled back together.

## 25. How is durability provided?
PostgreSQL WAL and normal commit settings, plus persistent database storage.

## 26. What if two people book the last seat?
The second waits, then sees full capacity and is rejected after the first commits.

## 27. What is a correlated subquery?
A subquery using values from the outer row; above-program-average scores demonstrate it.

## 28. Why not index enrollment.employee_id separately?
The existing employee_id,session_id unique index has the needed leading column.

## 29. Why might EXPLAIN show a sequential scan?
For tiny tables reading all pages can cost less than index traversal.

## 30. How is SQL injection avoided?
Values are bound parameters; routes accept fixed operations and allowlisted fields only.

## 31. Why not use Prisma db push?
It cannot reproduce all custom SQL objects; versioned migrations are authoritative.

## 32. Is pass/fail determined by score?
No universal threshold is declared; score and evaluation are separately validated domains.
