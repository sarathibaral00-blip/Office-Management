begin;
create type public.app_role as enum ('super_admin','hr','manager','employee');
create type public.attendance_status as enum ('present','late','absent');
create type public.leave_status as enum ('pending','approved','rejected','cancelled');
create type public.payroll_status as enum ('draft','approved','paid');
create table public.departments(id uuid primary key default gen_random_uuid(), name text not null unique, created_at timestamptz not null default now());
create table public.branches(id uuid primary key default gen_random_uuid(), name text not null unique, timezone text not null default 'Asia/Dhaka', created_at timestamptz not null default now());
create table public.shifts(id uuid primary key default gen_random_uuid(), name text not null unique, starts_at time not null default '09:00', ends_at time not null default '18:00', grace_minutes integer not null default 15 check(grace_minutes between 0 and 120), work_days integer[] not null default array[0,1,2,3,4] check(cardinality(work_days)>0 and work_days <@ array[0,1,2,3,4,5,6]), is_default boolean not null default false);
create unique index shifts_one_default on public.shifts(is_default) where is_default;
create table public.profiles(id uuid primary key references auth.users(id) on delete cascade, full_name text not null default '', email text, role public.app_role not null default 'employee', department_id uuid references public.departments(id), branch_id uuid references public.branches(id), designation text, salary numeric(14,2) not null default 0 check(salary>=0), manager_id uuid references public.profiles(id), shift_id uuid references public.shifts(id), joined_at date not null default current_date, is_active boolean not null default true, created_at timestamptz not null default now(), check(manager_id is distinct from id));
create table public.allowed_networks(id uuid primary key default gen_random_uuid(), label text not null check(length(trim(label))>0), branch_id uuid not null references public.branches(id), network cidr not null, is_active boolean not null default true, created_at timestamptz not null default now(), unique(branch_id,network));
create table public.attendance(id uuid primary key default gen_random_uuid(), employee_id uuid not null references public.profiles(id), branch_id uuid not null references public.branches(id), work_date date not null, check_in timestamptz not null, check_out timestamptz, status public.attendance_status not null, client_ip inet not null, created_at timestamptz not null default now(), unique(employee_id,work_date), check(check_out is null or check_out>=check_in));
create unique index attendance_one_open on public.attendance(employee_id) where check_out is null;
create table public.holidays(id uuid primary key default gen_random_uuid(), name text not null, holiday_date date not null, branch_id uuid references public.branches(id));
create table public.leave_types(id uuid primary key default gen_random_uuid(), name text not null unique, annual_days numeric(5,1) not null check(annual_days>=0), is_paid boolean not null default true);
create table public.leave_balances(id uuid primary key default gen_random_uuid(), employee_id uuid not null references public.profiles(id), leave_type_id uuid not null references public.leave_types(id), year integer not null check(year between 2000 and 2200), allocated numeric(5,1) not null check(allocated>=0), used numeric(5,1) not null default 0 check(used>=0 and used<=allocated), unique(employee_id,leave_type_id,year));
create table public.leave_requests(id uuid primary key default gen_random_uuid(), employee_id uuid not null references public.profiles(id), leave_type_id uuid not null references public.leave_types(id), starts_on date not null, ends_on date not null, reason text not null, status public.leave_status not null default 'pending', reviewed_by uuid references public.profiles(id), created_at timestamptz not null default now(), check(ends_on>=starts_on));
create table public.payroll(id uuid primary key default gen_random_uuid(), employee_id uuid not null references public.profiles(id), month date not null check(extract(day from month)=1), basic numeric(14,2) not null check(basic>=0), allowances numeric(14,2) not null default 0 check(allowances>=0), deductions numeric(14,2) not null default 0 check(deductions>=0), net numeric(14,2) generated always as (basic+allowances-deductions) stored, status public.payroll_status not null default 'draft', paid_at timestamptz, unique(employee_id,month));
create table public.announcements(id uuid primary key default gen_random_uuid(), title text not null, body text not null, branch_id uuid references public.branches(id), published_by uuid not null references public.profiles(id), published_at timestamptz not null default now());
create table public.audit_log(id bigint generated always as identity primary key, actor_id uuid, table_name text not null, record_id text, action text not null, created_at timestamptz not null default now());
create function public.current_role() returns public.app_role language sql stable security definer set search_path='' as $$ select role from public.profiles where id=(select auth.uid()) and is_active $$;
create function public.is_hr() returns boolean language sql stable security definer set search_path='' as $$ select coalesce(public.current_role() in ('super_admin','hr'),false) $$;
create function public.can_read_employee(target uuid) returns boolean language sql stable security definer set search_path='' as $$ select public.current_role() is not null and (target=(select auth.uid()) or public.is_hr() or (public.current_role()='manager' and exists(select 1 from public.profiles where id=target and manager_id=(select auth.uid())))) $$;
create function public.protect_profile() returns trigger language plpgsql set search_path='' as $$ begin
if coalesce(auth.role(),'') <> 'service_role' and current_user <> 'postgres' then
 if new.id is distinct from old.id then raise exception 'Profile identity cannot change'; end if;
 if new.role is distinct from old.role or new.salary is distinct from old.salary or new.is_active is distinct from old.is_active or new.manager_id is distinct from old.manager_id or new.branch_id is distinct from old.branch_id or new.department_id is distinct from old.department_id or new.shift_id is distinct from old.shift_id or new.joined_at is distinct from old.joined_at or new.designation is distinct from old.designation or new.email is distinct from old.email then
  if old.id=auth.uid() or not public.is_hr() then raise exception 'Protected profile fields'; end if;
  if public.current_role()<>'super_admin' and (old.role='super_admin' or new.role='super_admin') then raise exception 'Only super admin manages super admins'; end if;
 end if;
end if; return new; end $$;
create trigger protect_profile before update on public.profiles for each row execute function public.protect_profile();
create function public.handle_signup() returns trigger language plpgsql security definer set search_path='' as $$ begin insert into public.profiles(id,email,full_name) values(new.id,new.email,coalesce(new.raw_user_meta_data->>'full_name','')); return new; end $$;
create trigger on_auth_user_created after insert on auth.users for each row execute function public.handle_signup();
create function public.audit_change() returns trigger language plpgsql security definer set search_path='' as $$ begin insert into public.audit_log(actor_id,table_name,record_id,action) values(auth.uid(),tg_table_name,coalesce(new.id::text,old.id::text),tg_op); return coalesce(new,old); end $$;
do $$ declare t text; begin
foreach t in array array['profiles','departments','branches','allowed_networks','attendance','shifts','holidays','leave_types','leave_balances','leave_requests','payroll','announcements','audit_log'] loop
 execute format('alter table public.%I enable row level security',t);
 execute format('revoke all on public.%I from anon, authenticated',t);
 execute format('grant select on public.%I to authenticated',t);
 if t <> 'audit_log' then execute format('create trigger audit_change after insert or update or delete on public.%I for each row execute function public.audit_change()',t); end if;
end loop;
foreach t in array array['departments','branches','shifts','holidays','leave_types','announcements'] loop
 execute format('create policy read_active on public.%I for select to authenticated using (public.current_role() is not null)',t);
 execute format('create policy hr_manage on public.%I for all to authenticated using (public.is_hr()) with check(public.is_hr())',t);
 execute format('grant insert, update, delete on public.%I to authenticated',t);
end loop;
foreach t in array array['attendance','leave_balances','leave_requests','payroll'] loop
 execute format('create policy employee_read on public.%I for select to authenticated using (public.can_read_employee(employee_id))',t);
end loop;
foreach t in array array['leave_balances','payroll'] loop
 execute format('create policy hr_manage on public.%I for all to authenticated using(public.is_hr()) with check(public.is_hr())',t);
 execute format('grant insert,update,delete on public.%I to authenticated',t);
end loop;
end $$;
create policy profile_read on public.profiles for select to authenticated using(public.can_read_employee(id));
create policy profile_update on public.profiles for update to authenticated using(public.current_role() is not null and (id=(select auth.uid()) or public.is_hr())) with check(public.current_role() is not null and (id=(select auth.uid()) or public.is_hr()));
grant update on public.profiles to authenticated;
create policy networks_hr on public.allowed_networks for all to authenticated using(public.is_hr()) with check(public.is_hr());
grant insert,update,delete on public.allowed_networks to authenticated;
create policy leave_submit on public.leave_requests for insert to authenticated with check(employee_id=(select auth.uid()) and public.current_role() is not null and status='pending' and reviewed_by is null);
grant insert on public.leave_requests to authenticated;
create policy audit_read on public.audit_log for select to authenticated using(public.current_role()='super_admin');
-- Approval and attendance mutations are deliberately service-only.
revoke all on function public.handle_signup(), public.audit_change(), public.protect_profile() from public,anon,authenticated;
revoke all on function public.current_role(),public.is_hr(),public.can_read_employee(uuid) from public,anon;
grant execute on function public.current_role(),public.is_hr(),public.can_read_employee(uuid) to authenticated;
do $$ declare r record; begin for r in select conrelid::regclass as tbl, a.attname as col from pg_constraint c join pg_attribute a on a.attrelid=c.conrelid and a.attnum=c.conkey[1] where c.contype='f' and c.connamespace='public'::regnamespace loop execute format('create index if not exists %I on %s (%I)',replace(r.tbl::text,'.','_')||'_'||r.col||'_idx',r.tbl,r.col); end loop; end $$;
create index attendance_work_date_idx on public.attendance(work_date);
create index holidays_date_idx on public.holidays(holiday_date);
create index audit_created_at_idx on public.audit_log(created_at);
insert into public.shifts(name,is_default) values('Default office shift',true);
insert into public.leave_types(name,annual_days,is_paid) values ('Casual',10,true),('Sick',14,true),('Annual',15,true),('Unpaid',0,false);
commit;
