begin;
create table public.expense_claims(id uuid primary key default gen_random_uuid(),employee_id uuid not null references public.profiles(id),title text not null,category text not null,amount numeric(14,2) not null check(amount>0 and amount<1000000000000),spent_on date not null,receipt_path text not null unique,status text not null default 'pending' check(status in ('pending','approved','rejected','reimbursed','withdrawn')),reviewed_by uuid references public.profiles(id),review_comment text,reimbursed_by uuid references public.profiles(id),reimbursed_at timestamptz,payment_reference text,created_at timestamptz not null default now());
create index expenses_employee_idx on public.expense_claims(employee_id,created_at);create index expenses_reviewer_idx on public.expense_claims(reviewed_by);create index expenses_reimburser_idx on public.expense_claims(reimbursed_by);
alter table public.expense_claims enable row level security;revoke all on public.expense_claims from public,anon,authenticated;grant select on public.expense_claims to authenticated;grant all on public.expense_claims to service_role;
create policy expense_private on public.expense_claims for select to authenticated using((select public.current_role()) is not null and (employee_id=(select auth.uid()) or (select public.has_permission('expenses.review'))));
create trigger audit_change after insert or update on public.expense_claims for each row execute function public.audit_change();
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('expense-receipts','expense-receipts',false,10485760,array['application/pdf','image/png','image/jpeg']) on conflict(id) do nothing;
do $$ begin if exists(select 1 from storage.buckets where id='expense-receipts' and public) then raise exception 'Receipt bucket must be private';end if;end $$;
create policy receipts_private_read on storage.objects for select to authenticated using(bucket_id='expense-receipts' and (select public.current_role()) is not null and ((storage.foldername(name))[1]=(select auth.uid())::text or (select public.has_permission('expenses.review'))));
create policy receipts_own_upload on storage.objects for insert to authenticated with check(bucket_id='expense-receipts' and (storage.foldername(name))[1]=(select auth.uid())::text and (select public.current_role()) is not null);
create function public.submit_expense(p_title text,p_category text,p_amount numeric,p_day date,p_receipt text) returns uuid language plpgsql security definer set search_path='' as $$ declare result uuid;begin
 if public.current_role() is null then raise exception 'Active account required';end if;
 if p_amount is null or p_amount<=0 or p_amount>=1000000000000 or p_amount::text in ('NaN','Infinity','-Infinity') or p_day is null or p_day>public.employee_today() or length(trim(coalesce(p_title,'')))<3 or length(trim(coalesce(p_category,'')))<2 then raise exception 'Enter a title, category, valid amount and expense date';end if;
 if split_part(coalesce(p_receipt,''),'/',1)<>auth.uid()::text or not exists(select 1 from storage.objects where bucket_id='expense-receipts' and name=p_receipt) then raise exception 'Upload your own receipt first';end if;
 insert into public.expense_claims(employee_id,title,category,amount,spent_on,receipt_path) values(auth.uid(),trim(p_title),trim(p_category),p_amount,p_day,p_receipt) returning id into result;return result;
end $$;
create function public.review_expense(p_id uuid,p_action text,p_comment text) returns void language plpgsql security definer set search_path='' as $$ declare e public.expense_claims;begin
 select * into e from public.expense_claims where id=p_id for update;if e.id is null then raise exception 'Claim not found';end if;
 if p_action='withdraw' and e.status='pending' and e.employee_id=auth.uid() and public.current_role() is not null then update public.expense_claims set status='withdrawn' where id=e.id;return;end if;
 if not public.has_permission('expenses.review') or e.employee_id=auth.uid() then raise exception 'Another HR reviewer is required';end if;
 if length(trim(coalesce(p_comment,'')))<3 then raise exception 'A review comment or payment reference is required';end if;
 perform set_config('app.audit_reason',p_comment,true);
 if e.status='pending' and p_action in ('approve','reject') then update public.expense_claims set status=case when p_action='approve' then 'approved' else 'rejected' end,reviewed_by=auth.uid(),review_comment=trim(p_comment) where id=e.id;
 elsif e.status='approved' and p_action='reimburse' then update public.expense_claims set status='reimbursed',reimbursed_by=auth.uid(),reimbursed_at=now(),payment_reference=trim(p_comment) where id=e.id;
 else raise exception 'Invalid claim transition';end if;
end $$;
revoke all on function public.submit_expense(text,text,numeric,date,text),public.review_expense(uuid,text,text) from public,anon;grant execute on function public.submit_expense(text,text,numeric,date,text),public.review_expense(uuid,text,text) to authenticated;
commit;
