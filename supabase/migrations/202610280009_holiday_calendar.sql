begin;
alter table public.holidays add column is_active boolean not null default true;
revoke delete on public.holidays from authenticated;
create function public.save_holiday(p_id uuid,p_name text,p_date date,p_branch uuid,p_active boolean default true) returns uuid
language plpgsql security definer set search_path='' as $$ declare result uuid; begin
 if not public.is_hr() then raise exception 'HR access required'; end if;
 if length(trim(coalesce(p_name,'')))<2 or p_date is null then raise exception 'Holiday name and date are required'; end if;
 perform set_config('app.audit_reason',case when p_active then 'HR saved holiday' else 'HR archived holiday' end,true);
 if p_id is null then insert into public.holidays(name,holiday_date,branch_id,is_active) values(trim(p_name),p_date,p_branch,p_active) returning id into result;
 else update public.holidays set name=trim(p_name),holiday_date=p_date,branch_id=p_branch,is_active=p_active where id=p_id returning id into result; end if;
 if result is null then raise exception 'Holiday not found'; end if;return result;
end $$;
create or replace function public.leave_workdays(p_employee uuid,p_start date,p_end date,p_half boolean) returns table(day date,units numeric)
language sql stable security definer set search_path='' as $$
 select d::date,case when p_half then 0.5 else 1.0 end from public.profiles p
 left join public.shifts assigned on assigned.id=p.shift_id left join public.shifts fallback on fallback.is_default,
 pg_catalog.generate_series(p_start::timestamp,p_end::timestamp,interval '1 day') d
 where p.id=p_employee and extract(dow from d)::integer=any(coalesce(assigned.work_days,fallback.work_days,array[0,1,2,3,4]))
 and not exists(select 1 from public.holidays h where h.is_active and h.holiday_date=d::date and (h.branch_id is null or h.branch_id=p.branch_id))
$$;
revoke all on function public.save_holiday(uuid,text,date,uuid,boolean) from public,anon;
grant execute on function public.save_holiday(uuid,text,date,uuid,boolean) to authenticated;
commit;
