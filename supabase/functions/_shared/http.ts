import { createClient } from 'npm:@supabase/supabase-js@2';
export const headers = {'Access-Control-Allow-Origin':'*','Access-Control-Allow-Headers':'authorization, apikey, content-type, x-client-info','Access-Control-Allow-Methods':'POST, OPTIONS','Content-Type':'application/json'};
export const reply = (body: unknown,status=200) => new Response(JSON.stringify(body),{status,headers});
export const admin = () => createClient(Deno.env.get('SUPABASE_URL')!,Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,{auth:{persistSession:false,autoRefreshToken:false}});
export async function caller(req: Request) {
 const token=req.headers.get('Authorization')?.replace(/^Bearer\s+/i,'');
 if(!token) throw new Error('Unauthorized');
 const db=admin(); const {data,error}=await db.auth.getUser(token);
 if(error || !data.user) throw new Error('Unauthorized');
 const {data:profile,error:pe}=await db.from('profiles').select('id,role,is_active').eq('id',data.user.id).single();
 if(pe || !profile?.is_active) throw new Error('Forbidden');
 return {db,user:data.user,profile};
}
