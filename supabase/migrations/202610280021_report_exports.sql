begin;
create function public.export_rows(p_kind text,p_start date,p_end date,p_offset integer default 0,p_department uuid default null,p_branch uuid default null) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare wide boolean:=public.has_permission('reports.export_all');team boolean:=public.current_role()='manager' and public.has_permission('reports.export_team');own boolean:=public.has_permission('reports.export_own');result jsonb;page jsonb;
begin
 if public.current_role() is null or not(wide or team or own) then raise exception 'Export access required';end if;
 if p_start is null or p_end is null or p_end<p_start or p_end-p_start>366 or p_offset is null or p_offset<0 then raise exception 'Choose an export period of up to one year';end if;
 if p_kind='attendance' and wide then
  if p_end-p_start>31 then raise exception 'Attendance export pages must be split into months';end if;
  page:=public.attendance_report(p_start,p_end,p_department,p_branch,p_offset);
  return jsonb_build_object('headers',jsonb_build_array('Employee ID','Employee','Work date','Department','Branch','Status','Source','Check in','Check out','Completed hours'),'rows',coalesce((select jsonb_agg(jsonb_build_array(r->>'employee_code',r->>'full_name',r->>'work_date',r->>'department_name',r->>'branch_name',r->>'status',r->>'source',r->>'check_in',r->>'check_out',r->'hours')) from jsonb_array_elements(page->'rows') r),'[]'::jsonb),'has_more',page->'has_more');
 elsif p_kind='attendance' then
  with rows as(select a.*,p.employee_code,p.full_name from public.attendance a join public.profiles p on p.id=a.employee_id where a.work_date between p_start and p_end and ((own and p.id=auth.uid()) or (team and p.manager_id=auth.uid())) and (p_department is null or p.department_id=p_department) and (p_branch is null or a.branch_id=p_branch) order by a.work_date,p.id offset p_offset limit 201)
  select jsonb_build_object('headers',jsonb_build_array('Employee ID','Employee','Work date','Status','Source','Check in','Check out'),'rows',coalesce((select jsonb_agg(jsonb_build_array(r.employee_code,r.full_name,r.work_date,r.status,r.source,r.check_in,r.check_out)) from(select * from rows limit 200) r),'[]'::jsonb),'has_more',(select count(*)>200 from rows)) into result;
 elsif p_kind='leave' then
  with rows as(select l.*,p.employee_code,p.full_name,t.name type_name from public.leave_requests l join public.profiles p on p.id=l.employee_id join public.leave_types t on t.id=l.leave_type_id where l.starts_on<=p_end and l.ends_on>=p_start and (wide or (own and p.id=auth.uid()) or (team and p.manager_id=auth.uid())) and (p_department is null or p.department_id=p_department) and (p_branch is null or p.branch_id=p_branch) order by l.starts_on,p.id,l.id offset p_offset limit 201)
  select jsonb_build_object('headers',jsonb_build_array('Employee ID','Employee','Leave type','Start','End','Units','Half day','Session','Status','Review comment'),'rows',coalesce((select jsonb_agg(jsonb_build_array(r.employee_code,r.full_name,r.type_name,r.starts_on,r.ends_on,r.requested_days,r.is_half_day,r.half_day_period,r.status,r.review_comment)) from(select * from rows limit 200) r),'[]'::jsonb),'has_more',(select count(*)>200 from rows)) into result;
 elsif p_kind='payroll' then
  with rows as(select pay.*,p.employee_code,p.full_name from public.payroll pay join public.profiles p on p.id=pay.employee_id where pay.month between p_start and p_end and ((wide and public.has_permission('payroll.manage')) or (own and p.id=auth.uid() and (pay.locked_at is not null or (pay.run_id is null and pay.status in ('approved','paid'))))) and (p_department is null or p.department_id=p_department) and (p_branch is null or p.branch_id=p_branch) order by pay.month,p.id offset p_offset limit 201)
  select jsonb_build_object('headers',jsonb_build_array('Employee ID','Employee','Month','Basic','Allowances','Deductions','Net','Locked'),'rows',coalesce((select jsonb_agg(jsonb_build_array(r.employee_code,r.full_name,r.month,r.basic,r.allowances,r.deductions,r.net,r.locked_at is not null)) from(select * from rows limit 200) r),'[]'::jsonb),'has_more',(select count(*)>200 from rows)) into result;
 else raise exception 'Unknown report';end if;
 return result;
end $$;
revoke all on function public.export_rows(text,date,date,integer,uuid,uuid) from public,anon;grant execute on function public.export_rows(text,date,date,integer,uuid,uuid) to authenticated;
commit;
