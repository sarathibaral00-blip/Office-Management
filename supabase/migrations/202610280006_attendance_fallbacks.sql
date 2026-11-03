begin;
create extension if not exists pgcrypto with schema extensions;
create schema attendance_private;
revoke all on schema attendance_private from public,anon,authenticated,service_role;
create type public.attendance_source as enum ('app','manual','correction','kiosk');
create type public.attendance_device_kind as enum ('kiosk','temporary');
create sequence public.employee_code_seq;
alter table public.profiles add column employee_code text not null default ('EMP-'||nextval('public.employee_code_seq')::text) unique;
create function public.protect_employee_code() returns trigger language plpgsql set search_path='' as $$ begin
 if new.employee_code is distinct from old.employee_code then raise exception 'Employee ID is immutable'; end if;
 return new;
end $$;
create trigger protect_employee_code before update on public.profiles for each row execute function public.protect_employee_code();
revoke all on function public.protect_employee_code() from public,anon,authenticated;
grant usage,select on public.employee_code_seq to service_role;

create table public.attendance_settings (
 singleton boolean primary key default true check(singleton),
 monthly_manual_limit integer not null default 3 check(monthly_manual_limit between 0 and 100)
);
insert into public.attendance_settings default values;
create table public.attendance_devices (
 id uuid primary key default gen_random_uuid(), label text not null check(length(trim(label)) between 1 and 100),
 kind public.attendance_device_kind not null, branch_id uuid not null references public.branches(id),
 employee_id uuid references public.profiles(id), approved_by uuid not null references public.profiles(id),
 approved_at timestamptz not null default now(), expires_at timestamptz, revoked_at timestamptz,
 reason text not null check(length(trim(reason)) between 3 and 1000),
 check((kind='kiosk' and employee_id is null and expires_at is null) or
       (kind='temporary' and employee_id is not null and expires_at is not null and expires_at>approved_at and expires_at<=approved_at+interval '1 day'))
);
create table attendance_private.device_credentials (
 device_id uuid primary key references public.attendance_devices(id), token_hash bytea not null,
 window_started_at timestamptz not null default now(), window_attempts integer not null default 0,
 unknown_id_failures integer not null default 0, locked_at timestamptz
);
create table attendance_private.employee_pins (
 employee_id uuid primary key references public.profiles(id), pin_hash text not null,
 failed_attempts integer not null default 0 check(failed_attempts between 0 and 5), locked_at timestamptz,
 updated_by uuid not null references public.profiles(id), updated_at timestamptz not null default now()
);
alter table public.attendance add column source public.attendance_source not null default 'app',
 add column device_id uuid references public.attendance_devices(id),
 add column recorded_by uuid references public.profiles(id), add column manual_reason text;
alter table public.audit_log add column employee_id uuid references public.profiles(id) on delete set null,
 add column device_id uuid references public.attendance_devices(id),
 add column old_values jsonb, add column new_values jsonb, add column reason text;
create table public.hr_attendance_alerts (
 id uuid primary key default gen_random_uuid(), employee_id uuid not null references public.profiles(id),
 month date not null, manual_count integer not null, monthly_limit integer not null,
 message text not null, created_at timestamptz not null default now(),
 acknowledged_at timestamptz, acknowledged_by uuid references public.profiles(id), unique(employee_id,month)
);
create index attendance_source_date_idx on public.attendance(source,work_date,id);
create index attendance_device_id_idx on public.attendance(device_id);
create index attendance_recorded_by_idx on public.attendance(recorded_by);
create index attendance_devices_branch_idx on public.attendance_devices(branch_id);
create index attendance_devices_employee_idx on public.attendance_devices(employee_id);
create index attendance_devices_approver_idx on public.attendance_devices(approved_by);
create index attendance_devices_expiry_idx on public.attendance_devices(expires_at) where revoked_at is null;
create index audit_employee_idx on public.audit_log(employee_id);
create index audit_device_idx on public.audit_log(device_id);
create index audit_record_idx on public.audit_log(table_name,record_id,created_at);
create index hr_alerts_acknowledged_by_idx on public.hr_attendance_alerts(acknowledged_by);
create index employee_pins_updated_by_idx on attendance_private.employee_pins(updated_by);

do $$ declare t text; begin
 foreach t in array array['attendance_settings','attendance_devices','hr_attendance_alerts'] loop
  execute format('alter table public.%I enable row level security',t);
  execute format('revoke all on public.%I from public,anon,authenticated',t);
  execute format('grant select on public.%I to authenticated',t);
  execute format('grant all on public.%I to service_role',t);
  execute format('create policy hr_read on public.%I for select to authenticated using ((select public.is_hr()))',t);
 end loop;
end $$;
alter table attendance_private.device_credentials enable row level security;
alter table attendance_private.employee_pins enable row level security;
revoke all on all tables in schema attendance_private from public,anon,authenticated,service_role;
-- Only definer functions owned by postgres access private credential rows.
create policy credential_owner on attendance_private.device_credentials to postgres using(true) with check(true);
create policy pin_owner on attendance_private.employee_pins to postgres using(true) with check(true);
create policy hr_attendance_audit on public.audit_log for select to authenticated
 using ((select public.is_hr()) and table_name in ('attendance','attendance_devices','employee_pins','attendance_settings','hr_attendance_alerts'));

-- Preserve generic audit behavior and enrich attendance records. Secrets never
-- pass through this trigger; private credential/PIN tables have no audit trigger.
create or replace function public.audit_change() returns trigger language plpgsql security definer set search_path='' as $$
declare before_row jsonb; after_row jsonb; target uuid;
begin
 if tg_op<>'INSERT' then before_row:=to_jsonb(old); end if;
 if tg_op<>'DELETE' then after_row:=to_jsonb(new); end if;
 target:=coalesce(after_row->>'employee_id',before_row->>'employee_id')::uuid;
 insert into public.audit_log(actor_id,table_name,record_id,action,employee_id,device_id,old_values,new_values,reason)
 values(coalesce(nullif(current_setting('app.audit_actor',true),'')::uuid,auth.uid()),tg_table_name,
 coalesce(after_row->>'id',before_row->>'id',after_row->>'singleton'),tg_op,target,
 case when tg_table_name='attendance' then coalesce(after_row->>'device_id',before_row->>'device_id')::uuid when tg_table_name='attendance_devices' then coalesce(after_row->>'id',before_row->>'id')::uuid else null end,
 before_row,after_row,nullif(current_setting('app.audit_reason',true),''));
 return coalesce(new,old);
end $$;
create trigger audit_change after insert or update on public.attendance_devices for each row execute function public.audit_change();
create trigger audit_change after update on public.attendance_settings for each row execute function public.audit_change();
create trigger audit_change after insert or update on public.hr_attendance_alerts for each row execute function public.audit_change();

create function attendance_private.require_hr(actor uuid) returns void language plpgsql security definer set search_path='' as $$ begin
 if actor is null or not exists(select 1 from public.profiles where id=actor and is_active and role in ('hr','super_admin')) then raise exception 'Forbidden'; end if;
 perform set_config('app.audit_actor',actor::text,true);
end $$;
create function public.expire_attendance_devices() returns void language plpgsql security definer set search_path='' as $$ begin
 perform set_config('app.audit_actor','',true);
 perform set_config('app.audit_reason','Temporary device approval expired',true);
 update public.attendance_devices set revoked_at=expires_at where kind='temporary' and revoked_at is null and expires_at<=clock_timestamp();
end $$;

-- Device management is HR-only through the attendance-admin Edge Function.
create function public.manage_attendance_fallback(p_actor uuid,p_action text,p_data jsonb,p_ip inet) returns jsonb
 language plpgsql security definer set search_path='' as $$
declare d public.attendance_devices; token text; target uuid; before_pin jsonb; expires timestamptz; lim integer; message text;
begin
 perform attendance_private.require_hr(p_actor);
 if p_action='set_pin' then
  target:=(p_data->>'employee_id')::uuid;
  if not exists(select 1 from public.profiles where id=target and is_active) then raise exception 'Employee not found or inactive'; end if;
  if coalesce(p_data->>'pin','') !~ '^[0-9]{6,12}$' then raise exception 'PIN must contain 6 to 12 digits'; end if;
  perform 1 from public.profiles where id=target for update;
  select jsonb_build_object('pin_set',true,'locked',locked_at is not null) into before_pin from attendance_private.employee_pins where employee_id=target;
  insert into attendance_private.employee_pins(employee_id,pin_hash,updated_by)
   values(target,extensions.crypt(p_data->>'pin',extensions.gen_salt('bf',12)),p_actor)
   on conflict(employee_id) do update set pin_hash=excluded.pin_hash,failed_attempts=0,locked_at=null,updated_by=p_actor,updated_at=now();
  insert into public.audit_log(actor_id,employee_id,table_name,record_id,action,old_values,new_values,reason)
   values(p_actor,target,'employee_pins',target::text,'PIN_RESET',before_pin,'{"pin_set":true,"locked":false}', 'HR set or reset employee kiosk PIN');
  return jsonb_build_object('ok',true);
 elsif p_action='set_limit' then
  lim:=(p_data->>'limit')::integer;
  if lim is null or lim not between 0 and 100 then raise exception 'Limit must be 0 to 100'; end if;
  if length(trim(coalesce(p_data->>'reason','')))<3 then raise exception 'A reason is required'; end if;
  perform set_config('app.audit_reason',p_data->>'reason',true);
  update public.attendance_settings set monthly_manual_limit=lim where singleton;
  return jsonb_build_object('ok',true);
 elsif p_action='ack_alert' then
  perform set_config('app.audit_reason','HR acknowledged manual-attendance alert',true);
  update public.hr_attendance_alerts set acknowledged_at=now(),acknowledged_by=p_actor where id=(p_data->>'id')::uuid;
  if not found then raise exception 'Alert not found'; end if;
  return jsonb_build_object('ok',true);
 end if;
 if p_action not in ('register_device','rotate_device','revoke_device') then raise exception 'Invalid management action'; end if;
 if length(trim(coalesce(p_data->>'reason','')))<3 or length(p_data->>'reason')>1000 then raise exception 'A reason of 3 to 1000 characters is required'; end if;
 perform set_config('app.audit_reason',p_data->>'reason',true);
 if p_action='register_device' then
  if p_data->>'kind' not in ('kiosk','temporary') or p_data->>'kind' is null then raise exception 'Invalid device kind'; end if;
  if not exists(select 1 from public.allowed_networks where branch_id=(p_data->>'branch_id')::uuid and is_active and p_ip <<= network) then raise exception 'Connect to office WiFi'; end if;
  if p_data->>'kind'='temporary' then
   target:=(p_data->>'employee_id')::uuid;
   if not exists(select 1 from public.profiles where id=target and is_active and branch_id=(p_data->>'branch_id')::uuid) then raise exception 'Choose an active employee in this branch'; end if;
   expires:=coalesce((p_data->>'expires_at')::timestamptz,now()+interval '1 day');
   if expires<=clock_timestamp() or expires>now()+interval '1 day' then raise exception 'Temporary approvals must expire within one day'; end if;
  end if;
  insert into public.attendance_devices(label,kind,branch_id,employee_id,approved_by,expires_at,reason)
   values(trim(p_data->>'label'),(p_data->>'kind')::public.attendance_device_kind,(p_data->>'branch_id')::uuid,target,p_actor,expires,p_data->>'reason') returning * into d;
 else
  select * into d from public.attendance_devices where id=(p_data->>'id')::uuid for update;
  if not found then raise exception 'Device not found'; end if;
  if p_action='revoke_device' then
   update public.attendance_devices set revoked_at=coalesce(revoked_at,now()),reason=p_data->>'reason' where id=d.id;
   return jsonb_build_object('ok',true);
  end if;
  if d.revoked_at is not null or (d.expires_at is not null and d.expires_at<=clock_timestamp()) then raise exception 'Device expired or revoked. Register a new approval'; end if;
  if not exists(select 1 from public.allowed_networks where branch_id=d.branch_id and is_active and p_ip <<= network) then raise exception 'Connect to office WiFi'; end if;
  update public.attendance_devices set approved_by=p_actor,reason=p_data->>'reason' where id=d.id returning * into d;
 end if;
 token:=encode(extensions.gen_random_bytes(32),'hex');
 insert into attendance_private.device_credentials(device_id,token_hash)
 values(d.id,extensions.digest(token,'sha256')) on conflict(device_id) do update
 set token_hash=excluded.token_hash,window_attempts=0,window_started_at=now(),unknown_id_failures=0,locked_at=null;
 -- Token is returned once over TLS, never saved in public rows or audit values.
 return jsonb_build_object('ok',true,'device_id',d.id,'device_token',token,'kind',d.kind,'label',d.label,'expires_at',d.expires_at);
end $$;

create function public.manual_attendance(p_actor uuid,p_employee uuid,p_check_in timestamptz,p_check_out timestamptz,p_reason text,p_ip inet,p_attendance uuid default null) returns jsonb
 language plpgsql security definer set search_path='' as $$
declare p public.profiles; b public.branches; s public.shifts; old_row public.attendance; a public.attendance; day date; n integer; lim integer;
begin
 perform attendance_private.require_hr(p_actor);
 if length(trim(coalesce(p_reason,'')))<3 or length(p_reason)>1000 then raise exception 'A reason of 3 to 1000 characters is required'; end if;
 if p_check_in is null or p_ip is null or p_check_in>now() or p_check_out>now() or p_check_out<p_check_in then raise exception 'Check-in/out must be valid past times in order'; end if;
 select * into p from public.profiles where id=p_employee for update;
 if not found then raise exception 'Employee not found'; end if;
 if p_attendance is not null then
  select * into old_row from public.attendance where id=p_attendance and employee_id=p_employee for update;
  if not found then raise exception 'Attendance record not found for employee'; end if;
 end if;
 select * into b from public.branches where id=coalesce(old_row.branch_id,p.branch_id);
 if not found then raise exception 'Assign employee to a branch first'; end if;
 select * into s from public.shifts where id=p.shift_id;
 if not found then select * into s from public.shifts where is_default; end if;
 if not found then raise exception 'Configure an employee shift first'; end if;
 day:=(p_check_in at time zone b.timezone)::date;
 if s.ends_at<=s.starts_at and (p_check_in at time zone b.timezone)::time<s.ends_at then day:=day-1; end if;
 if p_attendance is not null and old_row.work_date<>day then raise exception 'Editing cannot move a record to another work date'; end if;
 perform set_config('app.audit_reason',trim(p_reason),true);
 if p_attendance is null then
  if exists(select 1 from public.attendance where employee_id=p_employee and work_date=day) then raise exception 'Attendance already exists. Load the record to edit it'; end if;
  insert into public.attendance(employee_id,branch_id,work_date,check_in,check_out,status,client_ip,source,recorded_by,manual_reason)
   values(p_employee,b.id,day,p_check_in,p_check_out,case when p_check_in>((day+s.starts_at) at time zone b.timezone)+make_interval(mins=>s.grace_minutes) then 'late'::public.attendance_status else 'present'::public.attendance_status end,p_ip,'manual',p_actor,trim(p_reason)) returning * into a;
 else
  update public.attendance set check_in=p_check_in,check_out=p_check_out,
   status=case when p_check_in>((day+s.starts_at) at time zone b.timezone)+make_interval(mins=>s.grace_minutes) then 'late'::public.attendance_status else 'present'::public.attendance_status end,
   source='manual',recorded_by=p_actor,manual_reason=trim(p_reason),client_ip=p_ip where id=p_attendance returning * into a;
 end if;
 select count(*) into n from public.attendance where employee_id=p_employee and source='manual' and work_date>=date_trunc('month',day)::date and work_date<(date_trunc('month',day)+interval '1 month')::date;
 select monthly_manual_limit into lim from public.attendance_settings where singleton;
 if n>lim then
  insert into public.hr_attendance_alerts(employee_id,month,manual_count,monthly_limit,message)
   values(p_employee,date_trunc('month',day)::date,n,lim,format('%s has %s manual records this month (limit %s).',p.employee_code,n,lim))
   on conflict(employee_id,month) do update set manual_count=excluded.manual_count,monthly_limit=excluded.monthly_limit,message=excluded.message,acknowledged_at=null,acknowledged_by=null;
 end if;
 return jsonb_build_object('ok',true,'attendance',to_jsonb(a),'manual_count',n,'limit',lim,'limit_exceeded',n>lim);
end $$;

-- Internal shared writer preserves existing behavior and provenance on mixed
-- app/kiosk/manual checkout. No public client can supply a source or actor.
create function attendance_private.write_punch(p_employee uuid,p_ip inet,p_action text,p_source public.attendance_source,p_device uuid default null,p_context text default null) returns jsonb
 language plpgsql security definer set search_path='' as $$
declare p public.profiles; s public.shifts; a public.attendance; b public.branches; stamp timestamptz:=clock_timestamp(); local_day date; local_clock time;
begin
 if p_action is null or p_action not in ('check_in','check_out','status') then raise exception 'Invalid action'; end if;
 select * into p from public.profiles where id=p_employee and is_active for update;
 if not found then raise exception 'Employee profile is inactive or missing'; end if;
 select * into b from public.branches where id=p.branch_id;
 if not found then raise exception 'Ask HR to assign your branch'; end if;
 if not exists(select 1 from public.allowed_networks where is_active and branch_id=p.branch_id and p_ip <<= network) then raise exception 'Connect to office WiFi'; end if;
 if p_action='status' then return jsonb_build_object('allowed',true,'ip',host(p_ip),'branch',b.name); end if;
 perform set_config('app.audit_actor',p_employee::text,true);
 perform set_config('app.audit_reason',coalesce(p_context,p_source::text)||' '||p_action,true);
 local_day:=(stamp at time zone b.timezone)::date; local_clock:=(stamp at time zone b.timezone)::time;
 if p_action='check_in' then
  select * into s from public.shifts where id=p.shift_id;
  if not found then select * into s from public.shifts where is_default; end if;
  if not found then raise exception 'Ask HR to configure your shift'; end if;
  if s.ends_at<=s.starts_at and local_clock<s.ends_at then local_day:=local_day-1; end if;
  if exists(select 1 from public.attendance where employee_id=p.id and (work_date=local_day or check_out is null)) then raise exception 'Already checked in. Check out your open attendance first'; end if;
  insert into public.attendance(employee_id,branch_id,work_date,check_in,status,client_ip,source,device_id,recorded_by)
   values(p.id,b.id,local_day,stamp,case when stamp>((local_day+s.starts_at) at time zone b.timezone)+make_interval(mins=>s.grace_minutes) then 'late'::public.attendance_status else 'present'::public.attendance_status end,p_ip,p_source,p_device,p.id) returning * into a;
 else
  select * into a from public.attendance where employee_id=p.id and check_out is null for update;
  if not found then raise exception 'No open check-in to check out'; end if;
  update public.attendance set check_out=stamp,device_id=coalesce(p_device,device_id),recorded_by=p.id,
   source=case when source in ('manual','correction') then source when p_source='kiosk' then p_source else source end where id=a.id returning * into a;
 end if;
 return to_jsonb(a);
end $$;
create or replace function public.record_attendance(p_employee uuid,p_ip inet,p_action text) returns jsonb
 language sql security definer set search_path='' as $$ select attendance_private.write_punch(p_employee,p_ip,p_action,'app') $$;

-- Returns errors instead of throwing for PIN failures: throwing would roll back
-- the failed-attempt counter and audit, allowing unlimited guesses.
create function public.device_attendance(p_device uuid,p_token text,p_mode text,p_code text,p_pin text,p_action text,p_ip inet) returns jsonb
 language plpgsql security definer set search_path='' as $$
declare d public.attendance_devices; c attendance_private.device_credentials; p public.profiles; pin attendance_private.employee_pins; result jsonb; code text; why text;
begin
 perform public.expire_attendance_devices();
 select * into d from public.attendance_devices where id=p_device for update;
 select * into c from attendance_private.device_credentials where device_id=p_device for update;
 if d.id is null or c.device_id is null or coalesce(p_token,'')='' or c.token_hash<>extensions.digest(p_token,'sha256') then
  insert into public.audit_log(table_name,record_id,action,reason) values('attendance_devices',p_device::text,'DEVICE_REJECTED','Invalid device credential');
  return jsonb_build_object('ok',false,'code','DEVICE_REJECTED','error','Device is not approved. Ask HR to pair this device');
 end if;
 if d.kind::text is distinct from p_mode or d.revoked_at is not null or (d.expires_at is not null and d.expires_at<=clock_timestamp()) or c.locked_at is not null then
  insert into public.audit_log(table_name,record_id,device_id,action,reason) values('attendance_devices',d.id::text,d.id,'DEVICE_REJECTED','Device expired, revoked, locked or wrong mode');
  return jsonb_build_object('ok',false,'code','DEVICE_REJECTED','error','Device expired, revoked or locked. Ask HR to pair it again');
 end if;
 if not exists(select 1 from public.allowed_networks where branch_id=d.branch_id and is_active and p_ip <<= network) then
  insert into public.audit_log(table_name,record_id,device_id,action,reason) values('attendance_devices',d.id::text,d.id,'NETWORK_REJECTED','Connect to office WiFi');
  return jsonb_build_object('ok',false,'code','OFFICE_WIFI_REQUIRED','error','Connect to office WiFi');
 end if;
 if c.window_started_at<=clock_timestamp()-interval '1 minute' then
  update attendance_private.device_credentials set window_started_at=clock_timestamp(),window_attempts=0 where device_id=d.id returning * into c;
 end if;
 if c.window_attempts>=20 then
  insert into public.audit_log(table_name,record_id,device_id,action,reason) values('attendance_devices',d.id::text,d.id,'RATE_LIMITED','Device exceeded 20 attempts per minute');
  return jsonb_build_object('ok',false,'code','RATE_LIMITED','error','Too many attempts. Wait a minute before trying again');
 end if;
 update attendance_private.device_credentials set window_attempts=window_attempts+1 where device_id=d.id;
 select * into p from public.profiles where employee_code=upper(trim(p_code)) and is_active for update;
 if p.id is not null then select * into pin from attendance_private.employee_pins where employee_id=p.id for update; end if;
 if p.id is null or p.branch_id is distinct from d.branch_id or (d.kind='temporary' and p.id is distinct from d.employee_id) or pin.employee_id is null or pin.locked_at is not null or coalesce(p_pin,'') !~ '^[0-9]{6,12}$' then
  code:='INVALID_PIN';
 elsif extensions.crypt(p_pin,pin.pin_hash)<>pin.pin_hash then code:='INVALID_PIN';
 end if;
 if code is not null then
  if pin.employee_id is not null and p.branch_id=d.branch_id and (d.kind='kiosk' or p.id=d.employee_id) and pin.locked_at is null then
   update attendance_private.employee_pins set failed_attempts=least(failed_attempts+1,5),locked_at=case when failed_attempts+1>=5 then clock_timestamp() else null end where employee_id=p.id;
  else
   update attendance_private.device_credentials set unknown_id_failures=unknown_id_failures+1,locked_at=case when unknown_id_failures+1>=5 then clock_timestamp() else locked_at end where device_id=d.id;
  end if;
  insert into public.audit_log(table_name,record_id,employee_id,device_id,action,reason) values('employee_pins',p.id::text,p.id,d.id,'PIN_REJECTED','Invalid Employee ID or PIN; five failures require HR reset');
  return jsonb_build_object('ok',false,'code','INVALID_PIN','error','Invalid Employee ID or PIN. Ask HR to reset it if locked');
 end if;
 update attendance_private.employee_pins set failed_attempts=0 where employee_id=p.id;
 -- Catch expected punch errors without rolling back the outer attempt counter.
 begin
  if p_action not in ('check_in','check_out') or p_action is null then raise exception 'Invalid attendance action'; end if;
  result:=attendance_private.write_punch(p.id,p_ip,p_action,case when d.kind='kiosk' then 'kiosk'::public.attendance_source else 'app'::public.attendance_source end,d.id,case when d.kind='temporary' then 'temporary device' else 'kiosk' end);
 exception when others then
  get stacked diagnostics why=message_text;
  insert into public.audit_log(actor_id,table_name,record_id,employee_id,device_id,action,reason) values(p.id,'attendance',null,p.id,d.id,'PUNCH_REJECTED',why);
  return jsonb_build_object('ok',false,'code','PUNCH_REJECTED','error',why);
 end;
 update attendance_private.device_credentials set unknown_id_failures=0 where device_id=d.id;
 return jsonb_build_object('ok',true,'attendance',result);
end $$;

revoke all on all functions in schema attendance_private from public,anon,authenticated,service_role;
revoke all on function public.expire_attendance_devices(),public.manage_attendance_fallback(uuid,text,jsonb,inet),public.manual_attendance(uuid,uuid,timestamptz,timestamptz,text,inet,uuid),public.device_attendance(uuid,text,text,text,text,text,inet) from public,anon,authenticated;
grant execute on function public.expire_attendance_devices(),public.manage_attendance_fallback(uuid,text,jsonb,inet),public.manual_attendance(uuid,uuid,timestamptz,timestamptz,text,inet,uuid),public.device_attendance(uuid,text,text,text,text,text,inet) to service_role;
-- The original service-only attendance RPC retains its grants and signature.
commit;
