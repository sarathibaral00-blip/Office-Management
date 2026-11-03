begin;
create function public.employee_today() returns date language sql stable security definer set search_path='' as $$ select (now() at time zone coalesce(b.timezone,'Asia/Dhaka'))::date from public.profiles p left join public.branches b on b.id=p.branch_id where p.id=(select auth.uid()) and p.is_active $$;
revoke all on function public.employee_today() from public,anon;
grant execute on function public.employee_today() to authenticated;
commit;
