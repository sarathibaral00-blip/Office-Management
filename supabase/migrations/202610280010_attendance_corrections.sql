begin;
create table public.attendance_correction_requests(
 id uuid primary key default gen_random_uuid(), employee_id uuid not null references public.profiles(id),
 attendance_id uuid not null references public.attendance(id), requested_check_in timestamptz not null,
 requested_check_out timestamptz, reason text not null check(length(trim(reason))>=3),
 original_values jsonb not null, status text not null default 'pending' check(status in ('pending','approved','rejected')),
 reviewed_by uuid references public.profiles(id), review_comment text, created_at timestamptz not null default now(), reviewed_at timestamptz,
 check(requested_check_out is null or requested_check_out>=requested_check_in)
);
create unique index correction_one_pending_idx on public.attendance_correction_requests(attendance_id) where status='pending';
create index correction_employee_idx on public.attendance_correction_requests(employee_id,created_at);
create index correction_reviewer_idx on public.attendance_correction_requests(reviewed_by);
alter table public.attendance_correction_requests enable row level security;
revoke all on public.attendance_correction_requests from public,anon,authenticated;
grant select on public.attendance_correction_requests to authenticated;
grant all on public.attendance_correction_requests to service_role;
create policy correction_read on public.attendance_correction_requests for select to authenticated using(public.can_read_employee(employee_id));
create trigger audit_change after insert or update on public.attendance_correction_requests for each row execute function public.audit_change();
create function public.request_attendance_correction(p_attendance uuid,p_in timestamptz,p_out timestamptz,p_reason text) returns uuid
language plpgsql security definer set search_path='' as $$ declare a public.attendance; result uuid; begin
 if public.current_role() is null then raise exception 'Active employee required'; end if;
 perform 1 from public.profiles where id=auth.uid() for update;
 select * into a from public.attendance where id=p_attendance and employee_id=auth.uid() for update;
 if not found then raise exception 'Choose your own existing attendance record. Ask HR to add wholly missing days'; end if;
 if p_in is null or p_in>now() or p_out>now() or p_out<p_in or length(trim(coalesce(p_reason,'')))<3 then raise exception 'Valid past timestamps and a reason are required'; end if;
 if p_in=a.check_in and p_out is not distinct from a.check_out then raise exception 'No attendance change requested'; end if;
 insert into public.attendance_correction_requests(employee_id,attendance_id,requested_check_in,requested_check_out,reason,original_values) values(auth.uid(),a.id,p_in,p_out,trim(p_reason),to_jsonb(a)) returning id into result;
 return result;
end $$;
create function public.review_attendance_correction(p_id uuid,p_approve boolean,p_comment text) returns void
language plpgsql security definer set search_path='' as $$
declare r public.attendance_correction_requests; a public.attendance; p public.profiles; s public.shifts; b public.branches; day date;
begin
 if not public.is_hr() then raise exception 'HR access required'; end if;
 select * into r from public.attendance_correction_requests where id=p_id;
 if not found or r.employee_id=auth.uid() then raise exception 'You cannot review this request'; end if;
 select * into p from public.profiles where id=r.employee_id for update;
 select * into r from public.attendance_correction_requests where id=p_id for update;
 if r.status<>'pending' or p_approve is null or length(trim(coalesce(p_comment,'')))<3 then raise exception 'A pending request and review comment are required'; end if;
 perform set_config('app.audit_actor',auth.uid()::text,true);
 perform set_config('app.audit_reason','Attendance correction: '||r.reason||' / Review: '||trim(p_comment),true);
 if p_approve then
  select * into a from public.attendance where id=r.attendance_id for update;
  if to_jsonb(a) is distinct from r.original_values then raise exception 'Attendance changed since submission; reject and request a fresh correction'; end if;
  select * into b from public.branches where id=a.branch_id;
  select * into s from public.shifts where id=p.shift_id;
  if not found then select * into s from public.shifts where is_default; end if;
  if s.id is null then raise exception 'Configure the employee shift first'; end if;
  day:=(r.requested_check_in at time zone b.timezone)::date;
  if s.ends_at<=s.starts_at and (r.requested_check_in at time zone b.timezone)::time<s.ends_at then day:=day-1; end if;
  if day<>a.work_date then raise exception 'Correction must preserve the original work date'; end if;
  update public.attendance set check_in=r.requested_check_in,check_out=r.requested_check_out,source='correction',manual_reason=r.reason,recorded_by=auth.uid(),status=case when r.requested_check_in>((day+s.starts_at) at time zone b.timezone)+make_interval(mins=>s.grace_minutes) then 'late'::public.attendance_status else 'present'::public.attendance_status end where id=a.id;
 end if;
 update public.attendance_correction_requests set status=case when p_approve then 'approved' else 'rejected' end,reviewed_by=auth.uid(),review_comment=trim(p_comment),reviewed_at=now() where id=r.id;
end $$;
revoke all on function public.request_attendance_correction(uuid,timestamptz,timestamptz,text),public.review_attendance_correction(uuid,boolean,text) from public,anon;
grant execute on function public.request_attendance_correction(uuid,timestamptz,timestamptz,text),public.review_attendance_correction(uuid,boolean,text) to authenticated;
commit;
