begin;
create table public.employee_financing(
 id uuid primary key default gen_random_uuid(),employee_id uuid not null references public.profiles(id),kind text not null check(kind in ('advance','loan')),amount numeric(14,2) not null check(amount>0 and amount<1000000000000),installments integer not null check(installments between 1 and 120),installment_amount numeric(14,2) not null check(installment_amount>0),starts_month date not null check(extract(day from starts_month)=1),reason text not null,status text not null default 'pending' check(status in ('pending','approved','active','settled','rejected','withdrawn')),reviewed_by uuid references public.profiles(id),review_comment text,disbursed_by uuid references public.profiles(id),payment_reference text,disbursed_at timestamptz,created_at timestamptz not null default now()
);
create table public.payroll_installments(
 id uuid primary key default gen_random_uuid(),financing_id uuid not null references public.employee_financing(id),employee_id uuid not null references public.profiles(id),payroll_id uuid not null references public.payroll(id) deferrable initially deferred,amount numeric(14,2) not null check(amount>0),posted_at timestamptz,unique(financing_id,payroll_id)
);
create index financing_employee_idx on public.employee_financing(employee_id,status,starts_month);create index financing_reviewer_idx on public.employee_financing(reviewed_by);create index financing_disburser_idx on public.employee_financing(disbursed_by);create index installments_employee_idx on public.payroll_installments(employee_id);create index installments_payroll_idx on public.payroll_installments(payroll_id);
do $$ declare t text;begin foreach t in array array['employee_financing','payroll_installments'] loop execute format('alter table public.%I enable row level security',t);execute format('revoke all on public.%I from public,anon,authenticated',t);execute format('grant select on public.%I to authenticated',t);execute format('grant all on public.%I to service_role',t);execute format('create trigger audit_change after insert or update on public.%I for each row execute function public.audit_change()',t);end loop;end $$;
create policy financing_private on public.employee_financing for select to authenticated using((select public.current_role()) is not null and (employee_id=(select auth.uid()) or (select public.has_permission('financing.review'))));
create policy installment_private on public.payroll_installments for select to authenticated using((select public.has_permission('financing.review')) or (employee_id=(select auth.uid()) and posted_at is not null and (select public.current_role()) is not null));
create function public.request_financing(p_kind text,p_amount numeric,p_installments integer,p_month date,p_reason text) returns uuid language plpgsql security definer set search_path='' as $$ declare result uuid;begin
 if public.current_role() is null then raise exception 'Active account required';end if;
 if p_kind not in ('advance','loan') or p_amount is null or p_amount<=0 or p_amount>=1000000000000 or p_amount::text in ('NaN','Infinity','-Infinity') or p_installments is null or p_installments not between 1 and 120 or p_month is null or extract(day from p_month)<>1 or length(trim(coalesce(p_reason,'')))<3 then raise exception 'Valid financing terms and a reason are required';end if;
 insert into public.employee_financing(employee_id,kind,amount,installments,installment_amount,starts_month,reason) values(auth.uid(),p_kind,p_amount,p_installments,ceil(p_amount/p_installments*100)/100,p_month,trim(p_reason)) returning id into result;return result;
end $$;
create function public.review_financing(p_id uuid,p_action text,p_comment text) returns void language plpgsql security definer set search_path='' as $$ declare f public.employee_financing;begin
 select * into f from public.employee_financing where id=p_id for update;if f.id is null then raise exception 'Request not found';end if;
 if p_action='withdraw' and f.employee_id=auth.uid() and public.current_role() is not null and f.status='pending' then update public.employee_financing set status='withdrawn' where id=f.id;return;end if;
 if not public.has_permission('financing.review') or f.employee_id=auth.uid() then raise exception 'Another HR reviewer is required';end if;
 if length(trim(coalesce(p_comment,'')))<3 then raise exception 'Review comment or payment reference is required';end if;
 perform set_config('app.audit_reason',p_comment,true);
 if f.status='pending' and p_action in ('approve','reject') then update public.employee_financing set status=case when p_action='approve' then 'approved' else 'rejected' end,reviewed_by=auth.uid(),review_comment=trim(p_comment) where id=f.id;
 elsif f.status='approved' and p_action='disburse' then
 if f.starts_month<date_trunc('month',now())::date then raise exception 'Repayment cannot start before the disbursement month';end if;
 update public.employee_financing set status='active',disbursed_by=auth.uid(),disbursed_at=now(),payment_reference=trim(p_comment) where id=f.id;
 else raise exception 'Invalid financing transition';end if;
end $$;
create function public.reserve_payroll_installments() returns trigger language plpgsql security definer set search_path='' as $$
declare f public.employee_financing;remaining numeric;room numeric;deduction numeric;total numeric:=0;begin
 if new.run_id is null then return new;end if;
 if exists(select 1 from public.payroll_runs where month<new.month and status<>'locked') then raise exception 'Lock earlier payroll runs before generating a later month';end if;
 room:=greatest(0,new.basic+new.allowances-new.deductions);
 for f in select * from public.employee_financing where employee_id=new.employee_id and status='active' and starts_month<=new.month order by starts_month,id for update loop
  select f.amount-coalesce(sum(amount),0) into remaining from public.payroll_installments where financing_id=f.id;
  deduction:=least(f.installment_amount,remaining,room);
  if deduction>0 then insert into public.payroll_installments(financing_id,employee_id,payroll_id,amount) values(f.id,new.employee_id,new.id,deduction);total:=total+deduction;room:=room-deduction;end if;
 end loop;
 new.installment_deduction:=total;new.deductions:=new.deductions+total;return new;
end $$;
create trigger reserve_payroll_installments before insert on public.payroll for each row execute function public.reserve_payroll_installments();
create function public.post_payroll_installments() returns trigger language plpgsql security definer set search_path='' as $$ begin
 if new.status='locked' and old.status='approved' then
  update public.payroll_installments i set posted_at=now() from public.payroll p where p.id=i.payroll_id and p.run_id=new.id and i.posted_at is null;
  update public.employee_financing f set status='settled' where f.status='active' and f.amount<=(select coalesce(sum(i.amount),0) from public.payroll_installments i where i.financing_id=f.id and i.posted_at is not null);
 end if;return new;
end $$;
create trigger post_payroll_installments after update of status on public.payroll_runs for each row execute function public.post_payroll_installments();
create function public.guard_installment() returns trigger language plpgsql set search_path='' as $$ begin
 if tg_op='DELETE' or old.posted_at is not null or new.amount is distinct from old.amount or new.financing_id is distinct from old.financing_id or new.employee_id is distinct from old.employee_id or new.payroll_id is distinct from old.payroll_id then raise exception 'Installment accounting is immutable';end if;return new;
end $$;
create trigger guard_installment before update or delete on public.payroll_installments for each row execute function public.guard_installment();
revoke all on function public.reserve_payroll_installments(),public.post_payroll_installments(),public.guard_installment() from public,anon,authenticated;
revoke all on function public.request_financing(text,numeric,integer,date,text),public.review_financing(uuid,text,text) from public,anon;
grant execute on function public.request_financing(text,numeric,integer,date,text),public.review_financing(uuid,text,text) to authenticated;
commit;
