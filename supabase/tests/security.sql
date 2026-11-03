-- Run against the dev project with postgres privileges after migrations.
-- Fixtures and all changes roll back. No existing data is deleted.
begin;
insert into auth.users(id,email,raw_user_meta_data) values
 ('00000000-0000-4000-a000-000000000001','v1-employee-test@example.invalid','{"role":"super_admin","salary":999999}'),
 ('00000000-0000-4000-a000-000000000002','v1-other-test@example.invalid','{}');
do $$ begin
 if (select role from public.profiles where id='00000000-0000-4000-a000-000000000001')<>'employee' then raise exception 'Signup metadata escalated role'; end if;
 if exists(select 1 from pg_tables where schemaname='public' and tablename in ('profiles','departments','branches','allowed_networks','attendance','shifts','holidays','leave_types','leave_balances','leave_requests','payroll','announcements','audit_log') and not rowsecurity) then raise exception 'RLS missing'; end if;
 if has_table_privilege('authenticated','public.attendance','INSERT') or has_table_privilege('authenticated','public.attendance','UPDATE') then raise exception 'Direct attendance writes permitted'; end if;
 if has_function_privilege('authenticated','public.record_attendance(uuid,inet,text)','execute') then raise exception 'Attendance RPC exposed'; end if;
end $$;
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-a000-000000000001","role":"authenticated"}',true);
do $$ begin
 if (select count(*) from public.profiles)<>1 then raise exception 'Employee profile isolation failed'; end if;
 begin
  update public.profiles set role='super_admin' where id=auth.uid();
  raise exception 'Role escalation permitted';
 exception when raise_exception then if SQLERRM='Role escalation permitted' then raise; end if; end;
 begin
  update public.profiles set salary=999 where id=auth.uid();
  raise exception 'Salary edit permitted';
 exception when raise_exception then if SQLERRM='Salary edit permitted' then raise; end if; end;
 begin
  update public.profiles set is_active=false where id=auth.uid();
  raise exception 'Active flag edit permitted';
 exception when raise_exception then if SQLERRM='Active flag edit permitted' then raise; end if; end;
 if exists(select 1 from public.allowed_networks) then raise exception 'Network administration exposed'; end if;
end $$;
reset role;
rollback;
