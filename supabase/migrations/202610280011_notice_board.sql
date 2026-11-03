begin;
alter table public.announcements add column department_id uuid references public.departments(id),
 add column is_active boolean not null default true,add column updated_at timestamptz not null default now();
create index announcements_department_idx on public.announcements(department_id,published_at);
create table public.announcement_reads(
 employee_id uuid not null references public.profiles(id),announcement_id uuid not null references public.announcements(id),
 read_at timestamptz not null default now(),primary key(employee_id,announcement_id)
);
create index announcement_reads_notice_idx on public.announcement_reads(announcement_id);
alter table public.announcement_reads enable row level security;
revoke all on public.announcement_reads from public,anon,authenticated;
grant select on public.announcement_reads to authenticated;
grant all on public.announcement_reads to service_role;
create policy read_own_receipts on public.announcement_reads for select to authenticated using(employee_id=(select auth.uid()) and (select public.current_role()) is not null);
alter policy read_active on public.announcements using(public.current_role() is not null and is_active and published_at<=now() and
 (department_id is null or department_id=(select department_id from public.profiles where id=(select auth.uid()))) and
 (branch_id is null or branch_id=(select branch_id from public.profiles where id=(select auth.uid()))));
revoke delete on public.announcements from authenticated;
create function public.save_announcement(p_id uuid,p_title text,p_body text,p_department uuid,p_active boolean default true) returns uuid
language plpgsql security definer set search_path='' as $$ declare result uuid; begin
 if not public.is_hr() then raise exception 'HR access required'; end if;
 if length(trim(coalesce(p_title,'')))<3 or length(trim(coalesce(p_body,'')))<3 then raise exception 'A title and message are required'; end if;
 perform set_config('app.audit_reason',case when p_active then 'HR published notice' else 'HR archived notice' end,true);
 if p_id is null then insert into public.announcements(title,body,department_id,published_by,is_active) values(trim(p_title),trim(p_body),p_department,auth.uid(),p_active) returning id into result;
 else update public.announcements set title=trim(p_title),body=trim(p_body),department_id=p_department,is_active=p_active,updated_at=now() where id=p_id returning id into result;end if;
 if result is null then raise exception 'Notice not found'; end if;return result;
end $$;
create function public.mark_announcement_read(p_id uuid) returns void language plpgsql security definer set search_path='' as $$ begin
 if public.current_role() is null or not exists(select 1 from public.announcements a join public.profiles p on p.id=auth.uid() where a.id=p_id and a.is_active and a.published_at<=now() and (public.is_hr() or ((a.department_id is null or a.department_id=p.department_id) and (a.branch_id is null or a.branch_id=p.branch_id)))) then raise exception 'Notice not available'; end if;
 insert into public.announcement_reads(employee_id,announcement_id) values(auth.uid(),p_id) on conflict(employee_id,announcement_id) do update set read_at=now();
end $$;
revoke all on function public.save_announcement(uuid,text,text,uuid,boolean),public.mark_announcement_read(uuid) from public,anon;
grant execute on function public.save_announcement(uuid,text,text,uuid,boolean),public.mark_announcement_read(uuid) to authenticated;
commit;
