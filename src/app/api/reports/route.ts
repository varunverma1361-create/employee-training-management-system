import {NextResponse} from 'next/server';
import {pool,serialize} from '@/lib/db';import {readable} from '@/lib/errors';
export const dynamic='force-dynamic';
export async function GET(){try{
 const [summary,departments,availability,programs]=await Promise.all([
 pool.query('SELECT * FROM employee_training_summary ORDER BY employee_id,session_id'),
 pool.query('SELECT * FROM department_training_statistics ORDER BY department_id'),
 pool.query('SELECT * FROM training_session_availability ORDER BY start_date'),
 pool.query(`SELECT p.title,count(n.enrollment_id) AS enrollments,round(avg(r.score),2) AS average_score FROM training_program p LEFT JOIN training_session s USING(program_id) LEFT JOIN enrollment n USING(session_id) LEFT JOIN training_result r USING(enrollment_id) GROUP BY p.program_id ORDER BY p.title`)]);
 return NextResponse.json(serialize({summary:summary.rows,departments:departments.rows,availability:availability.rows,programs:programs.rows}));
}catch(e){return NextResponse.json({error:readable(e)},{status:503});}}
