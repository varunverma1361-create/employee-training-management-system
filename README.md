# Employee Training Management System

A complete university DBMS lab application. The interface is deliberately simple;
PostgreSQL implements integrity, concurrency, stored functions, triggers, views,
audit logging and reports. All application records come from PostgreSQL.

## Stack and prerequisites

- Node.js 20.9+ (22/24 LTS recommended), npm or pnpm
- Next.js 16 App Router, React 19, TypeScript, Tailwind CSS 4
- PostgreSQL 17 recommended (local, Docker, or Neon)
- Prisma 6.19 for CRUD and migrations; pg for parameterized SQL
- No authentication or external API dependencies

Exact resolved dependency versions are recorded in pnpm-lock.yaml. With pnpm,
use `pnpm install --frozen-lockfile`. npm can also install from package.json.

## Quick start

```sh
npm install
# Copy .env.example to .env (PowerShell: Copy-Item .env.example .env)
docker compose up -d
npm run db:generate
npm run db:migrate
npm run db:seed
npm run dev
```

Open http://127.0.0.1:3000. Docker is optional: point DATABASE_URL at an existing
PostgreSQL database instead. The compose file uses a local lab password and a
persistent named volume. Do not run compose down --volumes unless intentionally
discarding the lab database. If port 5432 is occupied, change the host port and URL.

For Neon use its direct connection URL (with sslmode=require); transaction-pooling
connections are unsuitable for the multi-statement demos/tests. Create an empty
database, set DATABASE_URL in .env, and run the same migration/seed commands.
Use a direct connection for migrations. Never commit credentials.

## Environment

`DATABASE_URL` is required, for example
`postgresql://etms:etms_local_password@localhost:5432/etms?schema=public`.
The app uses public schema; the pg helper removes Prisma's schema query parameter.
`ENABLE_DBMS_DEMOS=true` enables the fixed rollback-only demonstrations.
`TEST_BASE_URL` optionally changes the API test server (default port 3000).
This is a local admin lab: run on the loopback interface as supplied.

## Migrations and seed

`prisma/migrations/202610280001_foundation/migration.sql` is the only schema setup
source. It includes all eight tables, identity PKs, constraints, FKs, five secondary
indexes, three views, stored functions and triggers. Prisma schema mirrors the
tables; PostgreSQL additionally enforces custom rules. Use `prisma migrate deploy`,
never `prisma db push`, to reproduce this project. `npm run sql:export` generates
inspection-only SQL copies; do not apply those on top of the migration.

The transactional seed creates 5 departments, 20 fictional employees, 5 trainers,
8 programs, 12 sessions, 30 enrollments and 15 evaluations. It creates enrollments
while sessions are future, moves five sample sessions into the past, and marks
those enrollments completed. This exercises normal triggers without disabling them.
Running it again detects the Engineering seed marker and leaves data untouched.
It refuses to mix seed data into an existing non-seed employee dataset. The seed
is an initial fixture loader, not a repair or refresh tool. Dates are relative to
PostgreSQL CURRENT_DATE; future sessions naturally become ineligible over time.

## Application

Sidebar pages: dashboard, departments, employees, trainers, programs, sessions,
enrollments, results, reports, audit, DBMS demonstrations. Core catalog pages
provide add/edit/delete with database-protected history. Employees support name
and department filters; enrollments support employee/session filters. Sessions
show occupied and available seats. Enrollments use enroll_employee, including
reactivation, and support cancel/complete. Completed attendance is terminal and
can only be set on/after the end date. Results use record_training_result and
preserve one evaluation per completed enrollment. Reports query actual views.
Audit logs show the newest 200 records and JSONB snapshots; no write API exists.

APIs: GET/POST/PATCH/DELETE `/api/{resource}` for allowlisted catalog resources;
enrollment POST books/reactivates and PATCH cancels/completes; results POST records;
audit GET only. `/api/dashboard`, `/api/reports`, `/api/session-detail` are read-only.
`/api/demos` accepts only eight numbered, predefined operations, never arbitrary SQL.

## Verification

```sh
npm run typecheck
npm run build
npm run test:db
# With npm run dev or npm start running and ENABLE_DBMS_DEMOS=true:
npm run test:api
```

Database tests create a randomly named isolated schema, apply the authoritative
migration, and drop only that schema in finally. The connection needs CREATE
SCHEMA permission. They verify columns, constraints, CRUD, functions, triggers,
views, audit JSONB, rollback, transitions, and two independent-connection races.
API tests create/delete one isolated department, run all eight rollback-only demos,
read all pages/endpoints, and verify audit writes are rejected. Use a lab database.
See docs/VERIFICATION.md for checks actually run during implementation.

SQL demonstrations: `sql/reports.sql` (17 queries), `sql/transaction_demo.sql`
(BEGIN/COMMIT/ROLLBACK/SAVEPOINT), `sql/explain_demo.sql` (EXPLAIN ANALYZE).
The transaction script deliberately emits a constraint error before recovering
to a savepoint; run it in psql without ON_ERROR_STOP for that demonstration.

## Concurrency design

All training writes acquire advisory transaction lock 72401 before row locks;
booking also SELECTs the session FOR UPDATE. This intentionally serializes
training writes across sessions, allowing direct DML triggers and functions to
share lock order. Use READ COMMITTED. See docs/TRANSACTIONS.md for the rationale,
tradeoffs and last-seat reproduction. Cancelled rows free seats; Completed rows
remain counted. Enrollment deletion is rejected: cancel instead to retain history.

## Documentation

- docs/ER_DIAGRAM.md — complete Mermaid ER model and participation
- docs/NORMALIZATION.md — UNF through 3NF, FDs, keys and proof
- docs/DATABASE_CONCEPTS.md — SQL concepts and file map, index decisions
- docs/SQL_QUERIES.md — reports and expected seed results
- docs/TRANSACTIONS.md — ACID, locking and race demonstrations
- docs/VIVA_GUIDE.md — walkthrough and 32 viva questions
- docs/VERIFICATION.md — actual verification results and limitations

## Troubleshooting

Database unavailable: confirm PostgreSQL is running, URL credentials/port are
correct, and migrations were applied. Foreign-key deletion errors mean related
history must be retained. Started/full session booking errors are expected rules.
Completion before end date is rejected. Demo SQLSTATE 23505/23503/23514 responses
are expected proof of constraints. Identity gaps after failed inserts are normal.
If Prisma engines are blocked during installation, allow Prisma's engine download
and run `npm run db:generate`. An unconfigured nvm launcher must be set to a
supported Node version before running npm commands.
