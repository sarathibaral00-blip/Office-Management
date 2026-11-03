begin;
-- DEV ONLY: assignments for the four explicitly requested test identities.
-- No Auth identities, roles, passwords, network rules or attendance are created
-- or changed. Resolve by auth.users.email, not editable profile email fields.
do $$
declare
 office public.branches;
 default_department uuid;
 default_shift uuid;
 affected integer;
begin
 -- Prefer an office that can actually accept attendance. If several offices
 -- have allowed IPs, select the earliest-created branch deterministically.
 select b.* into office from public.branches b
 where exists(select 1 from public.allowed_networks n where n.branch_id=b.id and n.is_active)
 order by b.created_at,b.id limit 1;
 if office.id is null then
  raise exception 'Create a branch and save its active office IP in Office networks, then retry this migration';
 end if;
 if not exists(select 1 from pg_catalog.pg_timezone_names where name=office.timezone) then
  raise exception 'The selected office branch has an invalid timezone. Correct it before retrying';
 end if;
 select id into default_department from public.departments order by created_at,id limit 1;
 select id into default_shift from public.shifts where is_default order by id limit 1;
 perform set_config('app.audit_reason','DEV ONLY: assign four test accounts to an office branch for attendance testing',true);
 update public.profiles p
 set branch_id=office.id,
     department_id=coalesce(p.department_id,default_department),
     shift_id=coalesce(p.shift_id,default_shift)
 from auth.users u
 where u.id=p.id and lower(u.email) in ('admin@test.com','hr@test.com','manager@test.com','employee@test.com')
 and (p.branch_id is distinct from office.id
      or p.department_id is distinct from coalesce(p.department_id,default_department)
      or p.shift_id is distinct from coalesce(p.shift_id,default_shift));
 get diagnostics affected=row_count;
 raise notice 'DEV test account assignments updated: %',affected;
 -- Missing test identities are intentionally not provisioned by a migration.
 -- The separately authorized manual seed script can create them later.
end $$;
commit;
