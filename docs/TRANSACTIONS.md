# Transactions and concurrency

Run `npm run test:db` against a local PostgreSQL database. It creates an isolated
random schema, applies the authoritative SQL migration, tests two independent
connections, and drops only its own schema. CREATE SCHEMA permission is required.
Do not run with a transaction-pooling URL; use a direct connection.

## Lock order and isolation
Default READ COMMITTED is used. The function first acquires transaction advisory
lock 72401, verifies the employee using FOR KEY SHARE, then locks training_session
using SELECT FOR UPDATE, and then the matching enrollment. BEFORE STATEMENT
triggers acquire the same advisory lock for direct session, enrollment and result
DML **before** row locks are acquired. The row trigger repeats the capacity/date
validation. Capacity updates participate in the same protocol.

The advisory guard is deliberately coarse: all training writes are serialized,
even across different sessions. This simplifies direct multi-row DML lock ordering
for a student project. Readers continue normally through MVCC. A production system
could restrict DML to procedures and use per-session locks for higher throughput.
The guard is transaction scoped and releases on COMMIT/ROLLBACK. VOLATILE PL/pgSQL
queries at READ COMMITTED see the committed state after the lock wait.
The guard rejects training writes at isolation levels other than READ COMMITTED
(SQLSTATE 25000). An earlier REPEATABLE READ snapshot could otherwise hide a
committed enrollment. The app and tests use READ COMMITTED.
Explicit user SQL that takes locks in a different order can still deadlock;
PostgreSQL aborts a victim (40P01), and the API asks the user to retry.

## Last-seat reproduction
The automated test commits a dedicated future one-seat session and two employees.
Connection A: BEGIN; SELECT enroll_employee(employee_a,session); (leave uncommitted).
Connection B: BEGIN; SELECT enroll_employee(employee_b,session); blocks on guard.
The test confirms B has not settled, then A COMMITs. B sees the seat occupied,
raises SQLSTATE 23514 and ROLLBACKs. An independent SELECT confirms exactly one
occupied seat. A second two-connection test races a direct enrollment INSERT
against a capacity reduction: the reduction waits, then fails.

## Atomicity
Functions execute inside the caller's transaction. A failure rolls back the
enrollment and its audit row. The demo API begins a transaction, inserts dedicated
fixtures and deliberately violates a CHECK; ROLLBACK removes every fixture.
Demo 8 verifies its inserted department count is zero afterward. Identity sequences
are nontransactional and may have gaps; gaps are expected.

## Consistency
PK/FK/UNIQUE/NOT NULL/CHECK constraints and validation triggers enforce legal
states. Cancelled seats do not count; completed attendance does occupy a seat.
Completed is terminal, cancellation cannot jump directly to completion, and
completion is permitted only on/after the session end date. Results require
completion and are at most one per enrollment.

## Isolation
Row locks and the shared guard serialize conflicting operations; MVCC lets
readers use committed snapshots. A transaction sees its own writes. Changes
to multiple records in seed/demo operations commit or roll back together.

## Durability
PostgreSQL's WAL persists successful commits under normal synchronous_commit
settings. Docker's named volume survives container restarts. Crash recovery is
an architectural explanation, not a crash test performed by this project.

See `sql/transaction_demo.sql` for BEGIN, SAVEPOINT, ROLLBACK and COMMIT examples.
Viva demos intentionally roll back even successful operations. Normal CRUD and
enrollment operations commit and persist. Audit logs contain only committed changes.
