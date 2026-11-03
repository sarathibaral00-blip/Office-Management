import {admin,caller,reply} from '../_shared/http.ts';
const uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
Deno.serve(async req => {
 if(req.method==='OPTIONS') return reply({});
 if(req.method!=='POST') return reply({error:'Method not allowed'},405);
 try {
  const body=await req.json();
  const ip=req.headers.get('x-forwarded-for')?.split(',')[0].trim();
  if(body.mode==='kiosk'||body.mode==='temporary') {
   // There is deliberately no employee-JWT shortcut here. A server-issued
   // device credential, office IP and verified employee PIN are all mandatory.
   const db=admin();
   if(!uuid.test(body.device_id??'')||typeof body.device_token!=='string'||body.device_token.length!==64||typeof body.employee_code!=='string'||body.employee_code.length>64||typeof body.pin!=='string'||body.pin.length>128||!['check_in','check_out'].includes(body.action)||!ip) {
    await db.from('audit_log').insert({table_name:'attendance_devices',action:'DEVICE_REJECTED',reason:'Invalid or incomplete fallback attendance request'});
    return reply({error:'Device credential, office IP, Employee ID, PIN and action are required'},400);
   }
   const {data,error}=await db.rpc('device_attendance',{p_device:body.device_id,p_token:body.device_token,p_mode:body.mode,p_code:body.employee_code,p_pin:body.pin,p_action:body.action,p_ip:ip});
   if(error) return reply({error:'Unable to process device attendance. Contact HR.'},400);
   if(!data?.ok) return reply({error:data?.error??'Device attendance rejected',code:data?.code},data?.code==='RATE_LIMITED'?429:data?.code==='PUNCH_REJECTED'?409:403);
   return reply(data);
  }
  const {db,user,profile}=await caller(req);
  if(!ip) return reply({error:'Unable to verify office network'},400);
  if(body.action==='current_ip') {
   if(!['hr','super_admin'].includes(profile.role)) return reply({error:'Forbidden'},403);
   return reply({ip});
  }
  if(!['check_in','check_out','status'].includes(body.action)) return reply({error:'Invalid attendance action'},400);
  // Ignore client-supplied source, employee_id, actor and device fields.
  const {data,error}=await db.rpc('record_attendance',{p_employee:user.id,p_ip:ip,p_action:body.action});
  if(error) {
   const message=error.message;
   if(message.includes('Connect to office WiFi')) return reply({error:'Connect to office WiFi',code:'OFFICE_WIFI_REQUIRED'},403);
   if(message.includes('Already checked')) return reply({error:message},409);
   return reply({error:message.includes('invalid input')?'Unable to verify office network':message},400);
  }
  return reply(data);
 } catch(e) {
  const message=e instanceof Error?e.message:'Unexpected error';
  return reply({error:message==='Unauthorized'||message==='Forbidden'?message:'Unable to process request'},message==='Unauthorized'?401:message==='Forbidden'?403:400);
 }
});
