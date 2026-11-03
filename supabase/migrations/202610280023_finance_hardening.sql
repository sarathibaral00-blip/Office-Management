begin;
-- Settings mutations go through capability-checked functions. Existing shifts,
-- employee assignments and attendance readers are unchanged.
revoke insert,update,delete on public.shifts from authenticated;
create function public.guard_finance_currency() returns trigger language plpgsql set search_path='' as $$ begin
 if new.currency is distinct from old.currency and (exists(select 1 from public.payroll) or exists(select 1 from public.employee_financing) or exists(select 1 from public.expense_claims) or exists(select 1 from public.salary_structures)) then raise exception 'Currency cannot change after financial records exist';end if;
 return new;
end $$;
create trigger guard_finance_currency before update of currency on public.company_settings for each row execute function public.guard_finance_currency();
create function public.guard_finance_identity() returns trigger language plpgsql set search_path='' as $$ begin
 if tg_op='DELETE' then raise exception 'Financial and document history cannot be deleted';end if;
 if tg_table_name='employee_financing' then
  if new.employee_id is distinct from old.employee_id or new.amount is distinct from old.amount or new.installments is distinct from old.installments or new.installment_amount is distinct from old.installment_amount or new.kind is distinct from old.kind or new.starts_month is distinct from old.starts_month then raise exception 'Submitted financing terms are immutable';end if;
 elsif tg_table_name='expense_claims' then
  if new.employee_id is distinct from old.employee_id or new.amount is distinct from old.amount or new.spent_on is distinct from old.spent_on or new.receipt_path is distinct from old.receipt_path then raise exception 'Submitted expense details are immutable';end if;
 else raise exception 'Document records are immutable';end if;
 return new;
end $$;
create trigger guard_finance_identity before update or delete on public.employee_financing for each row execute function public.guard_finance_identity();
create trigger guard_finance_identity before update or delete on public.expense_claims for each row execute function public.guard_finance_identity();
create trigger guard_finance_identity before update or delete on public.generated_letters for each row execute function public.guard_finance_identity();
create trigger guard_finance_identity before update or delete on public.employee_documents for each row execute function public.guard_finance_identity();
-- Do not silently broaden or overwrite any pre-existing bucket configuration.
do $$ declare b record;begin
 for b in select * from storage.buckets where id in ('expense-receipts','employee-documents','company-assets') loop
  if b.public or b.file_size_limit is null or b.file_size_limit>(case when b.id='company-assets' then 2097152 else 10485760 end) or b.allowed_mime_types is null or not (b.allowed_mime_types <@ (case when b.id='company-assets' then array['image/jpeg','image/png'] else array['application/pdf','image/jpeg','image/png'] end)) then raise exception 'Review incompatible private bucket configuration: %',b.id;end if;
 end loop;
end $$;
revoke all on function public.guard_finance_currency(),public.guard_finance_identity() from public,anon,authenticated;
create function public.notify_finance_workflow() returns trigger language plpgsql security definer set search_path='' as $$
declare k text:=case when tg_table_name='expense_claims' then 'expense' else 'financing' end;cap text:=case when tg_table_name='expense_claims' then 'expenses.review' else 'financing.review' end;
begin
 if tg_op='INSERT' then
  insert into public.notifications(employee_id,title,body,kind,entity_id,dedupe_key)
  select p.id,'Financial approval needed','A financial request is waiting for review.',k,new.id,k||':'||new.id||':pending' from public.profiles p where p.is_active and p.id<>new.employee_id and (p.role='super_admin' or (p.role='hr' and exists(select 1 from public.role_permissions r where r.role=p.role and r.permission=cap and r.enabled))) on conflict(employee_id,dedupe_key) do nothing;
 elsif new.status<>old.status then
  insert into public.notifications(employee_id,title,body,kind,entity_id,dedupe_key) values(new.employee_id,'Financial request updated','Your request is now '||new.status||'.',k,new.id,k||':'||new.id||':'||new.status) on conflict(employee_id,dedupe_key) do nothing;
 end if;return new;
end $$;
create trigger notify_finance_workflow after insert or update of status on public.employee_financing for each row execute function public.notify_finance_workflow();
create trigger notify_finance_workflow after insert or update of status on public.expense_claims for each row execute function public.notify_finance_workflow();
revoke all on function public.notify_finance_workflow() from public,anon,authenticated;

commit;
