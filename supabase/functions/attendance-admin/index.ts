import {caller,reply} from '../_shared/http.ts';
const actions=['manual','set_pin','set_limit','ack_alert','register_device','rotate_device','revoke_device','refresh_expiry'];
Deno.serve(async req=>{
 if(req.method==='OPTIONS')return reply({});
 if(req.method!=='POST')return reply({error:'Method not allowed'},405);
 try {
  const {db,user,profile}=await caller(req);
  if(!['hr','super_admin'].includes(profile.role)) {
   await db.from('audit_log').insert({actor_id:user.id,table_name:'attendance',action:'ADMIN_DENIED',reason:'Unauthorized attendance fallback management'});
   return reply({error:'Only HR and super admins can manage fallback attendance'},403);
  }
  const b=await req.json();
  if(!actions.includes(b.action))return reply({error:'Invalid management action'},400);
  const ip=req.headers.get('x-forwarded-for')?.split(',')[0].trim();
  if(!ip)return reply({error:'Unable to verify client IP'},400);
  let response;
  if(b.action==='manual') {
   response=await db.rpc('manual_attendance',{p_actor:user.id,p_employee:b.employee_id,p_check_in:b.check_in,p_check_out:b.check_out??null,p_reason:b.reason,p_ip:ip,p_attendance:b.attendance_id??null});
  } else if(b.action==='refresh_expiry') {
   response=await db.rpc('expire_attendance_devices');
  } else {
   // Actor and network identity come exclusively from the verified request.
   response=await db.rpc('manage_attendance_fallback',{p_actor:user.id,p_action:b.action,p_data:b.data??{},p_ip:ip});
  }
  if(response.error) {
   const message=response.error.message;
   await db.from('audit_log').insert({actor_id:user.id,table_name:'attendance',action:'MANAGEMENT_REJECTED',reason:`${b.action}: ${message}`});
   const safe=message.includes('duplicate')?'A conflicting attendance or device record already exists':message.includes('invalid input')||message.includes('null value')||message.includes('foreign key')?'Check the employee, device, times and required fields':message;
   return reply({error:safe},response.error.code==='23505'?409:400);
  }
  return reply(response.data??{ok:true});
 }catch(e){const m=e instanceof Error?e.message:'';return reply({error:m==='Unauthorized'||m==='Forbidden'?m:'Unable to process management request'},m==='Unauthorized'?401:m==='Forbidden'?403:400);}
});
