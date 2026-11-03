begin;
create function public.validate_branch_timezone() returns trigger language plpgsql set search_path='' as $$ begin
 if not exists(select 1 from pg_catalog.pg_timezone_names where name=new.timezone) then raise exception 'Choose a valid IANA branch timezone'; end if;
 return new;
end $$;
create trigger validate_branch_timezone before insert or update on public.branches for each row execute function public.validate_branch_timezone();
revoke all on function public.validate_branch_timezone() from public,anon,authenticated;
commit;
