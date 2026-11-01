# Database implementation map

The authoritative source is `prisma/migrations/202610280001_foundation/migration.sql`.
`npm run db:migrate` applies it; `npm run sql:export` regenerates reference SQL.
Never apply the reference copies as additional migrations or use db push to set up
this database: Prisma alone cannot recreate CHECKs, views, functions and triggers.

| Concept | Implementation |
|---|---|
| Relational model and M:N | Eight tables; enrollment resolves employee/session |
| PK and identity | GENERATED ALWAYS AS IDENTITY for every PK |
| Candidate keys | employee/trainer email, department name, enrollment pair, result enrollment |
| Referential integrity | Explicit RESTRICT on all FK updates/deletes |
| Domain constraints | Positive capacity/duration, date order, score range, status lists |
| Defaults | PostgreSQL CURRENT_DATE; enrollment status; audit CURRENT_TIMESTAMP |
| Triggers | validate_enrollment, validate_capacity, validate_result, audit_changes |
| Stored functions | enroll_employee; record_training_result |
| JSONB | to_jsonb(OLD/NEW) audit snapshots |
| Views and joins | Three SQL views, API reports route |
| Subqueries and grouping | department view; 17 queries in sql/reports.sql |
| Transactions | Seed transaction, rollback-only demos, two-client tests |
| Concurrency | Advisory lock followed by FOR UPDATE; see TRANSACTIONS.md |
| Indexes | Five secondary FK/date indexes plus PK/UNIQUE indexes |
| ORM vs SQL | Prisma for CRUD; parameterized pg queries for functions/views |

Example: `SELECT enroll_employee(1,6);` acquires locks and calls enrollment
INSERT/UPDATE; that statement invokes validation and audit triggers. A failure
rolls back the entire statement. API values use `$1`, `$2`, etc.; model and field
names come from a fixed allowlist, never user-generated SQL.

Index decisions: employee.department_id supports department filters and parent
FK checks; session.program_id/trainer_id support reports and FK lookups;
enrollment.session_id supports seat counts; start_date supports upcoming sessions.
The unique index (employee_id,session_id) already covers employee_id as its left
prefix. training_result.enrollment_id already has a unique index. No redundant
indexes are added. Run `sql/explain_demo.sql` and compare estimated cost, actual
rows, time, and buffers. Small datasets often appropriately use sequential scans.

Audit has no write API. This is a local admin lab with no authentication: it is
not intended to be publicly accessible. The database owner can modify schema/data;
the UI read-only policy is not a security boundary against the database owner.
