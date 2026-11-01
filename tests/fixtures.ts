import type {PoolClient} from 'pg';
// Dedicated fixtures for isolated database integration tests.
export async function fixture(c:PoolClient){
 const suffix=crypto.randomUUID();
 const dep=(await c.query("INSERT INTO department(department_name) VALUES($1) RETURNING department_id",['Test '+suffix])).rows[0].department_id;
 const employees=[];for(let i=0;i<2;i++)employees.push((await c.query("INSERT INTO employee(employee_name,email,department_id) VALUES($1,$2,$3) RETURNING *",['Test Employee '+i,`test-${suffix}-${i}@example.test`,dep])).rows[0]);
 const trainer=(await c.query("INSERT INTO trainer(trainer_name,email) VALUES('Test Trainer',$1) RETURNING trainer_id",['trainer-'+suffix+'@example.test'])).rows[0].trainer_id;
 const program=(await c.query("INSERT INTO training_program(title,duration_hours) VALUES('Test Program',2) RETURNING program_id")).rows[0].program_id;
 const session=(await c.query('INSERT INTO training_session(program_id,trainer_id,start_date,end_date,capacity) VALUES($1,$2,CURRENT_DATE+30,CURRENT_DATE+31,1) RETURNING session_id',[program,trainer])).rows[0].session_id;
 return {dep,employees,trainer,program,session};
}
