begin;
create table public.role_permissions(role public.app_role not null,permission text not null,enabled boolean not null default false,primary key(role,permission));
alter table public.role_permissions enable row level security;revoke all on public.role_permissions from public,anon,authenticated;grant select on public.role_permissions to authenticated;grant all on public.role_permissions to service_role;
create policy permission_own_role_read on public.role_permissions for select to authenticated using(role=(select public.current_role()) or (select public.current_role())='super_admin');
insert into public.role_permissions(role,permission,enabled) select r::public.app_role,k,(r in ('hr','super_admin') or k='reports.export_own' or (r='manager' and k='reports.export_team')) from unnest(array['employee','manager','hr','super_admin']) r cross join unnest(array['payroll.manage','financing.review','expenses.review','documents.manage','letters.issue','reports.export_all','reports.export_team','reports.export_own','settings.manage','audit.view']) k;
create function public.has_permission(p_key text) returns boolean language sql stable security definer set search_path='' as $$
 select coalesce(public.current_role() is not null and
 (p_key='reports.export_own' or (public.current_role()='manager' and p_key='reports.export_team') or public.current_role() in ('hr','super_admin'))
 and p_key=any(array['payroll.manage','financing.review','expenses.review','documents.manage','letters.issue','reports.export_all','reports.export_team','reports.export_own','settings.manage','audit.view'])
 and (public.current_role()='super_admin' or exists(select 1 from public.role_permissions where role=public.current_role() and permission=p_key and enabled)),false)
$$;
revoke all on function public.has_permission(text) from public,anon;grant execute on function public.has_permission(text) to authenticated;
create trigger audit_change after update on public.role_permissions for each row execute function public.audit_change();
create table public.company_settings(
 singleton boolean primary key default true check(singleton),company_name text not null default 'Pride People',address text not null default '',registration_no text not null default '',currency text not null default 'BDT',logo_path text,signature_path text,
 deduct_absence boolean not null default true,late_fee numeric(14,2) not null default 0 check(late_fee>=0),free_lates integer not null default 0 check(free_lates>=0),overtime_multiplier numeric(6,2) not null default 0 check(overtime_multiplier between 0 and 5),max_daily_overtime numeric(4,1) not null default 4 check(max_daily_overtime between 0 and 12),updated_at timestamptz not null default now()
);
insert into public.company_settings default values;
create table public.salary_structures(
 employee_id uuid primary key references public.profiles(id),basic numeric(14,2) not null check(basic>=0),house_rent numeric(14,2) not null default 0 check(house_rent>=0),medical numeric(14,2) not null default 0 check(medical>=0),conveyance numeric(14,2) not null default 0 check(conveyance>=0),bank_name text not null default '',account_name text not null default '',account_number text not null default '',updated_at timestamptz not null default now()
);
create table public.payroll_runs(
 id uuid primary key default gen_random_uuid(),month date not null unique check(extract(day from month)=1),status text not null default 'draft' check(status in ('draft','approved','locked')),
 created_by uuid not null references public.profiles(id),approved_by uuid references public.profiles(id),locked_by uuid references public.profiles(id),created_at timestamptz not null default now(),approved_at timestamptz,locked_at timestamptz,policy_snapshot jsonb not null,company_snapshot jsonb not null
);
alter table public.payroll add column run_id uuid references public.payroll_runs(id),add column house_rent numeric(14,2) not null default 0,add column medical numeric(14,2) not null default 0,add column conveyance numeric(14,2) not null default 0,add column bonus numeric(14,2) not null default 0,add column overtime_pay numeric(14,2) not null default 0,add column absence_deduction numeric(14,2) not null default 0,add column late_deduction numeric(14,2) not null default 0,add column installment_deduction numeric(14,2) not null default 0,add column extra_deduction numeric(14,2) not null default 0,add column locked_at timestamptz,add column calculation jsonb not null default '{}',add column employee_snapshot jsonb not null default '{}';
create index payroll_run_idx on public.payroll(run_id);create index payroll_runs_creator_idx on public.payroll_runs(created_by);create index payroll_runs_approver_idx on public.payroll_runs(approved_by);create index payroll_runs_locker_idx on public.payroll_runs(locked_by);
do $$ declare t text;begin foreach t in array array['company_settings','salary_structures','payroll_runs'] loop
 execute format('alter table public.%I enable row level security',t);execute format('revoke all on public.%I from public,anon,authenticated',t);execute format('grant select on public.%I to authenticated',t);execute format('grant all on public.%I to service_role',t);
 execute format('create trigger audit_change after insert or update on public.%I for each row execute function public.audit_change()',t);
 end loop;end $$;
create policy company_hr_read on public.company_settings for select to authenticated using((select public.has_permission('settings.manage')));
create policy salary_private_read on public.salary_structures for select to authenticated using((select public.current_role()) is not null and (employee_id=(select auth.uid()) or (select public.has_permission('payroll.manage'))));
create policy runs_hr_read on public.payroll_runs for select to authenticated using((select public.has_permission('payroll.manage')));
alter policy employee_read on public.payroll using((select public.current_role()) is not null and employee_id=(select auth.uid()) and (locked_at is not null or (run_id is null and status in ('approved','paid'))));
revoke insert,update,delete on public.payroll from authenticated;
alter policy hr_manage on public.payroll using((select public.has_permission('payroll.manage'))) with check((select public.has_permission('payroll.manage')));
create function public.guard_locked_payroll() returns trigger language plpgsql set search_path='' as $$
declare run uuid;begin
 if tg_table_name='payroll_runs' then
  if old.locked_at is not null or old.status='locked' then raise exception 'Locked payroll runs are immutable';end if;
 else
  if tg_op<>'INSERT' and (old.locked_at is not null or old.status='paid') then raise exception 'Locked payslips are immutable';end if;
  run:=case when tg_op='DELETE' then old.run_id else new.run_id end;
  if exists(select 1 from public.payroll_runs where id=run and status='locked') then raise exception 'Locked payroll cannot be changed';end if;
  if tg_op='UPDATE' and old.run_id is distinct from new.run_id then raise exception 'Payroll run identity is immutable';end if;
 end if;return coalesce(new,old);
end $$;
create trigger guard_locked_payroll before update or delete on public.payroll_runs for each row execute function public.guard_locked_payroll();
create trigger guard_locked_payroll before insert or update or delete on public.payroll for each row execute function public.guard_locked_payroll();
create function public.save_salary_structure(p_employee uuid,p_data jsonb) returns void language plpgsql security definer set search_path='' as $$
declare old public.salary_structures;b numeric;h numeric;m numeric;c numeric;begin
 if not public.is_hr() or not public.has_permission('payroll.manage') then raise exception 'HR access required';end if;
 perform 1 from public.profiles where id=p_employee for update;if not found then raise exception 'Employee not found';end if;
 select * into old from public.salary_structures where employee_id=p_employee;
 b:=(p_data->>'basic')::numeric;h:=(p_data->>'house_rent')::numeric;m:=(p_data->>'medical')::numeric;c:=(p_data->>'conveyance')::numeric;
 if b is null or h is null or m is null or c is null or least(b,h,m,c)<0 or b::text in ('NaN','Infinity','-Infinity') or h::text in ('NaN','Infinity','-Infinity') or m::text in ('NaN','Infinity','-Infinity') or c::text in ('NaN','Infinity','-Infinity') then raise exception 'Enter finite, non-negative salary components';end if;
 if p_employee=auth.uid() and (old.employee_id is null or b<>old.basic or h<>old.house_rent or m<>old.medical or c<>old.conveyance) then raise exception 'You cannot change your own salary structure';end if;
 perform set_config('app.audit_reason','HR updated salary structure and banking details',true);
 update public.profiles set salary=b+h+m+c where id=p_employee and p_employee<>auth.uid() and salary is distinct from b+h+m+c;
 insert into public.salary_structures(employee_id,basic,house_rent,medical,conveyance,bank_name,account_name,account_number) values(p_employee,b,h,m,c,coalesce(p_data->>'bank_name',''),coalesce(p_data->>'account_name',''),coalesce(p_data->>'account_number',''))
 on conflict(employee_id) do update set basic=b,house_rent=h,medical=m,conveyance=c,bank_name=excluded.bank_name,account_name=excluded.account_name,account_number=excluded.account_number,updated_at=now();
end $$;
-- Payroll uses active holidays only without altering the existing leave API.
create function public.payroll_workdays(p_employee uuid,p_start date,p_end date) returns table(day date)
language sql stable security definer set search_path='' as $$
 select d::date from public.profiles p
 left join public.shifts assigned on assigned.id=p.shift_id
 left join public.shifts fallback on fallback.is_default,
 pg_catalog.generate_series(p_start::timestamp,p_end::timestamp,interval '1 day') d
 where p.id=p_employee and extract(dow from d)::integer=any(coalesce(assigned.work_days,fallback.work_days,array[0,1,2,3,4]))
 and not exists(select 1 from public.holidays h where h.is_active and h.holiday_date=d::date and (h.branch_id is null or h.branch_id=p.branch_id))
$$;
revoke all on function public.payroll_workdays(uuid,date,date) from public,anon,authenticated;
create function public.generate_payroll(p_month date) returns uuid language plpgsql security definer set search_path='' as $$
declare run uuid;p public.profiles;st public.salary_structures;s public.shifts;cfg public.company_settings;b public.branches;days numeric;eligible numeric;absent numeric;late_count integer;ot numeric;gross numeric;ratio numeric;absence_fee numeric;late_amount numeric;ot_amount numeric;daily record;leave_paid numeric;leave_all numeric;start_day date;finish date;
begin
 if not public.is_hr() or not public.has_permission('payroll.manage') then raise exception 'HR access required';end if;
 if p_month is null or extract(day from p_month)<>1 then raise exception 'Choose the first day of a month';end if;
 perform pg_advisory_xact_lock(hashtext('payroll-generation'));
 perform pg_advisory_xact_lock(hashtext('payroll:'||p_month));
 perform set_config('app.audit_reason','Monthly payroll generation '||p_month,true);
 finish:=(p_month+interval '1 month')::date-1;
 if finish>=current_date then raise exception 'Run payroll only after the month is fully closed';end if;
 if exists(select 1 from public.payroll_runs where month=p_month) or exists(select 1 from public.payroll where month=p_month) then raise exception 'Payroll already exists for this month; existing data is preserved';end if;
 if exists(select 1 from public.payroll_runs where month>p_month) then raise exception 'Generate payroll chronologically; a newer run already exists';end if;
 perform 1 from public.profiles where joined_at<=finish and (is_active or exists(select 1 from public.attendance a where a.employee_id=profiles.id and a.work_date between p_month and finish)) order by id for update;
 lock table public.shifts,public.holidays,public.leave_requests,public.branches in share mode;
 select * into cfg from public.company_settings where singleton;
 insert into public.payroll_runs(month,created_by,policy_snapshot,company_snapshot) values(p_month,auth.uid(),to_jsonb(cfg)-'logo_path'-'signature_path',jsonb_build_object('company_name',cfg.company_name,'address',cfg.address,'currency',cfg.currency,'registration_no',cfg.registration_no,'logo_path',cfg.logo_path)) returning id into run;
 for p in select * from public.profiles where joined_at<=finish and (is_active or exists(select 1 from public.attendance a where a.employee_id=profiles.id and a.work_date between p_month and finish)) order by id for update loop
  select * into b from public.branches where id=p.branch_id;if not found then raise exception 'Assign every included employee to a branch before running payroll';end if;
  if finish>=(now() at time zone b.timezone)::date then raise exception 'Month is not closed in every branch';end if;
  select * into s from public.shifts where id=p.shift_id;if not found then select * into s from public.shifts where is_default;end if;if s.id is null then raise exception 'Configure a shift before running payroll';end if;
  if exists(select 1 from public.attendance where employee_id=p.id and work_date between p_month and finish and check_out is null) then raise exception 'Resolve open attendance before running payroll';end if;
  select * into st from public.salary_structures where employee_id=p.id;if not found then st.basic:=p.salary;st.house_rent:=0;st.medical:=0;st.conveyance:=0;end if;
  select count(*) into days from public.payroll_workdays(p.id,p_month,finish);start_day:=greatest(p_month,p.joined_at);select count(*) into eligible from public.payroll_workdays(p.id,start_day,finish);
  ratio:=case when days>0 then eligible/days else 1 end;gross:=round(st.basic*ratio,2)+round(st.house_rent*ratio,2)+round(st.medical*ratio,2)+round(st.conveyance*ratio,2);absent:=0;ot:=0;
  for daily in select w.day,a.check_in,a.check_out,a.status from public.payroll_workdays(p.id,start_day,finish) w left join public.attendance a on a.employee_id=p.id and a.work_date=w.day loop
   select coalesce(sum(case when r.is_half_day then 0.5 else 1 end),0),coalesce(sum(case when t.is_paid then case when r.is_half_day then 0.5 else 1 end else 0 end),0) into leave_all,leave_paid from public.leave_requests r join public.leave_types t on t.id=r.leave_type_id where r.employee_id=p.id and r.status='approved' and daily.day between r.starts_on and r.ends_on;
   if daily.check_in is null or daily.status='absent' then absent:=absent+greatest(0,1-least(1,leave_paid));else absent:=absent+greatest(0,least(1,leave_all)-least(1,leave_paid));end if;
   if daily.check_out is not null and daily.status in ('present','late') then ot:=ot+least(cfg.max_daily_overtime,greatest(0,extract(epoch from daily.check_out-daily.check_in)/3600-extract(epoch from ((daily.day+case when s.ends_at<=s.starts_at then 1 else 0 end+s.ends_at)-(daily.day+s.starts_at)))/3600));end if;
  end loop;
  select count(*) into late_count from public.attendance a join public.payroll_workdays(p.id,start_day,finish) w on w.day=a.work_date where a.employee_id=p.id and a.status='late';
  absence_fee:=case when cfg.deduct_absence and days>0 then round((st.basic+st.house_rent+st.medical+st.conveyance)/days*absent,2) else 0 end;
  absence_fee:=least(absence_fee,gross);
  late_amount:=round(greatest(0,late_count-cfg.free_lates)*cfg.late_fee,2);
  ot_amount:=case when days>0 then round(ot*cfg.overtime_multiplier*st.basic/(days*greatest(1,extract(epoch from ((p_month+case when s.ends_at<=s.starts_at then 1 else 0 end+s.ends_at)-(p_month+s.starts_at)))/3600)),2) else 0 end;
  late_amount:=least(late_amount,greatest(0,gross+ot_amount-absence_fee));
  insert into public.payroll(employee_id,month,run_id,basic,house_rent,medical,conveyance,allowances,deductions,absence_deduction,late_deduction,overtime_pay,employee_snapshot,calculation)
  values(p.id,p_month,run,round(st.basic*ratio,2),round(st.house_rent*ratio,2),round(st.medical*ratio,2),round(st.conveyance*ratio,2),round(st.house_rent*ratio,2)+round(st.medical*ratio,2)+round(st.conveyance*ratio,2)+ot_amount,least(gross+ot_amount,absence_fee+late_amount),absence_fee,late_amount,ot_amount,
  jsonb_build_object('name',p.full_name,'code',p.employee_code,'designation',p.designation,'bank_name',coalesce(st.bank_name,''),'account_name',coalesce(st.account_name,p.full_name),'account_number',coalesce(st.account_number,''),'company',jsonb_build_object('name',cfg.company_name,'address',cfg.address,'currency',cfg.currency,'logo_path',cfg.logo_path)),
  jsonb_build_object('scheduled_days',days,'eligible_days',eligible,'absent_units',absent,'late_count',late_count,'overtime_hours',ot,'policy',to_jsonb(cfg)-'signature_path','shift',to_jsonb(s),'leave',coalesce((select jsonb_agg(to_jsonb(l)||jsonb_build_object('paid',t.is_paid)) from public.leave_requests l join public.leave_types t on t.id=l.leave_type_id where l.employee_id=p.id and l.status='approved' and l.starts_on<=finish and l.ends_on>=p_month),'[]'::jsonb),'holidays',coalesce((select jsonb_agg(to_jsonb(h)) from public.holidays h where h.is_active and h.holiday_date between p_month and finish and (h.branch_id is null or h.branch_id=p.branch_id)),'[]'::jsonb),'attendance',coalesce((select jsonb_agg(to_jsonb(a)) from public.attendance a where a.employee_id=p.id and a.work_date between p_month and finish),'[]'::jsonb)));
 end loop;
 if not exists(select 1 from public.payroll where run_id=run) then raise exception 'No eligible employees';end if;return run;
end $$;
create function public.adjust_payroll(p_id uuid,p_bonus numeric,p_extra numeric,p_reason text) returns void language plpgsql security definer set search_path='' as $$ declare row public.payroll;r public.payroll_runs;begin
 if not public.is_hr() or not public.has_permission('payroll.manage') then raise exception 'HR access required';end if;
 select * into row from public.payroll where id=p_id;select * into r from public.payroll_runs where id=row.run_id for update;
 if r.id is null or r.status<>'draft' then raise exception 'Only draft payroll can be adjusted';end if;
 if row.employee_id=auth.uid() then raise exception 'You cannot adjust your own payslip';end if;
 if p_bonus is null or p_extra is null or least(p_bonus,p_extra)<0 or p_bonus::text in ('NaN','Infinity','-Infinity') or p_extra::text in ('NaN','Infinity','-Infinity') or length(trim(coalesce(p_reason,'')))<3 then raise exception 'Valid amounts and a reason are required';end if;
 if row.basic+row.house_rent+row.medical+row.conveyance+row.overtime_pay+p_bonus<row.absence_deduction+row.late_deduction+row.installment_deduction+p_extra then raise exception 'Deductions cannot exceed gross pay';end if;
 perform set_config('app.audit_reason',p_reason,true);
 update public.payroll set bonus=p_bonus,extra_deduction=p_extra,allowances=house_rent+medical+conveyance+overtime_pay+p_bonus,deductions=absence_deduction+late_deduction+installment_deduction+p_extra where id=p_id;
end $$;
create function public.transition_payroll(p_run uuid,p_action text) returns void language plpgsql security definer set search_path='' as $$ declare r public.payroll_runs;begin
 if not public.is_hr() or not public.has_permission('payroll.manage') then raise exception 'HR access required';end if;select * into r from public.payroll_runs where id=p_run for update;
 if r.id is null then raise exception 'Run not found';end if;
 perform set_config('app.audit_reason','Payroll run '||p_action||' '||r.month,true);
 if p_action='approve' and r.status='draft' then
  if r.created_by=auth.uid() then raise exception 'A different HR or super admin must approve this run';end if;
  update public.payroll_runs set status='approved',approved_by=auth.uid(),approved_at=now() where id=r.id;update public.payroll set status='approved' where run_id=r.id;
 elsif p_action='lock' and r.status='approved' then
  update public.payroll set locked_at=now() where run_id=r.id;update public.payroll_runs set status='locked',locked_by=auth.uid(),locked_at=now() where id=r.id;
 else raise exception 'Invalid payroll transition';end if;
end $$;
revoke all on function public.guard_locked_payroll() from public,anon,authenticated;
revoke all on function public.save_salary_structure(uuid,jsonb),public.generate_payroll(date),public.adjust_payroll(uuid,numeric,numeric,text),public.transition_payroll(uuid,text) from public,anon;
grant execute on function public.save_salary_structure(uuid,jsonb),public.generate_payroll(date),public.adjust_payroll(uuid,numeric,numeric,text),public.transition_payroll(uuid,text) to authenticated;
commit;
