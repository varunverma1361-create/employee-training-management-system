import {NextRequest,NextResponse} from 'next/server';import {pool,serialize} from '@/lib/db';import {fixture} from '@/lib/demo';
export async function POST(req:NextRequest){
 if(process.env.ENABLE_DBMS_DEMOS!=='true')return NextResponse.json({error:'Enable ENABLE_DBMS_DEMOS=true in your local .env to use these demonstrations.'},{status:403});
 const {demo}=await req.json();if(!Number.isInteger(demo)||demo<1||demo>8)return NextResponse.json({error:'Choose demo 1–8'},{status:400});
 const c=await pool.connect();let before=0;const marker='rollback-'+crypto.randomUUID();
 try{
  await c.query('BEGIN');const f=await fixture(c);let output:unknown;
  if(demo===1)await c.query('INSERT INTO employee(employee_name,email,department_id) VALUES($1,$2,$3)',['Duplicate',f.employees[0].email,f.dep]);
  if(demo===2)await c.query('INSERT INTO employee(employee_name,email,department_id) VALUES($1,$2,$3)',['Orphan',marker+'@example.test',-1]);
  if(demo===3){
   const n=(await c.query('SELECT enroll_employee($1,$2) AS id',[f.employees[0].employee_id,f.session])).rows[0].id;
   await c.query('UPDATE training_session SET start_date=CURRENT_DATE-2,end_date=CURRENT_DATE-1 WHERE session_id=$1',[f.session]);
   await c.query("UPDATE enrollment SET status='Completed' WHERE enrollment_id=$1",[n]);
   await c.query("SELECT * FROM record_training_result($1,101,'Passed','Check demo')",[n]);
  }
  if(demo===4){await c.query('SELECT enroll_employee($1,$2)',[f.employees[0].employee_id,f.session]);await c.query('INSERT INTO enrollment(employee_id,session_id) VALUES($1,$2)',[f.employees[1].employee_id,f.session]);}
  if(demo===5){before=Number((await c.query("SELECT count(*) FROM audit_log WHERE table_name='employee' AND record_id=$1",[f.employees[0].employee_id])).rows[0].count);await c.query("UPDATE employee SET designation='Viva update' WHERE employee_id=$1",[f.employees[0].employee_id]);output={before,logs:(await c.query("SELECT * FROM audit_log WHERE table_name='employee' AND record_id=$1 ORDER BY log_id",[f.employees[0].employee_id])).rows};}
  if(demo===6)output=(await c.query('SELECT * FROM employee_training_summary ORDER BY employee_id LIMIT 30')).rows;
  if(demo===7)output=(await c.query('SELECT enroll_employee($1,$2) AS enrollment_id',[f.employees[0].employee_id,f.session])).rows;
  if(demo===8){await c.query('INSERT INTO department(department_name) VALUES($1)',[marker]);await c.query('INSERT INTO training_program(title,duration_hours) VALUES($1,0)',['Deliberate failure']);}
  await c.query('ROLLBACK');return NextResponse.json(serialize({ok:true,rolledBack:true,output}));
 }catch(error){
  await c.query('ROLLBACK');const e=error as {code?:string;message?:string};
  const remaining=demo===8?Number((await c.query('SELECT count(*) FROM department WHERE department_name=$1',[marker])).rows[0].count):undefined;
  return NextResponse.json({ok:[1,2,3,4,8].includes(demo)&&['23505','23503','23514'].includes(e.code??''),rolledBack:true,sqlstate:e.code,message:e.message,remaining});
 }finally{c.release();}
}
