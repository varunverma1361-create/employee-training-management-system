# Entity relationship model

```mermaid
erDiagram
 department ||--o{ employee : employs
 training_program ||--o{ training_session : schedules
 trainer ||--o{ training_session : teaches
 employee ||--o{ enrollment : registers
 training_session ||--o{ enrollment : contains
 enrollment ||--o| training_result : evaluates
 department {
  int department_id PK
  varchar department_name UK
  varchar location
 }
 employee {
  int employee_id PK
  varchar employee_name
  varchar email UK
  int department_id FK
  varchar designation
  date joining_date
 }
 trainer {
  int trainer_id PK
  varchar trainer_name
  varchar email UK
  varchar specialization
 }
 training_program {
  int program_id PK
  varchar title
  text description
  int duration_hours
 }
 training_session {
  int session_id PK
  int program_id FK
  int trainer_id FK
  date start_date
  date end_date
  int capacity
 }
 enrollment {
  int enrollment_id PK
  int employee_id FK
  int session_id FK
  date enrollment_date
  varchar status
 }
 training_result {
  int result_id PK
  int enrollment_id FK,UK
  numeric score
  varchar completion_status
  text feedback
 }
 audit_log {
  bigint log_id PK
  varchar table_name
  int record_id
  varchar operation
  jsonb old_data
  jsonb new_data
  timestamptz changed_at
 }
```

All child FKs are NOT NULL: each employee must participate in exactly one
department; each session must have exactly one program and trainer; each enrollment
must have exactly one employee and session; each result must reference one enrollment.
Parent participation is optional (zero or many children). An enrollment may have
zero or one result, and that result requires Completed status. Employee–session
is M:N resolved by enrollment, with UNIQUE(employee_id,session_id).
All FKs use ON DELETE RESTRICT and ON UPDATE RESTRICT. IDs are identity columns.
Audit records have no FK: historical snapshots survive source record deletion.
The polymorphic table_name/record_id reference describes provenance only.
Nullable attributes: location, designation, specialization, description, feedback,
old_data, new_data, changed_at (defaulted). All other scalar attributes are required.
