import 'dotenv/config';import {Pool} from 'pg';
const url=new URL(process.env.DATABASE_URL!);url.searchParams.delete('schema');const pool=new Pool({connectionString:url.toString()});
const c=await pool.connect();
try{
 await c.query('BEGIN');await c.query('SELECT pg_advisory_xact_lock(72401)');
 if(Number((await c.query("SELECT count(*) FROM department WHERE department_name='Engineering'")).rows[0].count)>0){
  console.log('Seed already present; no records modified.');await c.query('ROLLBACK');
 }else{
  const count=Number((await c.query('SELECT count(*) FROM employee')).rows[0].count);
  if(count>0)throw Error('Seed requires an empty employee table; existing records were left intact.');
  const deps=[];for(const [name,location] of [['Engineering','North Campus'],['Human Resources','Admin Block'],['Finance','Central Campus'],['Operations','West Campus'],['Research','Innovation Centre']])deps.push((await c.query('INSERT INTO department(department_name,location) VALUES($1,$2) RETURNING department_id',[name,location])).rows[0].department_id);
  const names=['Aarav Mehta','Diya Rao','Kabir Shah','Mira Iyer','Rohan Sen','Anaya Bose','Vihaan Nair','Tara Das','Ishaan Kapoor','Leela Menon','Arjun Sethi','Nisha Pillai','Dev Malhotra','Sana Roy','Neil Bhat','Asha Verma','Kiran Joshi','Zoya Anand','Reva Kulkarni','Aditya Jain'];
  const employees=[];for(const [i,name] of names.entries())employees.push((await c.query('INSERT INTO employee(employee_name,email,department_id,designation,joining_date) VALUES($1,$2,$3,$4,CURRENT_DATE-365) RETURNING employee_id',[name,name.toLowerCase().replaceAll(' ','.')+'@example.test',deps[i%5],['Analyst','Engineer','Associate','Manager'][i%4]])).rows[0].employee_id);
  const trainers=[];for(const [i,name] of ['Priya Raman','Vikram Desai','Farah Khan','Sameer Gupta','Ritu Sood'].entries())trainers.push((await c.query('INSERT INTO trainer(trainer_name,email,specialization) VALUES($1,$2,$3) RETURNING trainer_id',[name,'trainer'+i+'@example.test',['Databases','Leadership','Security','Communication','Research'][i]])).rows[0].trainer_id);
  const programs=[];for(const [i,title] of ['PostgreSQL fundamentals','Effective communication','Information security','Team leadership','Data analytics','Project planning','Research methods','Workplace wellbeing'].entries())programs.push((await c.query('INSERT INTO training_program(title,description,duration_hours) VALUES($1,$2,$3) RETURNING program_id',[title,'Practical workshops and evaluation in '+title.toLowerCase(),[12,8,10,16,20,12,18,6][i]])).rows[0].program_id);
  const sessions=[];for(let i=0;i<12;i++)sessions.push((await c.query('INSERT INTO training_session(program_id,trainer_id,start_date,end_date,capacity) VALUES($1,$2,CURRENT_DATE+$3::integer,CURRENT_DATE+$4::integer,$5) RETURNING session_id',[programs[i%7],trainers[i%4],20+i*5,22+i*5,i===5?3:8])).rows[0].session_id);
  const enrollments=[];for(let i=0;i<30;i++)enrollments.push((await c.query('SELECT enroll_employee($1,$2) AS id',[employees[i%18],sessions[Math.floor(i/3)]])).rows[0].id);
  for(let i=0;i<5;i++)await c.query('UPDATE training_session SET start_date=CURRENT_DATE-30+$2::integer,end_date=CURRENT_DATE-28+$2::integer WHERE session_id=$1',[sessions[i],i*4]);
  for(let i=0;i<15;i++){await c.query("UPDATE enrollment SET status='Completed' WHERE enrollment_id=$1",[enrollments[i]]);const score=48+i*3;await c.query('SELECT * FROM record_training_result($1,$2,$3,$4)',[enrollments[i],score,score>=60?'Passed':'Failed',score>=60?'Demonstrated the required skills.':'Further guided practice recommended.']);}
  for(const i of [20,23,26,29])await c.query("UPDATE enrollment SET status='Cancelled' WHERE enrollment_id=$1",[enrollments[i]]);
  await c.query('COMMIT');console.log('Seeded 5 departments, 20 employees, 5 trainers, 8 programs, 12 sessions, 30 enrollments, 15 results. All names are fictional.');
 }
}catch(e){await c.query('ROLLBACK');throw e;}finally{c.release();await pool.end();}
