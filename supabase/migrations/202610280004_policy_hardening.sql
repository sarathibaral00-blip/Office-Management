begin;
-- Authenticated UPDATE checks still run through protect_profile; service updates
-- inside create-employee are trusted only after its caller/role validation.
insert into public.profiles(id,email,full_name)
select id,email,coalesce(raw_user_meta_data->>'full_name','') from auth.users
on conflict(id) do nothing;
create function public.protect_leave_review() returns trigger language plpgsql set search_path='' as $$ begin
 if new.employee_id is distinct from old.employee_id or new.leave_type_id is distinct from old.leave_type_id or new.starts_on is distinct from old.starts_on or new.ends_on is distinct from old.ends_on or new.reason is distinct from old.reason then raise exception 'Submitted leave details are immutable'; end if;
 if old.status<>'pending' or new.status not in ('approved','rejected') then raise exception 'Only pending requests can be reviewed'; end if;
 return new;
end $$;
create trigger protect_leave_review before update on public.leave_requests for each row execute function public.protect_leave_review();
revoke all on function public.protect_leave_review() from public,anon,authenticated;
create policy leave_review on public.leave_requests for update to authenticated using(employee_id<>(select auth.uid()) and (public.is_hr() or (public.current_role()='manager' and public.can_read_employee(employee_id)))) with check(employee_id<>(select auth.uid()) and reviewed_by=(select auth.uid()) and (public.is_hr() or (public.current_role()='manager' and public.can_read_employee(employee_id))));
grant update on public.leave_requests to authenticated;
-- Explicit grants avoid depending on project-specific default privileges.
grant all on public.profiles,public.departments,public.branches,public.allowed_networks,public.attendance,public.shifts,public.holidays,public.leave_types,public.leave_balances,public.leave_requests,public.payroll,public.announcements,public.audit_log to service_role;
grant usage,select on sequence public.audit_log_id_seq to service_role;
commit;
