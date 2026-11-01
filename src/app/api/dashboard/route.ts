import {NextResponse} from 'next/server';import {prisma,pool,serialize} from '@/lib/db';import {readable} from '@/lib/errors';
export const dynamic='force-dynamic';
export async function GET(){try{
 const [employees,departments,programs,sessions,enrollments,completed,upcoming]=await Promise.all([prisma.employee.count(),prisma.department.count(),prisma.training_program.count(),prisma.training_session.count(),prisma.enrollment.count(),prisma.enrollment.count({where:{status:'Completed'}}),pool.query('SELECT * FROM training_session_availability WHERE start_date>CURRENT_DATE ORDER BY start_date LIMIT 6')]);
 return NextResponse.json(serialize({counts:{employees,departments,programs,sessions,enrollments,completed},upcoming:upcoming.rows}));
}catch(e){return NextResponse.json({error:readable(e)},{status:503});}}
