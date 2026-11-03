-- Postgres-only dev verification, AFTER migrations 016–023. Not yet run remotely.
-- Fresh fixtures only; all changes roll back, including auth/signup effects.
begin;
insert into auth.users(id,email,raw_user_meta_data) values
('00000000-0000-4000-b000-000000000001','finance-own@example.invalid','{}'),
('00000000-0000-4000-b000-000000000002','finance-other@example.invalid','{}');
insert into public.payroll(employee_id,month,basic,status,locked_at) values
('00000000-0000-4000-b000-000000000001','2001-01-01',100,'approved',now()),
('00000000-0000-4000-b000-000000000002','2001-01-01',100,'approved',now());
do $$ declare t text;begin
 foreach t in array array['role_permissions','company_settings','salary_structures','payroll_runs','employee_financing','payroll_installments','expense_claims','employee_documents','generated_letters'] loop
  if not exists(select 1 from pg_tables where schemaname='public' and tablename=t and rowsecurity) then raise exception 'Missing RLS: %',t;end if;
  if has_table_privilege('authenticated','public.'||t,'INSERT') or has_table_privilege('authenticated','public.'||t,'UPDATE') or has_table_privilege('authenticated','public.'||t,'DELETE') then raise exception 'Direct financial writes exposed: %',t;end if;
 end loop;
 if exists(select 1 from storage.buckets where id in ('profile-photos','expense-receipts','employee-documents','company-assets') and public) then raise exception 'Private bucket is public';end if;
 begin
  update public.payroll set basic=101 where employee_id='00000000-0000-4000-b000-000000000001';
  raise exception 'TEST: locked payslip editable';
 exception when raise_exception then if SQLERRM='TEST: locked payslip editable' then raise;end if;end;
end $$;
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-b000-000000000001","role":"authenticated"}',true);
do $$ begin
 if (select count(*) from public.payroll)<>1 then raise exception 'Payslip isolation failed';end if;
 if public.has_permission('payroll.manage') or public.has_permission('documents.manage') or public.has_permission('settings.manage') then raise exception 'Employee capability escalation';end if;
 if exists(select 1 from public.payroll_runs) then raise exception 'Employee can read payroll runs';end if;
 if has_schema_privilege('authenticated','attendance_private','USAGE') then raise exception 'Private credentials exposed';end if;
 if has_table_privilege('authenticated','public.attendance','INSERT') or has_table_privilege('authenticated','public.attendance','UPDATE') then raise exception 'Direct attendance writes exposed';end if;
end $$;
reset role;
rollback;
-- Repeat all four test scripts with actual role JWTs and two teams; these
-- fixture assertions do not certify hosted gateways, Storage URLs or devices.
