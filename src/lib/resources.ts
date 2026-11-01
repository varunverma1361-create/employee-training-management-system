export type Field={name:string;label:string;type?:'text'|'email'|'number'|'date'|'textarea'|'select';required?:boolean;ref?:string;options?:string[]};
export type Resource={title:string;model:string;id:string;fields:Field[];readonly?:boolean};
const f=(name:string,label:string,type:Field['type']='text',required=false,ref?:string):Field=>({name,label,type,required,ref});
export const resources:Record<string,Resource>={
 departments:{title:'Departments',model:'department',id:'department_id',fields:[f('department_name','Department name','text',true),f('location','Location')]},
 employees:{title:'Employees',model:'employee',id:'employee_id',fields:[f('employee_name','Employee name','text',true),f('email','Email','email',true),f('department_id','Department','select',true,'departments'),f('designation','Designation'),f('joining_date','Joining date','date',true)]},
 trainers:{title:'Trainers',model:'trainer',id:'trainer_id',fields:[f('trainer_name','Trainer name','text',true),f('email','Email','email',true),f('specialization','Specialization')]},
 programs:{title:'Training programs',model:'training_program',id:'program_id',fields:[f('title','Title','text',true),f('description','Description','textarea'),f('duration_hours','Duration (hours)','number',true)]},
 sessions:{title:'Training sessions',model:'training_session',id:'session_id',fields:[f('program_id','Program','select',true,'programs'),f('trainer_id','Trainer','select',true,'trainers'),f('start_date','Start date','date',true),f('end_date','End date','date',true),f('capacity','Capacity','number',true)]},
 enrollments:{title:'Enrollments',model:'enrollment',id:'enrollment_id',fields:[f('employee_id','Employee','select',true,'employees'),f('session_id','Session','select',true,'sessions')]},
 results:{title:'Training results',model:'training_result',id:'result_id',fields:[f('enrollment_id','Completed enrollment','select',true,'enrollments'),f('score','Score (0–100)','number',true),{name:'completion_status',label:'Evaluation',type:'select',required:true,options:['Passed','Failed']},f('feedback','Feedback','textarea')]},
 audit:{title:'Audit logs',model:'audit_log',id:'log_id',fields:[],readonly:true}
};
export function label(row:Record<string,unknown>){return String(row.employee_name??row.department_name??row.trainer_name??row.title??(row.session_id?'Session '+row.session_id:row.enrollment_id?'Enrollment '+row.enrollment_id:'Record'));}
