import 'dotenv/config';import assert from 'node:assert/strict';import {readFile} from 'node:fs/promises';import {Pool,PoolClient} from 'pg';import {fixture} from './fixtures';
const url=new URL(process.env.DATABASE_URL!);url.searchParams.delete('schema');
const admin=new Pool({connectionString:url.toString()});const schema='etms_test_'+crypto.randomUUID().replaceAll('-','');
// Only this generated schema is created/dropped. Public data is never touched.
await admin.query(`CREATE SCHEMA "${schema}"`);
const pool=new Pool({connectionString:url.toString(),options:`-c search_path=${schema}`,max:5});
let passed=0;function pass(name:string){console.log('PASS',++passed,name);}
async function rejects(c:PoolClient,sql:string,values:unknown[],code:string){await c.query('SAVEPOINT expected_failure');let observed='';try{await c.query(sql,values)}catch(e){observed=(e as {code:string}).code}await c.query('ROLLBACK TO SAVEPOINT expected_failure');assert.equal(observed,code,sql);}
try{
 await pool.query(await readFile('prisma/migrations/202610280001_foundation/migration.sql','utf8'));
 const c=await pool.connect();await c.query('BEGIN');const f=await fixture(c);
 const tables=await c.query("SELECT table_name FROM information_schema.tables WHERE table_schema=$1 AND table_type='BASE TABLE'",[schema]);assert.equal(tables.rowCount,8);
 const expected:Record<string,string[]>={department:['department_id','department_name','location'],employee:['employee_id','employee_name','email','department_id','designation','joining_date'],trainer:['trainer_id','trainer_name','email','specialization'],training_program:['program_id','title','description','duration_hours'],training_session:['session_id','program_id','trainer_id','start_date','end_date','capacity'],enrollment:['enrollment_id','employee_id','session_id','enrollment_date','status'],training_result:['result_id','enrollment_id','score','completion_status','feedback'],audit_log:['log_id','table_name','record_id','operation','old_data','new_data','changed_at']};
 for(const[name,columns]of Object.entries(expected)){const actual=await c.query('SELECT column_name FROM information_schema.columns WHERE table_schema=$1 AND table_name=$2 ORDER BY ordinal_position',[schema,name]);assert.deepEqual(actual.rows.map(r=>r.column_name),columns);}
 pass('8 tables and all expected columns');
 await rejects(c,'INSERT INTO department(department_id,department_name) OVERRIDING SYSTEM VALUE VALUES($1,$2)',[f.dep,'Duplicate PK'],'23505');pass('primary key rejects duplicate');
 await rejects(c,"INSERT INTO employee(employee_name,email,department_id) VALUES('Orphan','orphan@example.test',-1)",[],'23503');pass('foreign key');
 await rejects(c,"INSERT INTO employee(employee_name,email,department_id) VALUES('Duplicate',$1,$2)",[f.employees[0].email,f.dep],'23505');pass('unique email');
 await rejects(c,"INSERT INTO training_program(title,duration_hours) VALUES('Bad',0)",[],'23514');
 await rejects(c,'UPDATE training_session SET capacity=0 WHERE session_id=$1',[f.session],'23514');
 await rejects(c,'UPDATE training_session SET end_date=start_date-1 WHERE session_id=$1',[f.session],'23514');
 await rejects(c,'UPDATE employee SET employee_name=NULL WHERE employee_id=$1',[f.employees[0].employee_id],'23502');pass('CHECK and NOT NULL constraints');
 const d=(await c.query("INSERT INTO department(department_name) VALUES('CRUD fixture') RETURNING department_id")).rows[0].department_id;await c.query("UPDATE department SET location='Changed' WHERE department_id=$1",[d]);assert.equal((await c.query('SELECT location FROM department WHERE department_id=$1',[d])).rows[0].location,'Changed');await c.query('DELETE FROM department WHERE department_id=$1',[d]);pass('CRUD read-your-writes');
 const n=(await c.query('SELECT enroll_employee($1,$2) AS id',[f.employees[0].employee_id,f.session])).rows[0].id;assert.ok(n);pass('enrollment stored function');
 await rejects(c,'INSERT INTO enrollment(employee_id,session_id) VALUES($1,$2)',[f.employees[1].employee_id,f.session],'23514');pass('capacity trigger rejects direct overbooking');
 await rejects(c,'SELECT enroll_employee($1,$2)',[f.employees[0].employee_id,f.session],'23505');
 await c.query("UPDATE enrollment SET status='Cancelled' WHERE enrollment_id=$1",[n]);const re=(await c.query('SELECT enroll_employee($1,$2) AS id',[f.employees[0].employee_id,f.session])).rows[0].id;assert.equal(re,n);pass('reactivation keeps unique enrollment ID');
 await rejects(c,"SELECT * FROM record_training_result($1,80,'Passed',NULL)",[n],'23514');
 await rejects(c,"UPDATE enrollment SET status='Completed' WHERE enrollment_id=$1",[n],'23514');pass('result and completion validation');
 await c.query('UPDATE training_session SET start_date=CURRENT_DATE-2,end_date=CURRENT_DATE-1 WHERE session_id=$1',[f.session]);
 await c.query("UPDATE enrollment SET status='Cancelled' WHERE enrollment_id=$1",[n]);await rejects(c,'SELECT enroll_employee($1,$2)',[f.employees[0].employee_id,f.session],'23514');
 await rejects(c,"UPDATE enrollment SET status='Completed' WHERE enrollment_id=$1",[n],'23514');pass('started sessions and invalid cancelled transitions rejected');
 // Create a separate valid completed enrollment via future enrollment, then elapsed dates.
 const s=(await c.query('INSERT INTO training_session(program_id,trainer_id,start_date,end_date,capacity) VALUES($1,$2,CURRENT_DATE+5,CURRENT_DATE+6,2) RETURNING session_id',[f.program,f.trainer])).rows[0].session_id;
 const n2=(await c.query('SELECT enroll_employee($1,$2) AS id',[f.employees[0].employee_id,s])).rows[0].id;
 const n3=(await c.query('SELECT enroll_employee($1,$2) AS id',[f.employees[1].employee_id,s])).rows[0].id;
 await rejects(c,'UPDATE training_session SET capacity=1 WHERE session_id=$1',[s],'23514');pass('capacity reduction rejected');
 await c.query('UPDATE training_session SET start_date=CURRENT_DATE-2,end_date=CURRENT_DATE-1 WHERE session_id=$1',[s]);await c.query("UPDATE enrollment SET status='Completed' WHERE enrollment_id IN($1,$2)",[n2,n3]);
 await rejects(c,"SELECT * FROM record_training_result($1,101,'Passed',NULL)",[n2],'23514');
 await rejects(c,"SELECT * FROM record_training_result($1,80,'Unknown',NULL)",[n2],'23514');
 await c.query("SELECT * FROM record_training_result($1,80,'Passed','Good')",[n2]);await c.query("SELECT * FROM record_training_result($1,60,'Passed',NULL)",[n3]);
 await rejects(c,"SELECT * FROM record_training_result($1,90,'Passed',NULL)",[n2],'23505');
 await rejects(c,"UPDATE enrollment SET status='Cancelled' WHERE enrollment_id=$1",[n2],'23514');
 await rejects(c,'UPDATE training_result SET enrollment_id=$1 WHERE enrollment_id=$2',[n,n2],'23514');pass('result function, range, enum, duplicate and completed-state protection');
 const stats=(await c.query('SELECT * FROM department_training_statistics WHERE department_id=$1',[f.dep])).rows[0];assert.equal(Number(stats.total_employees),2);assert.equal(Number(stats.employees_enrolled),2);assert.equal(Number(stats.completed_enrollments),2);assert.equal(Number(stats.average_score),70);
 assert.equal((await c.query('SELECT * FROM employee_training_summary WHERE enrollment_id=$1',[n2])).rows[0].employee_name,f.employees[0].employee_name);
 assert.equal(Number((await c.query('SELECT available_seats FROM training_session_availability WHERE session_id=$1',[s])).rows[0].available_seats),0);pass('all 3 views and non-inflated aggregates');
 await c.query("UPDATE employee SET designation='Audited' WHERE employee_id=$1",[f.employees[0].employee_id]);const audit=(await c.query("SELECT * FROM audit_log WHERE table_name='employee' AND record_id=$1 AND operation='UPDATE'",[f.employees[0].employee_id])).rows[0];assert.equal(audit.new_data.designation,'Audited');assert.equal(audit.old_data.designation,null);pass('audit OLD and NEW JSONB');
 await c.query('ROLLBACK');assert.equal(Number((await c.query('SELECT count(*) FROM employee')).rows[0].count),0);c.release();pass('transaction rollback removes fixtures and audit records');
 const isolation=await pool.connect();await isolation.query('BEGIN ISOLATION LEVEL REPEATABLE READ');
 await rejects(isolation,'UPDATE training_session SET capacity=capacity',[],'25000');
 await isolation.query('ROLLBACK');isolation.release();pass('unsupported isolation cannot bypass concurrency rules');
 // Commit a fixture to let independent connections compete for the final seat.
 const setup=await pool.connect();await setup.query('BEGIN');const race=await fixture(setup);await setup.query('COMMIT');setup.release();
 const a=await pool.connect();const b=await pool.connect();await a.query('BEGIN');await b.query('BEGIN');
 await a.query('SELECT enroll_employee($1,$2)',[race.employees[0].employee_id,race.session]);
 let settled=false;const attempt=b.query('SELECT enroll_employee($1,$2)',[race.employees[1].employee_id,race.session]).then(()=>({code:'unexpected success'}),e=>({code:e.code})).finally(()=>{settled=true});
 await new Promise(r=>setTimeout(r,150));assert.equal(settled,false);await a.query('COMMIT');assert.equal((await attempt).code,'23514');await b.query('ROLLBACK');a.release();b.release();
 assert.equal(Number((await pool.query('SELECT count(*) FROM enrollment WHERE session_id=$1 AND status<>$2',[race.session,'Cancelled'])).rows[0].count),1);pass('two connections: last-seat booking blocks, then exactly one succeeds');
 // Direct INSERT versus capacity reduction on another session.
 const s2=(await pool.query('INSERT INTO training_session(program_id,trainer_id,start_date,end_date,capacity) VALUES($1,$2,CURRENT_DATE+5,CURRENT_DATE+6,2) RETURNING session_id',[race.program,race.trainer])).rows[0].session_id;
 await pool.query('INSERT INTO enrollment(employee_id,session_id) VALUES($1,$2)',[race.employees[0].employee_id,s2]);
 const x=await pool.connect(),y=await pool.connect();await x.query('BEGIN');await y.query('BEGIN');await x.query('INSERT INTO enrollment(employee_id,session_id) VALUES($1,$2)',[race.employees[1].employee_id,s2]);
 const reduction=y.query('UPDATE training_session SET capacity=1 WHERE session_id=$1',[s2]).then(()=>({code:'unexpected success'}),e=>({code:e.code}));await x.query('COMMIT');assert.equal((await reduction).code,'23514');await y.query('ROLLBACK');x.release();y.release();pass('concurrent direct DML and capacity reduction preserve capacity');
 // Reports are parsed and executed against the same real schema.
 await pool.query(await readFile('sql/reports.sql','utf8'));pass('all 17 SQL reports execute');
 console.log(`${passed} database checks passed in isolated schema ${schema}.`);
}finally{await pool.end();await admin.query(`DROP SCHEMA "${schema}" CASCADE`);await admin.end();}
