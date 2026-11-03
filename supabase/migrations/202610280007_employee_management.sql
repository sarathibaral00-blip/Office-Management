begin;
create index profiles_employee_search_idx on public.profiles(lower(full_name));
create index profiles_active_role_idx on public.profiles(is_active,role,id);
create function public.update_employee(p_employee uuid,p_data jsonb) returns void
language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid(); old_row public.profiles; next_role public.app_role; next_salary numeric; next_active boolean;
begin
 if not public.is_hr() then raise exception 'HR access required'; end if;
 select * into old_row from public.profiles where id=p_employee for update;
 if not found then raise exception 'Employee not found'; end if;
 next_role:=coalesce((p_data->>'role')::public.app_role,old_row.role);
 next_salary:=coalesce((p_data->>'salary')::numeric,old_row.salary);
 next_active:=coalesce((p_data->>'is_active')::boolean,old_row.is_active);
 if next_salary<0 or next_salary::text in ('NaN','Infinity','-Infinity') then raise exception 'Enter a finite, non-negative salary'; end if;
 if actor=p_employee and (next_role<>old_row.role or next_salary<>old_row.salary or next_active<>old_row.is_active) then raise exception 'You cannot change your own role, salary or active status'; end if;
 if public.current_role()<>'super_admin' and (old_row.role='super_admin' or next_role='super_admin') then raise exception 'Only super admin can manage a super admin'; end if;
 if length(trim(coalesce(p_data->>'full_name',old_row.full_name)))=0 then raise exception 'Employee name is required'; end if;
 perform set_config('app.audit_actor',actor::text,true);
 perform set_config('app.audit_reason',case when next_active<>old_row.is_active then 'HR changed employee active status' else 'HR updated employee assignments' end,true);
 update public.profiles set full_name=coalesce(p_data->>'full_name',full_name),role=next_role,salary=next_salary,is_active=next_active,
 department_id=case when p_data ? 'department_id' then (p_data->>'department_id')::uuid else department_id end,
 branch_id=case when p_data ? 'branch_id' then (p_data->>'branch_id')::uuid else branch_id end,
 manager_id=case when p_data ? 'manager_id' then (p_data->>'manager_id')::uuid else manager_id end,
 shift_id=case when p_data ? 'shift_id' then (p_data->>'shift_id')::uuid else shift_id end,
 designation=case when p_data ? 'designation' then p_data->>'designation' else designation end where id=p_employee;
end $$;
create function public.validate_employee_manager() returns trigger language plpgsql set search_path='' as $$ begin
 if new.manager_id is not null and (tg_op='INSERT' or new.manager_id is distinct from old.manager_id) then
  if not exists(select 1 from public.profiles where id=new.manager_id and is_active and role in ('manager','hr','super_admin')) then raise exception 'Choose an active manager'; end if;
  if exists(with recursive chain as (select id,manager_id,array[id] path from public.profiles where id=new.manager_id union all select p.id,p.manager_id,c.path||p.id from public.profiles p join chain c on p.id=c.manager_id where not p.id=any(c.path)) select 1 from chain where id=new.id) then raise exception 'Manager assignment creates a cycle'; end if;
 end if; return new;
end $$;
create trigger validate_employee_manager before insert or update of manager_id on public.profiles for each row execute function public.validate_employee_manager();
revoke all on function public.validate_employee_manager() from public,anon,authenticated;
revoke all on function public.update_employee(uuid,jsonb) from public,anon;
grant execute on function public.update_employee(uuid,jsonb) to authenticated;
commit;
