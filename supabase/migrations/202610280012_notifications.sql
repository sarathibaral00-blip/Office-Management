begin;
create table public.notifications(
 id uuid primary key default gen_random_uuid(),employee_id uuid not null references public.profiles(id),
 title text not null,body text not null,kind text not null,entity_id uuid,dedupe_key text not null,
 created_at timestamptz not null default now(),read_at timestamptz,unique(employee_id,dedupe_key)
);
create index notifications_inbox_idx on public.notifications(employee_id,created_at desc,id);
alter table public.notifications enable row level security;
revoke all on public.notifications from public,anon,authenticated;
grant select on public.notifications to authenticated;grant all on public.notifications to service_role;
create policy own_notifications on public.notifications for select to authenticated using(employee_id=(select auth.uid()) and (select public.current_role()) is not null);
create function public.read_notifications(p_id uuid default null) returns void language plpgsql security definer set search_path='' as $$ begin
 if public.current_role() is null then raise exception 'Active account required'; end if;
 update public.notifications set read_at=now() where employee_id=auth.uid() and (p_id is null or id=p_id) and read_at is null;
end $$;
create function public.notify_workflow() returns trigger language plpgsql security definer set search_path='' as $$
declare recipient record; kind text; title text; target uuid; begin
 if tg_table_name='announcements' then
  if not new.is_active then return new; end if;
  insert into public.notifications(employee_id,title,body,kind,entity_id,dedupe_key)
  select id,'New company update','An announcement is available on your notice board.','notice',new.id,'notice:'||new.id||':'||new.updated_at
  from public.profiles where is_active and (new.department_id is null or department_id=new.department_id) and (new.branch_id is null or branch_id=new.branch_id)
  on conflict(employee_id,dedupe_key) do nothing;
  return new;
 end if;
 kind:=case when tg_table_name='leave_requests' then 'leave' else 'correction' end;
 if tg_op='INSERT' then
  for recipient in select id from public.profiles where is_active and id<>new.employee_id and
   (role in ('hr','super_admin') or (kind='leave' and role='manager' and id=(select manager_id from public.profiles where id=new.employee_id))) loop
   insert into public.notifications(employee_id,title,body,kind,entity_id,dedupe_key) values(recipient.id,'Approval needed','A '||kind||' request is waiting for review.',kind,new.id,kind||':'||new.id||':pending') on conflict(employee_id,dedupe_key) do nothing;
  end loop;
 elsif new.status::text<>old.status::text then
  insert into public.notifications(employee_id,title,body,kind,entity_id,dedupe_key) values(new.employee_id,'Request '||new.status,'Your '||kind||' request has been '||new.status||'.',kind,new.id,kind||':'||new.id||':'||new.status) on conflict(employee_id,dedupe_key) do nothing;
 end if;return new;
end $$;
create trigger notify_workflow after insert or update of status on public.leave_requests for each row execute function public.notify_workflow();
create trigger notify_workflow after insert or update of status on public.attendance_correction_requests for each row execute function public.notify_workflow();
create trigger notify_workflow after insert or update on public.announcements for each row execute function public.notify_workflow();
create function public.queue_missed_checkout_reminders() returns integer language plpgsql security definer set search_path='' as $$ declare affected integer; begin
 insert into public.notifications(employee_id,title,body,kind,entity_id,dedupe_key)
 select a.employee_id,'Did you check out?','Your workday is still open. Check out or request a correction if needed.','missed_checkout',a.id,'checkout:'||a.id
 from public.attendance a join public.profiles p on p.id=a.employee_id and p.is_active
 join public.branches b on b.id=a.branch_id left join public.shifts assigned on assigned.id=p.shift_id left join public.shifts fallback on fallback.is_default
 where a.check_out is null and now()>
 (((a.work_date+case when coalesce(assigned.ends_at,fallback.ends_at)<=coalesce(assigned.starts_at,fallback.starts_at) then 1 else 0 end)+coalesce(assigned.ends_at,fallback.ends_at)) at time zone b.timezone)+interval '30 minutes'
 on conflict(employee_id,dedupe_key) do nothing;
 get diagnostics affected=row_count;return affected;
end $$;
revoke all on function public.notify_workflow(),public.queue_missed_checkout_reminders() from public,anon,authenticated;
grant execute on function public.queue_missed_checkout_reminders() to service_role;
revoke all on function public.read_notifications(uuid) from public,anon;
grant execute on function public.read_notifications(uuid) to authenticated;
create extension if not exists pg_cron with schema pg_catalog;
select cron.schedule('hr-missed-checkout-reminders','*/15 * * * *','select public.queue_missed_checkout_reminders();');
commit;
