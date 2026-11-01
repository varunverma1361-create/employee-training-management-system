import { Prisma } from '@prisma/client';
export function readable(error:unknown){
 const e=error as {code?:string;message?:string};
 // Prisma's connector wraps PL/pgSQL exceptions in UnknownRequestError.
 // Expose only messages emitted by our known database rules, not query details.
 const rules=['Capacity cannot be below occupied seats','Session is full','Enrollment closes when a session starts','Training can only be completed on or after the end date','Completed enrollments are final','Reactivate before completing training','Enrollment identity cannot be changed','Only completed enrollments can receive results','Training writes require READ COMMITTED isolation'];
 const rule=rules.find(message=>e.message?.includes(message));if(rule)return rule+'.';
 if(e.message?.includes('training_session_capacity_check'))return 'Session capacity must be greater than zero.';
 if(e.message?.includes('training_session_check'))return 'Session end date cannot precede the start date.';
 if(e.message?.includes('training_program_duration_hours_check'))return 'Training duration must be greater than zero.';
 if(e.code==='25000')return 'Training writes require READ COMMITTED isolation.';
 if(error instanceof Prisma.PrismaClientKnownRequestError){
  if(e.code==='P2002')return 'A record with these unique values already exists.';
  if(e.code==='P2003')return 'Related records prevent this change. Check references and preserve training history.';
  if(e.code==='P2025')return 'Record not found.';
 }
 if(e.code==='23505')return e.message?.includes('already')?e.message:'Duplicate value: this record already exists.';
 if(e.code==='23503')return 'Invalid reference, or related history prevents deletion.';
 if(e.code==='23514')return e.message??'A database CHECK constraint rejected the values.';
 if(e.code==='23502')return 'A required database field is missing.';
 if(e.code==='40P01'||e.code==='40001')return 'Another transaction conflicted. Please retry.';
 if(e.code==='22P02'||e.code==='22007'||e.code==='22008'||e.code==='22003')return 'Invalid number, date, or value.';
 if(e.code==='P2000')return 'A value exceeds the database column length.';
 if(error instanceof Prisma.PrismaClientValidationError)return 'Check the field values and required fields.';
 if(e.code?.startsWith('P10')||e.code==='ECONNREFUSED')return 'Database unavailable. Check DATABASE_URL and run migrations.';
 return 'The operation could not be completed. Check the values and database connection.';
}
