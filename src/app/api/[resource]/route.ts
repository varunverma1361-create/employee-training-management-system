import { NextRequest,NextResponse } from 'next/server';
import { prisma,pool,serialize } from '@/lib/db';
import { resources } from '@/lib/resources';
import { readable } from '@/lib/errors';
export const dynamic='force-dynamic';
type Context={params:Promise<{resource:string}>};
// The delegates differ by model; the allowlist below fixes their fields before dispatch.
function delegate(model:string){return (prisma as unknown as Record<string,{findMany:(a?:unknown)=>Promise<unknown>;create:(a:unknown)=>Promise<unknown>;update:(a:unknown)=>Promise<unknown>;delete:(a:unknown)=>Promise<unknown>}>)[model];}
export async function GET(req:NextRequest,{params}:Context){
 const {resource}=await params;const config=resources[resource];if(!config)return NextResponse.json({error:'Not found'},{status:404});
 try{
  if(resource==='sessions')return NextResponse.json(serialize((await pool.query('SELECT * FROM training_session_availability ORDER BY start_date,session_id')).rows));
  const where:Record<string,unknown>={}; const q=req.nextUrl.searchParams;
  if(resource==='enrollments')return NextResponse.json(serialize((await pool.query(`SELECT n.*,e.employee_name,p.title AS program,s.start_date,s.end_date FROM enrollment n JOIN employee e USING(employee_id) JOIN training_session s USING(session_id) JOIN training_program p USING(program_id) WHERE ($1::integer IS NULL OR n.employee_id=$1) AND ($2::integer IS NULL OR n.session_id=$2) ORDER BY n.enrollment_id`,[q.get('employee_id')||null,q.get('session_id')||null])).rows));
  if(resource==='results')return NextResponse.json(serialize((await pool.query(`SELECT r.*,e.employee_name,p.title AS program,s.session_id FROM training_result r JOIN enrollment n USING(enrollment_id) JOIN employee e USING(employee_id) JOIN training_session s USING(session_id) JOIN training_program p USING(program_id) ORDER BY r.result_id`)).rows));
  if(resource==='employees'){if(q.get('department_id'))where.department_id=Number(q.get('department_id'));if(q.get('q'))where.employee_name={contains:q.get('q'),mode:'insensitive'};}
  if(resource==='enrollments'){for(const key of ['employee_id','session_id'])if(q.get(key))where[key]=Number(q.get(key));}
  return NextResponse.json(serialize(await delegate(config.model).findMany({where,orderBy:{[config.id]:resource==='audit'?'desc':'asc'},...(resource==='audit'?{take:200}:{})})));
 }catch(error){return NextResponse.json({error:readable(error)},{status:503});}
}
async function mutate(req:NextRequest,{params}:Context){
 const {resource}=await params;const config=resources[resource];if(!config||config.readonly)return NextResponse.json({error:'This resource is read-only or does not exist'},{status:405});
 try{
  const body=await req.json();const id=Number(body.id);let result:unknown;
  if(req.method!=='POST'&&(!Number.isSafeInteger(id)||id<=0))throw new Error('Invalid ID');
  if(resource==='enrollments'){
   if(req.method==='POST')result=(await pool.query('SELECT enroll_employee($1::integer,$2::integer) AS enrollment_id',[body.employee_id,body.session_id])).rows[0];
   else if(req.method==='PATCH'&&['Cancelled','Completed'].includes(body.status))result=(await pool.query('UPDATE enrollment SET status=$1 WHERE enrollment_id=$2 RETURNING *',[body.status,id])).rows[0];
   else return NextResponse.json({error:'Use enroll to reactivate, cancel, or complete; training history cannot be deleted.'},{status:405});
   if(!result)return NextResponse.json({error:'Enrollment not found'},{status:404});
  }else if(resource==='results'){
   if(req.method!=='POST')return NextResponse.json({error:'Results are preserved. Only recording is exposed.'},{status:405});
   result=(await pool.query('SELECT * FROM record_training_result($1::integer,$2::numeric,$3::varchar,$4::text)',[body.enrollment_id,body.score,body.completion_status,body.feedback||null])).rows[0];
  }else{
   const data:Record<string,unknown>={};for(const field of config.fields){
    const value=body[field.name];if(value===undefined)continue;
    data[field.name]=value===''&&!field.required?null:field.type==='number'||field.ref?Number(value):field.type==='date'?new Date(String(value)):value;
   }
   const db=delegate(config.model);
   result=req.method==='POST'?await db.create({data}):req.method==='PATCH'?await db.update({where:{[config.id]:id},data}):await db.delete({where:{[config.id]:id}});
  }
  return NextResponse.json(serialize(result),{status:req.method==='POST'?201:200});
 }catch(error){return NextResponse.json({error:readable(error)},{status:400});}
}
export const POST=mutate;export const PATCH=mutate;export const DELETE=mutate;
