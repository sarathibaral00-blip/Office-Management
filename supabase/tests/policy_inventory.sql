-- Read-only remote inventory. Compare with docs/policy-inventory.md before rollout.
select schemaname,tablename,rowsecurity from pg_tables where schemaname in ('public','attendance_private') order by 1,2;
select schemaname,tablename,policyname,roles,cmd,qual,with_check from pg_policies where schemaname in ('public','attendance_private','storage') order by 1,2,3;
select n.nspname,p.proname,p.prosecdef,p.proconfig,p.proacl from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname in ('public','attendance_private') order by 1,2;
select id,public,file_size_limit,allowed_mime_types from storage.buckets order by id;
select table_schema,table_name,grantee,privilege_type from information_schema.role_table_grants where grantee in ('anon','authenticated') and table_schema in ('public','attendance_private','storage') order by 1,2,3,4;
