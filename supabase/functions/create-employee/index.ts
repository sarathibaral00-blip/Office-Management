import {caller,reply} from '../_shared/http.ts';
Deno.serve(async req=>{
 if(req.method==='OPTIONS') return reply({});
 if(req.method!=='POST') return reply({error:'Method not allowed'},405);
 try {
  const {db,profile}=await caller(req);
  if(!['hr','super_admin'].includes(profile.role)) return reply({error:'Forbidden'},403);
  const b=await req.json();
  if(typeof b.email!=='string'||!/^\S+@\S+\.\S+$/.test(b.email)||typeof b.password!=='string'||b.password.length!==6||!/^\d{6}$/.test(b.password)||typeof b.full_name!=='string'||!b.full_name.trim()) return reply({error:'Name, valid email and a password of exactly 6 digits are required'},400);
  const role=b.role??'employee';
  if(!['employee','manager','hr','super_admin'].includes(role) || (role==='super_admin' && profile.role!=='super_admin')) return reply({error:'Role assignment is not permitted'},403);
  if(b.salary!==undefined && (typeof b.salary!=='number'||b.salary<0||!Number.isFinite(b.salary))) return reply({error:'Invalid salary'},400);
  // Auth insertion invokes the profile trigger. Delete the newly created Auth
  // identity on profile failure to avoid leaving a partially provisioned account.
  const {data,error}=await db.auth.admin.createUser({email:b.email,password:b.password,email_confirm:true,user_metadata:{full_name:b.full_name}});
  if(error||!data.user) {
   const message=error?.code==='email_exists'||error?.code==='user_already_exists'
    ? 'An employee with this email already exists.'
    : error?.code==='weak_password'
    ? 'The project password policy rejected this password. Contact your administrator to allow six-digit employee passwords.'
    : 'Unable to create employee; check the email and password requirements.';
   return reply({error:message},400);
  }
  const fields:Record<string,unknown>={role,full_name:b.full_name.trim()};
  for(const k of ['department_id','branch_id','designation','salary','manager_id','shift_id','joined_at']) if(b[k]!==undefined) fields[k]=b[k];
  const {error:pe}=await db.from('profiles').update(fields).eq('id',data.user.id);
  if(pe) {
   const {error:cleanup}=await db.auth.admin.deleteUser(data.user.id);
   if(cleanup) console.error('Provisioning compensation failed for user',data.user.id);
   return reply({error:'Employee profile could not be provisioned. Verify branch, department, manager and shift.'},400);
  }
  return reply({id:data.user.id,email:data.user.email},201);
 }catch(e){const m=e instanceof Error?e.message:'';return reply({error:m==='Unauthorized'||m==='Forbidden'?m:'Invalid employee request'},m==='Unauthorized'?401:m==='Forbidden'?403:400);}
});
