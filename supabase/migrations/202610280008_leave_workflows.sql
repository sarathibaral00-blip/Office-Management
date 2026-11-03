begin;
alter table public.leave_requests add column is_half_day boolean not null default false,
 add column half_day_period text check(half_day_period in ('am','pm')),
 add column requested_days numeric(6,1), add column review_comment text;
create index leave_requests_period_idx on public.leave_requests(starts_on,ends_on,status);
create function public.leave_workdays(p_employee uuid,p_start date,p_end date,p_half boolean) returns table(day date,units numeric)
language sql stable security definer set search_path='' as $$
 select d::date,case when p_half then 0.5 else 1.0 end
 from public.profiles p left join public.shifts assigned on assigned.id=p.shift_id
 left join public.shifts fallback on fallback.is_default,
 pg_catalog.generate_series(p_start::timestamp,p_end::timestamp,interval '1 day') d
 where p.id=p_employee and extract(dow from d)::integer=any(coalesce(assigned.work_days,fallback.work_days,array[0,1,2,3,4]))
 and not exists(select 1 from public.holidays h where h.holiday_date=d::date and (h.branch_id is null or h.branch_id=p.branch_id))
$$;
create function public.ensure_leave_balances(p_year integer) returns void language plpgsql security definer set search_path='' as $$ begin
 if public.current_role() is null or p_year not between 2000 and 2200 then raise exception 'Invalid balance year or inactive account'; end if;
 insert into public.leave_balances(employee_id,leave_type_id,year,allocated)
 select auth.uid(),id,p_year,annual_days from public.leave_types on conflict(employee_id,leave_type_id,year) do nothing;
end $$;
create function public.apply_leave(p_type uuid,p_start date,p_end date,p_half boolean,p_period text,p_reason text) returns uuid
language plpgsql security definer set search_path='' as $$
declare who uuid:=auth.uid(); units numeric; result uuid;
begin
 if public.current_role() is null then raise exception 'Active employee required'; end if;
 perform 1 from public.profiles where id=who for update;
 if p_start is null or p_end is null or p_end<p_start or p_end-p_start>366 or p_start<public.employee_today() then raise exception 'Choose future leave dates within a year'; end if;
 if length(trim(coalesce(p_reason,'')))<3 then raise exception 'A leave reason is required'; end if;
 if p_half is null or (p_half and (p_start<>p_end or p_period not in ('am','pm') or p_period is null)) then raise exception 'Half day requires one date and AM or PM'; end if;
 if not exists(select 1 from public.leave_types where id=p_type) then raise exception 'Leave type not found'; end if;
 if exists(select 1 from public.leave_requests r where employee_id=who and status in ('pending','approved') and starts_on<=p_end and ends_on>=p_start and not(p_half and r.is_half_day and r.starts_on=p_start and r.half_day_period<>p_period)) then raise exception 'Leave dates overlap an existing request'; end if;
 select sum(w.units) into units from public.leave_workdays(who,p_start,p_end,p_half) w;
 if coalesce(units,0)=0 then raise exception 'Choose at least one scheduled workday'; end if;
 insert into public.leave_requests(employee_id,leave_type_id,starts_on,ends_on,reason,is_half_day,half_day_period,requested_days)
 values(who,p_type,p_start,p_end,trim(p_reason),p_half,case when p_half then p_period else null end,units) returning id into result;
 return result;
end $$;
create or replace function public.protect_leave_review() returns trigger language plpgsql set search_path='' as $$ begin
 if new.employee_id is distinct from old.employee_id or new.leave_type_id is distinct from old.leave_type_id or new.starts_on is distinct from old.starts_on or new.ends_on is distinct from old.ends_on or new.reason is distinct from old.reason or new.is_half_day is distinct from old.is_half_day or new.half_day_period is distinct from old.half_day_period or new.requested_days is distinct from old.requested_days then raise exception 'Submitted leave details are immutable'; end if;
 if old.status<>'pending' then raise exception 'Only pending requests can change'; end if;
 if new.status='cancelled' then
  if auth.uid() is distinct from old.employee_id then raise exception 'Only the applicant can cancel pending leave'; end if;
 elsif new.status in ('approved','rejected') then
  if auth.uid()=old.employee_id or not(public.is_hr() or (public.current_role()='manager' and public.can_read_employee(old.employee_id))) then raise exception 'Review access denied'; end if;
  if new.reviewed_by is distinct from auth.uid() or length(trim(coalesce(new.review_comment,'')))<3 then raise exception 'A reviewer and comment are required'; end if;
 else raise exception 'Invalid leave transition'; end if;
 return new;
end $$;
create function public.deduct_approved_leave() returns trigger language plpgsql security definer set search_path='' as $$
declare allocation record; paid boolean; annual numeric; total numeric;
begin
 if new.status='approved' and old.status='pending' then
  select is_paid,annual_days into paid,annual from public.leave_types where id=new.leave_type_id;
  select sum(units) into total from public.leave_workdays(new.employee_id,new.starts_on,new.ends_on,new.is_half_day);
  if total is null or total is distinct from coalesce(new.requested_days,total) then raise exception 'Work calendar changed; cancel and resubmit this request'; end if;
  if paid then
   for allocation in select extract(year from w.day)::integer as balance_year,sum(w.units) as amount from public.leave_workdays(new.employee_id,new.starts_on,new.ends_on,new.is_half_day) w group by 1 order by 1 loop
    insert into public.leave_balances(employee_id,leave_type_id,year,allocated) values(new.employee_id,new.leave_type_id,allocation.balance_year,annual) on conflict(employee_id,leave_type_id,year) do nothing;
    update public.leave_balances set used=used+allocation.amount where employee_id=new.employee_id and leave_type_id=new.leave_type_id and year=allocation.balance_year and used+allocation.amount<=allocated;
    if not found then raise exception 'Insufficient leave balance'; end if;
   end loop;
  end if;
 end if; return new;
end $$;
create trigger deduct_approved_leave after update of status on public.leave_requests for each row execute function public.deduct_approved_leave();
create function public.review_leave(p_id uuid,p_approve boolean,p_comment text) returns void language plpgsql security definer set search_path='' as $$
declare target uuid; begin
 select employee_id into target from public.leave_requests where id=p_id;
 if p_approve is null then raise exception 'Choose approve or reject'; end if;
 if target is null or auth.uid()=target or not(public.is_hr() or (public.current_role()='manager' and public.can_read_employee(target))) then raise exception 'Review access denied'; end if;
 perform 1 from public.profiles where id=target for update;
 update public.leave_requests set status=case when p_approve then 'approved'::public.leave_status else 'rejected'::public.leave_status end,reviewed_by=auth.uid(),review_comment=trim(p_comment) where id=p_id and status='pending';
 if not found then raise exception 'Request is no longer pending'; end if;
end $$;
create function public.cancel_leave(p_id uuid) returns void language plpgsql security definer set search_path='' as $$ begin
 if public.current_role() is null then raise exception 'Active account required'; end if;
 perform 1 from public.profiles where id=auth.uid() for update;
 update public.leave_requests set status='cancelled' where id=p_id and employee_id=auth.uid() and status='pending';
 if not found then raise exception 'Only your pending requests can be cancelled'; end if;
end $$;
-- Approval/cancellation must use transactional functions, including for HR.
revoke insert,update,delete on public.leave_requests from authenticated;
revoke all on function public.leave_workdays(uuid,date,date,boolean),public.deduct_approved_leave() from public,anon,authenticated;
revoke all on function public.ensure_leave_balances(integer),public.apply_leave(uuid,date,date,boolean,text,text),public.review_leave(uuid,boolean,text),public.cancel_leave(uuid) from public,anon;
grant execute on function public.ensure_leave_balances(integer),public.apply_leave(uuid,date,date,boolean,text,text),public.review_leave(uuid,boolean,text),public.cancel_leave(uuid) to authenticated;
commit;
