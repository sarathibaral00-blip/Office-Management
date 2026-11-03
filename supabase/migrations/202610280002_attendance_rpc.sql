begin;
create function public.record_attendance(p_employee uuid,p_ip inet,p_action text) returns jsonb language plpgsql security definer set search_path='' as $$
declare p public.profiles; s public.shifts; a public.attendance; b public.branches; stamp timestamptz:=now(); local_day date; local_clock time;
begin
 if p_action is null or p_action not in ('check_in','check_out','status') then raise exception 'Invalid action'; end if;
 select * into p from public.profiles where id=p_employee and is_active for update;
 if not found then raise exception 'Employee profile is inactive or missing'; end if;
 select * into b from public.branches where id=p.branch_id;
 if not found then raise exception 'Ask HR to assign your branch'; end if;
 if not exists(select 1 from public.allowed_networks where is_active and branch_id=p.branch_id and p_ip <<= network) then raise exception 'Connect to office WiFi'; end if;
 if p_action='status' then return jsonb_build_object('allowed',true,'ip',host(p_ip),'branch',b.name); end if;
 local_day:=(stamp at time zone b.timezone)::date;
 local_clock:=(stamp at time zone b.timezone)::time;
 if p_action='check_in' then
  select * into s from public.shifts where id=p.shift_id;
  if not found then select * into s from public.shifts where is_default; end if;
  if not found then raise exception 'Ask HR to configure your shift'; end if;
  if s.ends_at<=s.starts_at and local_clock<s.ends_at then local_day:=local_day-1; end if;
  if exists(select 1 from public.attendance where employee_id=p.id and (work_date=local_day or check_out is null)) then raise exception 'Already checked in. Check out your open attendance first'; end if;
  insert into public.attendance(employee_id,branch_id,work_date,check_in,status,client_ip) values(p.id,b.id,local_day,stamp,case when stamp > ((local_day+s.starts_at) at time zone b.timezone)+make_interval(mins=>s.grace_minutes) then 'late'::public.attendance_status else 'present'::public.attendance_status end,p_ip) returning * into a;
 else
  select * into a from public.attendance where employee_id=p.id and check_out is null for update;
  if not found then raise exception 'No open check-in to check out'; end if;
  update public.attendance set check_out=stamp where id=a.id returning * into a;
 end if;
 return to_jsonb(a);
end $$;
revoke all on function public.record_attendance(uuid,inet,text) from public,anon,authenticated;
grant execute on function public.record_attendance(uuid,inet,text) to service_role;
commit;
