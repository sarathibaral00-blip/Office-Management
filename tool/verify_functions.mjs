// Unit verification of the actual handlers with mocked Supabase boundaries.
// This does not replace Deno checks, gateway/IP checks, or deployed integration tests.
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { stripTypeScriptTypes } from 'node:module';
import vm from 'node:vm';

let db;
const context = vm.createContext({
  Response, Request, console,
  createClient: () => db,
  Deno: { env: { get: () => 'test-only' }, serve: handler => { context.handler = handler; } },
});
const load = path => stripTypeScriptTypes(readFileSync(new URL(path, import.meta.url), 'utf8').replace(/^import .*;\s*$/gm, ''), { mode: 'strip' });
vm.runInContext(load('../supabase/functions/_shared/http.ts').replace(/\bexport /g, ''), context);

function database(role = 'employee', options = {}) {
  return {
    auth: {
      getUser: async () => ({ data: { user: options.invalidToken ? null : { id: 'caller-id' } }, error: null }),
      admin: {
        createUser: async () => { calls.created++; return { data: { user: { id: 'new-user', email: 'new@example.com' } }, error: null }; },
        deleteUser: async id => { calls.deleted = id; return { error: null }; },
      },
    },
    from: table => ({
      select: () => ({ eq: () => ({ single: async () => ({ data: { id: 'caller-id', role, is_active: !options.inactive }, error: null }) }) }),
      insert: async fields => { calls.audit = fields; return {error:null}; },
      update: fields => ({ eq: async () => { calls.fields = fields; return { error: options.profileFailure ? { message: 'bad branch' } : null }; } }),
    }),
    rpc: async (name, args) => { calls.rpc = { name, args }; return { data: options.rpcData ?? { status: 'present' }, error: options.rpcError ? { message: options.rpcError } : null }; },
  };
}
let calls;
const reset = (role, options) => { calls = { created: 0 }; db = database(role, options); };
const request = (body, { token = true, ip = '203.0.113.4', method = 'POST' } = {}) => new Request('https://example.invalid', {
  method,
  headers: { ...(token ? { Authorization: 'Bearer test-token' } : {}), ...(ip ? { 'x-forwarded-for': ip } : {}), 'Content-Type': 'application/json' },
  ...(method === 'POST' ? { body: JSON.stringify(body) } : {}),
});
let passed = 0;
async function check(name, test) { await test(); passed++; console.log(`PASS: ${name}`); }
vm.runInContext(load('../supabase/functions/check-in/index.ts'), context);
await check('Missing token is rejected', async () => { reset(); assert.equal((await context.handler(request({ action: 'check_in' }, { token: false }))).status, 401); });
await check('Invalid token and inactive profiles are rejected', async () => {
  reset('employee', { invalidToken: true }); assert.equal((await context.handler(request({ action: 'check_in' }))).status, 401);
  reset('employee', { inactive: true }); assert.equal((await context.handler(request({ action: 'check_in' }))).status, 403);
});
await check('GET requests and unknown actions are rejected', async () => {
  reset(); assert.equal((await context.handler(request({}, { method: 'GET' }))).status, 405);
  assert.equal((await context.handler(request({ action: 'anything' }))).status, 400);
});
await check('Missing IP cannot record attendance', async () => { reset(); assert.equal((await context.handler(request({ action: 'check_in' }, { ip: null }))).status, 400); assert.equal(calls.rpc, undefined); });
await check('First forwarded address is used, never an IP supplied in JSON', async () => {
  reset(); assert.equal((await context.handler(request({ action: 'check_in', ip: 'spoofed' }, { ip: '203.0.113.4, 10.0.0.1' }))).status, 200);
  assert.equal(calls.rpc.args.p_ip, '203.0.113.4'); assert.equal(calls.rpc.args.p_employee, 'caller-id');
});
await check('Wrong network has a friendly error and duplicate check-in returns conflict', async () => {
  reset('employee', { rpcError: 'Connect to office WiFi' }); const result = await context.handler(request({ action: 'check_out' }));
  assert.equal(result.status, 403); assert.equal((await result.json()).code, 'OFFICE_WIFI_REQUIRED');
  reset('employee', { rpcError: 'Already checked in' }); assert.equal((await context.handler(request({ action: 'check_in' }))).status, 409);
});
await check('Current-IP lookup is restricted to HR/admin', async () => {
  reset(); assert.equal((await context.handler(request({ action: 'current_ip' }))).status, 403);
  reset('hr'); assert.equal((await context.handler(request({ action: 'current_ip' }))).status, 200);
});
const deviceRequest={mode:'kiosk',device_id:'20000000-0000-4000-a000-000000000001',device_token:'a'.repeat(64),employee_code:'EMP-000001',pin:'654321',action:'check_in'};
await check('Employee JWT cannot manufacture a kiosk source without an approved device', async()=>{
 reset();const r=await context.handler(request({...deviceRequest,device_token:undefined}));assert.equal(r.status,400);assert.equal(calls.rpc,undefined);assert.equal(calls.audit.action,'DEVICE_REJECTED');
});
await check('Normal app clients cannot override source, actor or target employee',async()=>{
 reset();assert.equal((await context.handler(request({action:'check_in',source:'manual',employee_id:'someone-else',p_actor:'hr'}))).status,200);
 assert.equal(calls.rpc.name,'record_attendance');assert.equal(calls.rpc.args.p_employee,'caller-id');assert.equal(calls.rpc.args.p_source,undefined);
});
await check('Approved-terminal requests authenticate through the device RPC, not an employee JWT shortcut',async()=>{
 reset('employee',{rpcData:{ok:true,attendance:{source:'kiosk'}}});const r=await context.handler(request(deviceRequest,{token:false}));assert.equal(r.status,200);assert.equal(calls.rpc.name,'device_attendance');assert.equal(calls.rpc.args.p_mode,'kiosk');assert.equal(calls.rpc.args.p_ip,'203.0.113.4');
});
await check('Wrong PIN, expired devices and rate limits propagate server rejections',async()=>{
 for(const [code,status] of [['INVALID_PIN',403],['DEVICE_REJECTED',403],['OFFICE_WIFI_REQUIRED',403],['RATE_LIMITED',429],['PUNCH_REJECTED',409]]){
  reset('employee',{rpcData:{ok:false,code,error:'Rejected'}});const r=await context.handler(request(deviceRequest));assert.equal(r.status,status);assert.equal((await r.json()).code,code);
 }
});
await check('Temporary requests preserve the temporary mode for server-side binding and expiry checks',async()=>{
 reset('employee',{rpcData:{ok:true}});assert.equal((await context.handler(request({...deviceRequest,mode:'temporary'}))).status,200);assert.equal(calls.rpc.args.p_mode,'temporary');
});

vm.runInContext(load('../supabase/functions/create-employee/index.ts'), context);
const employee = { email: 'new@example.com', password: '654321', full_name: 'Amina', branch_id: 'branch' };
await check('Employees and managers cannot provision employees', async () => {
  for (const role of ['employee', 'manager']) { reset(role); assert.equal((await context.handler(request(employee))).status, 403); assert.equal(calls.created, 0); }
});
await check('HR cannot create a super admin and invalid input creates no user', async () => {
  reset('hr'); assert.equal((await context.handler(request({ ...employee, role: 'super_admin' }))).status, 403);
  assert.equal((await context.handler(request({ ...employee, password: 'short' }))).status, 400); assert.equal(calls.created, 0);
});
await check('Employee passwords require exactly six digits', async () => {
  for (const password of ['12345', '1234567', 'abcdef', '12345a', '123456\n']) {
    reset('hr'); assert.equal((await context.handler(request({ ...employee, password }))).status, 400); assert.equal(calls.created, 0);
  }
  reset('hr'); assert.equal((await context.handler(request(employee))).status, 201);
});
await check('HR provisioning passes only explicitly allowed profile fields', async () => {
  reset('hr'); assert.equal((await context.handler(request({ ...employee, id: 'injected', is_active: false }))).status, 201);
  assert.equal(calls.created, 1); assert.equal(calls.fields.role, 'employee'); assert.equal(calls.fields.id, undefined); assert.equal(calls.fields.is_active, undefined);
});
await check('Profile provisioning failure compensates only the newly created identity', async () => {
  reset('hr', { profileFailure: true }); assert.equal((await context.handler(request(employee))).status, 400); assert.equal(calls.deleted, 'new-user');
});
vm.runInContext(load('../supabase/functions/attendance-admin/index.ts'), context);
await check('Employees and managers cannot create manual attendance and denial is audited',async()=>{
 for(const role of ['employee','manager']){reset(role);const r=await context.handler(request({action:'manual',employee_id:'other'}));assert.equal(r.status,403);assert.equal(calls.rpc,undefined);assert.equal(calls.audit.action,'ADMIN_DENIED');}
});
await check('Manual attendance actor is always the authenticated HR identity',async()=>{
 reset('hr',{rpcData:{ok:true}});assert.equal((await context.handler(request({action:'manual',employee_id:'target',check_in:'2026-10-20T09:00:00Z',reason:'Phone unavailable',p_actor:'forged'}))).status,200);assert.equal(calls.rpc.name,'manual_attendance');assert.equal(calls.rpc.args.p_actor,'caller-id');assert.equal(calls.rpc.args.p_employee,'target');
});
await check('Device approval and PIN commands cannot supply their own HR actor',async()=>{
 reset('hr',{rpcData:{ok:true}});assert.equal((await context.handler(request({action:'set_pin',data:{employee_id:'target',pin:'654321',p_actor:'forged'}}))).status,200);assert.equal(calls.rpc.name,'manage_attendance_fallback');assert.equal(calls.rpc.args.p_actor,'caller-id');assert.equal(calls.rpc.args.p_action,'set_pin');
});
await check('Rejected manual requests are audited and return no success',async()=>{
 reset('hr',{rpcError:'A reason of 3 to 1000 characters is required'});const r=await context.handler(request({action:'manual'}));assert.equal(r.status,400);assert.equal(calls.audit.action,'MANAGEMENT_REJECTED');
});

console.log(`${passed} Edge Function scenarios passed (mocked database).`);
