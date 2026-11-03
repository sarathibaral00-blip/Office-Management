begin;
create function public.attendance_report(p_start date,p_end date,p_department uuid default null,p_branch uuid default null,p_offset integer default 0) returns jsonb
language plpgsql stable security definer set search_path='' as $$ declare result jsonb; begin
 if not public.is_hr() then raise exception 'HR access required'; end if;
 if p_start is null or p_end is null or p_end<p_start or p_end-p_start>31 or p_offset<0 then raise exception 'Choose a daily or monthly period'; end if;
 with grid as (
 select p.id employee_id,p.full_name,p.employee_code,d.name department_name,b.name branch_name,
 day::date work_date,(now() at time zone coalesce(b.timezone,'Asia/Dhaka'))::date branch_today,a.id attendance_id,a.check_in,a.check_out,coalesce(a.source::text,'app') source,
 case when a.id is not null then a.status::text
 when day::date>(now() at time zone coalesce(b.timezone,'Asia/Dhaka'))::date then 'upcoming'
 when exists(select 1 from public.holidays h where h.is_active and h.holiday_date=day::date and (h.branch_id is null or h.branch_id=p.branch_id)) then 'holiday'
 when not extract(dow from day)::integer=any(coalesce(s.work_days,f.work_days,array[0,1,2,3,4])) then 'off'
 when coalesce(l.units,0)>=1 then 'on_leave'
 when coalesce(l.units,0)>0 then 'half_leave'
 when day::date=(now() at time zone coalesce(b.timezone,'Asia/Dhaka'))::date then 'not_checked_in'
 else 'absent' end status,
 case when a.check_out is not null then extract(epoch from a.check_out-a.check_in)/3600 else 0 end hours
 from public.profiles p cross join pg_catalog.generate_series(p_start::timestamp,p_end::timestamp,interval '1 day') day
 left join public.attendance a on a.employee_id=p.id and a.work_date=day::date
 left join lateral (select sum(case when r.is_half_day then 0.5 else 1 end) units from public.leave_requests r where r.employee_id=p.id and r.status='approved' and day::date between r.starts_on and r.ends_on) l on true
 left join public.departments d on d.id=p.department_id left join public.branches b on b.id=coalesce(a.branch_id,p.branch_id)
 left join public.shifts s on s.id=p.shift_id left join public.shifts f on f.is_default
 where (p_department is null or p.department_id=p_department) and (p_branch is null or coalesce(a.branch_id,p.branch_id)=p_branch)
 and day::date>=p.joined_at and (p.is_active or a.id is not null)
 ), page as (select * from grid order by work_date desc,full_name,employee_id offset p_offset limit 51)
 select jsonb_build_object('rows',coalesce((select jsonb_agg(to_jsonb(r)) from (select * from page limit 50) r),'[]'::jsonb),
 'has_more',(select count(*)>50 from page),'total',(select count(*) from grid),
 'present',(select count(*) from grid where status='present'),'late',(select count(*) from grid where status='late'),
 'absent',(select coalesce(sum(case when status='absent' then 1 when status='half_leave' and work_date<branch_today then 0.5 else 0 end),0) from grid),'hours',(select coalesce(sum(hours),0) from grid)) into result;
 return result;
end $$;
revoke all on function public.attendance_report(date,date,uuid,uuid,integer) from public,anon;
grant execute on function public.attendance_report(date,date,uuid,uuid,integer) to authenticated;
commit;
