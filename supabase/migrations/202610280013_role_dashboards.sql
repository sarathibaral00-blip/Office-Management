begin;
create function public.role_dashboard() returns jsonb language plpgsql stable security definer set search_path='' as $$
declare who uuid:=auth.uid(); v_role public.app_role:=public.current_role(); result jsonb;
begin
 if v_role is null then raise exception 'Active account required'; end if;
 with scope as (
  select p.id,p.full_name,p.employee_code,p.joined_at,(now() at time zone coalesce(b.timezone,'Asia/Dhaka'))::date today
  from public.profiles p left join public.branches b on b.id=p.branch_id where p.is_active and
   (v_role in ('hr','super_admin') or (v_role='manager' and p.manager_id=who) or (v_role='employee' and p.id=who))
 ), today_attendance as (select a.* from public.attendance a join scope s on s.id=a.employee_id and a.work_date=s.today),
 month_attendance as (select a.* from public.attendance a join scope s on s.id=a.employee_id and a.work_date>=date_trunc('month',s.today)::date and a.work_date<=s.today),
 missed as (
  select s.id,w.day,greatest(0,1-coalesce((select sum(case when r.is_half_day then 0.5 else 1 end) from public.leave_requests r where r.employee_id=s.id and r.status='approved' and w.day between r.starts_on and r.ends_on),0)) units
  from scope s cross join lateral public.leave_workdays(s.id,date_trunc('month',s.today)::date,s.today-1,false) w
  where w.day>=s.joined_at and not exists(select 1 from public.attendance a where a.employee_id=s.id and a.work_date=w.day and a.status in ('present','late'))
 )
 select jsonb_build_object(
 'role',v_role,'headcount',(select count(*) from scope),
 'present_today',(select count(*) from today_attendance where status in ('present','late')),
 'late_today',(select count(*) from today_attendance where status='late'),
 'on_leave',(select count(distinct r.employee_id) from public.leave_requests r join scope s on s.id=r.employee_id where r.status='approved' and s.today between r.starts_on and r.ends_on),
 'pending',(select count(*) from public.leave_requests r join scope s on s.id=r.employee_id where r.status='pending')+case when v_role in ('hr','super_admin','employee') then (select count(*) from public.attendance_correction_requests r join scope s on s.id=r.employee_id where r.status='pending') else 0 end,
 'chart',jsonb_build_array((select count(*) from month_attendance where status='present'),(select count(*) from month_attendance where status='late'),(select coalesce(sum(units),0) from missed)),
 'team',coalesce((select jsonb_agg(jsonb_build_object('id',s.id,'name',s.full_name,'code',s.employee_code,'status',coalesce(a.status::text,'Not checked in'),'source',coalesce(a.source::text,'app'),'check_in',a.check_in,'check_out',a.check_out) order by s.full_name) from scope s left join today_attendance a on a.employee_id=s.id),'[]'::jsonb),
 'balances',coalesce((select jsonb_agg(jsonb_build_object('name',t.name,'remaining',coalesce(b.allocated,t.annual_days)-coalesce(b.used,0),'paid',t.is_paid)) from public.leave_types t left join public.leave_balances b on b.leave_type_id=t.id and b.employee_id=who and b.year=extract(year from public.employee_today())),'[]'::jsonb),
 'unread_notifications',(select count(*) from public.notifications where employee_id=who and read_at is null),
 'unread_notices',(select count(*) from public.announcements a join public.profiles p on p.id=who left join public.announcement_reads r on r.announcement_id=a.id and r.employee_id=who where a.is_active and a.published_at<=now() and (v_role in ('hr','super_admin') or ((a.department_id is null or a.department_id=p.department_id) and (a.branch_id is null or a.branch_id=p.branch_id))) and (r.read_at is null or r.read_at<a.updated_at))
 ) into result;
 return result;
end $$;
revoke all on function public.role_dashboard() from public,anon;
grant execute on function public.role_dashboard() to authenticated;
commit;
