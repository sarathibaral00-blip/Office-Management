-- Run as postgres on dev after migrations 007–015. Every fixture rolls back.
begin;
insert into auth.users(id,email,raw_user_meta_data) values
 ('30000000-0000-4000-a000-000000000001','workflow-e1@example.invalid','{"full_name":"Workflow Employee A"}'),
 ('30000000-0000-4000-a000-000000000002','workflow-e2@example.invalid','{"full_name":"Workflow Employee B"}'),
 ('30000000-0000-4000-a000-000000000003','workflow-m1@example.invalid','{"full_name":"Workflow Manager A"}'),
 ('30000000-0000-4000-a000-000000000004','workflow-m2@example.invalid','{"full_name":"Workflow Manager B"}'),
 ('30000000-0000-4000-a000-000000000005','workflow-hr@example.invalid','{"full_name":"Workflow HR"}'),
 ('30000000-0000-4000-a000-000000000006','workflow-super@example.invalid','{"full_name":"Workflow Super"}');
insert into public.departments(id,name) values('30000000-0000-4000-a000-000000000011','Workflow department A'),('30000000-0000-4000-a000-000000000012','Workflow department B');
insert into public.branches(id,name,timezone) values('30000000-0000-4000-a000-000000000013','Workflow branch','UTC');
insert into public.shifts(id,name,starts_at,ends_at,work_days) values('30000000-0000-4000-a000-000000000014','Workflow shift','09:00','17:00',array[0,1,2,3,4,5,6]);
update public.profiles set role='manager' where id in ('30000000-0000-4000-a000-000000000003','30000000-0000-4000-a000-000000000004');
update public.profiles set role='hr' where id='30000000-0000-4000-a000-000000000005';
update public.profiles set role='super_admin' where id='30000000-0000-4000-a000-000000000006';
update public.profiles set branch_id='30000000-0000-4000-a000-000000000013',shift_id='30000000-0000-4000-a000-000000000014',department_id='30000000-0000-4000-a000-000000000011',joined_at=current_date-60 where id::text like '30000000-0000-4000-a000-00000000000%';
update public.profiles set manager_id='30000000-0000-4000-a000-000000000003' where id='30000000-0000-4000-a000-000000000001';
update public.profiles set manager_id='30000000-0000-4000-a000-000000000004',department_id='30000000-0000-4000-a000-000000000012' where id='30000000-0000-4000-a000-000000000002';
insert into public.leave_types(id,name,annual_days,is_paid) values('30000000-0000-4000-a000-000000000015','Workflow half-day allocation',0.5,true);
insert into public.attendance(id,employee_id,branch_id,work_date,check_in,check_out,status,client_ip)
values('30000000-0000-4000-a000-000000000016','30000000-0000-4000-a000-000000000001','30000000-0000-4000-a000-000000000013',current_date-1,((current_date-1)+time '09:00') at time zone 'UTC',((current_date-1)+time '17:00') at time zone 'UTC','present','203.0.113.10');
insert into public.attendance(id,employee_id,branch_id,work_date,check_in,status,client_ip)
values('30000000-0000-4000-a000-000000000017','30000000-0000-4000-a000-000000000002','30000000-0000-4000-a000-000000000013',current_date-1,((current_date-1)+time '09:00') at time zone 'UTC','present','203.0.113.10');
select public.queue_missed_checkout_reminders();
select public.queue_missed_checkout_reminders();
do $$ begin
 if (select count(*) from public.notifications where employee_id='30000000-0000-4000-a000-000000000002' and dedupe_key='checkout:30000000-0000-4000-a000-000000000017')<>1 then raise exception 'Checkout reminder duplicated or missing';end if;
 if not exists(select 1 from cron.job where jobname='hr-missed-checkout-reminders' and active) then raise exception 'Checkout reminder schedule missing';end if;
end $$;
-- Metadata-only storage fixtures test policies without creating external blobs.
insert into storage.objects(bucket_id,name) values('profile-photos','30000000-0000-4000-a000-000000000001/workflow.jpg'),('profile-photos','30000000-0000-4000-a000-000000000002/workflow.jpg');
select set_config('test.workday',(select min(day)::text from public.leave_workdays('30000000-0000-4000-a000-000000000001',current_date+2,current_date+30,false)),true);
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"30000000-0000-4000-a000-000000000001","role":"authenticated"}',true);
do $$ declare request uuid; d date:=current_setting('test.workday')::date; begin
 if d is null then raise exception 'Fixture needs a scheduled workday'; end if;
 if exists(select 1 from public.profiles where id='30000000-0000-4000-a000-000000000002') then raise exception 'Employee can read another profile'; end if;
 begin perform public.update_employee(auth.uid(),'{"salary":500}');raise exception 'Employee called HR update';exception when raise_exception then if SQLERRM='Employee called HR update' then raise;end if;end;
 begin update public.profiles set role='hr' where id=auth.uid();raise exception 'Employee changed own role';exception when raise_exception then if SQLERRM='Employee changed own role' then raise;end if;end;
 begin update public.profiles set salary=500 where id=auth.uid();raise exception 'Employee changed own salary';exception when raise_exception then if SQLERRM='Employee changed own salary' then raise;end if;end;
 begin update public.profiles set is_active=false where id=auth.uid();raise exception 'Employee changed own active flag';exception when raise_exception then if SQLERRM='Employee changed own active flag' then raise;end if;end;
 request:=public.apply_leave('30000000-0000-4000-a000-000000000015',d,d,true,'am','Workflow half day');
 perform set_config('test.leave',request::text,true);
 if exists(select 1 from public.leave_balances where employee_id=auth.uid() and used>0) then raise exception 'Balance deducted before approval';end if;
 perform set_config('test.correction',public.request_attendance_correction('30000000-0000-4000-a000-000000000016',((current_date-1)+time '09:00') at time zone 'UTC',((current_date-1)+time '18:00') at time zone 'UTC','Missed checkout correction')::text,true);
 perform public.save_my_profile('+880 123456789',null);
 begin perform public.save_my_profile(null,'30000000-0000-4000-a000-000000000002/workflow.jpg',true,false);raise exception 'Employee claimed another photo';exception when raise_exception then if SQLERRM='Employee claimed another photo' then raise;end if;end;
 if exists(select 1 from storage.objects where bucket_id='profile-photos' and name='30000000-0000-4000-a000-000000000002/workflow.jpg') then raise exception 'Employee read another photo';end if;
 if (public.role_dashboard()->>'headcount')::integer<>1 then raise exception 'Employee dashboard leaks headcount';end if;
 begin perform public.attendance_report(current_date,current_date);raise exception 'Employee accessed HR report';exception when raise_exception then if SQLERRM='Employee accessed HR report' then raise;end if;end;
end $$;
select set_config('request.jwt.claims','{"sub":"30000000-0000-4000-a000-000000000004","role":"authenticated"}',true);
do $$ begin
 if exists(select 1 from public.profiles where id='30000000-0000-4000-a000-000000000001') then raise exception 'Manager read outside team';end if;
 begin perform public.review_leave(current_setting('test.leave')::uuid,true,'Wrong team');raise exception 'Manager approved outside team';exception when raise_exception then if SQLERRM='Manager approved outside team' then raise;end if;end;
 if exists(select 1 from public.attendance_correction_requests where id=current_setting('test.correction')::uuid) then raise exception 'Manager read outside-team correction';end if;
end $$;
select set_config('request.jwt.claims','{"sub":"30000000-0000-4000-a000-000000000003","role":"authenticated"}',true);
do $$ begin
 if not exists(select 1 from public.profiles where id='30000000-0000-4000-a000-000000000001') then raise exception 'Manager cannot see own team';end if;
 perform public.review_leave(current_setting('test.leave')::uuid,true,'Approved half day');
 if not exists(select 1 from public.leave_balances where employee_id='30000000-0000-4000-a000-000000000001' and leave_type_id='30000000-0000-4000-a000-000000000015' and used=0.5) then raise exception 'Half-day deduction failed';end if;
 begin perform public.review_leave(current_setting('test.leave')::uuid,true,'Again');raise exception 'Double approval permitted';exception when raise_exception then if SQLERRM='Double approval permitted' then raise;end if;end;
 if (public.role_dashboard()->>'headcount')::integer<>1 then raise exception 'Manager dashboard includes outside team';end if;
 begin perform public.review_attendance_correction(current_setting('test.correction')::uuid,true,'Manager cannot approve');raise exception 'Manager approved correction';exception when raise_exception then if SQLERRM='Manager approved correction' then raise;end if;end;
end $$;
select set_config('request.jwt.claims','{"sub":"30000000-0000-4000-a000-000000000001","role":"authenticated"}',true);
do $$ declare d date:=current_setting('test.workday')::date; next_day date:=d+1; request uuid; begin
 -- The fixture shift works every day; skip any pre-existing global holiday.
 while exists(select 1 from public.holidays where is_active and branch_id is null and holiday_date=next_day) loop next_day:=next_day+1;end loop;
 request:=public.apply_leave('30000000-0000-4000-a000-000000000015',next_day,next_day,false,null,'Over remaining allocation');
 perform set_config('test.insufficient',request::text,true);
 begin perform public.cancel_leave(current_setting('test.leave')::uuid);raise exception 'Approved leave cancelled';exception when raise_exception then if SQLERRM='Approved leave cancelled' then raise;end if;end;
end $$;
select set_config('request.jwt.claims','{"sub":"30000000-0000-4000-a000-000000000003","role":"authenticated"}',true);
do $$ begin
 begin perform public.review_leave(current_setting('test.insufficient')::uuid,true,'No balance');raise exception 'Insufficient balance approval succeeded';exception when raise_exception then if SQLERRM='Insufficient balance approval succeeded' then raise;end if;end;
 if (select status from public.leave_requests where id=current_setting('test.insufficient')::uuid)<>'pending' then raise exception 'Failed approval changed status';end if;
 if (select used from public.leave_balances where employee_id='30000000-0000-4000-a000-000000000001' and leave_type_id='30000000-0000-4000-a000-000000000015')<>0.5 then raise exception 'Failed approval changed balance';end if;
end $$;
select set_config('request.jwt.claims','{"sub":"30000000-0000-4000-a000-000000000005","role":"authenticated"}',true);
do $$ declare notice uuid; holiday uuid; begin
 begin perform public.update_employee(auth.uid(),'{"salary":500}');raise exception 'HR changed own salary';exception when raise_exception then if SQLERRM='HR changed own salary' then raise;end if;end;
 begin perform public.update_employee('30000000-0000-4000-a000-000000000006','{"role":"employee"}');raise exception 'HR demoted super admin';exception when raise_exception then if SQLERRM='HR demoted super admin' then raise;end if;end;
 perform public.update_employee('30000000-0000-4000-a000-000000000002','{"designation":"Engineer","is_active":false}');
 perform public.update_employee('30000000-0000-4000-a000-000000000002','{"is_active":true}');
 perform public.review_attendance_correction(current_setting('test.correction')::uuid,true,'Times verified by HR');
 if (select source from public.attendance where id='30000000-0000-4000-a000-000000000016')<>'correction' then raise exception 'Correction source not set';end if;
 if not exists(select 1 from public.audit_log where table_name='attendance' and record_id='30000000-0000-4000-a000-000000000016' and new_values->>'source'='correction' and old_values is not null and actor_id=auth.uid()) then raise exception 'Correction audit missing';end if;
 notice:=public.save_announcement(null,'Department A update','Private department update','30000000-0000-4000-a000-000000000011',true);
 perform set_config('test.notice',notice::text,true);
 holiday:=public.save_holiday(null,'Workflow archive fixture',current_date+30,'30000000-0000-4000-a000-000000000013',true);
 perform public.save_holiday(holiday,'Workflow archive fixture',current_date+30,'30000000-0000-4000-a000-000000000013',false);
 if not exists(select 1 from public.holidays where id=holiday and not is_active) then raise exception 'Holiday archive lost data';end if;
 if public.attendance_report(current_date-1,current_date-1,'30000000-0000-4000-a000-000000000011','30000000-0000-4000-a000-000000000013')->>'total' is null then raise exception 'HR report missing';end if;
end $$;
select set_config('request.jwt.claims','{"sub":"30000000-0000-4000-a000-000000000002","role":"authenticated"}',true);
do $$ begin
 if exists(select 1 from public.announcements where id=current_setting('test.notice')::uuid) then raise exception 'Wrong department notice leaked';end if;
 begin perform public.mark_announcement_read(current_setting('test.notice')::uuid);raise exception 'Wrong department receipt created';exception when raise_exception then if SQLERRM='Wrong department receipt created' then raise;end if;end;
 if exists(select 1 from public.notifications where employee_id<>auth.uid()) then raise exception 'Other notification leaked';end if;
 if exists(select 1 from public.leave_requests where id=current_setting('test.leave')::uuid) then raise exception 'Other employee leave leaked';end if;
end $$;
select set_config('request.jwt.claims','{"sub":"30000000-0000-4000-a000-000000000001","role":"authenticated"}',true);
do $$ begin
 if not exists(select 1 from public.announcements where id=current_setting('test.notice')::uuid) then raise exception 'Target department cannot read notice';end if;
 perform public.mark_announcement_read(current_setting('test.notice')::uuid);
 if not exists(select 1 from public.announcement_reads where announcement_id=current_setting('test.notice')::uuid and employee_id=auth.uid()) then raise exception 'Read receipt missing';end if;
 perform public.cancel_leave(current_setting('test.insufficient')::uuid);
end $$;
select set_config('request.jwt.claims','{"sub":"30000000-0000-4000-a000-000000000006","role":"authenticated"}',true);
do $$ begin
 perform public.update_employee('30000000-0000-4000-a000-000000000005','{"designation":"HR Lead"}');
 begin perform public.update_employee(auth.uid(),'{"is_active":false}');raise exception 'Super admin changed own active status';exception when raise_exception then if SQLERRM='Super admin changed own active status' then raise;end if;end;
 if exists(select 1 from pg_tables where schemaname='public' and tablename in ('attendance_correction_requests','announcement_reads','notifications') and not rowsecurity) then raise exception 'New table missing RLS';end if;
end $$;
select set_config('request.jwt.claims','{"sub":"30000000-0000-4000-a000-000000000001","role":"authenticated"}',true);
select set_config('test.stale',public.request_attendance_correction('30000000-0000-4000-a000-000000000016',((current_date-1)+time '09:00') at time zone 'UTC',((current_date-1)+time '18:30') at time zone 'UTC','Another requested correction')::text,true);
reset role;
update public.attendance set check_out=((current_date-1)+time '19:00') at time zone 'UTC' where id='30000000-0000-4000-a000-000000000016';
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"30000000-0000-4000-a000-000000000005","role":"authenticated"}',true);
do $$ begin
 begin perform public.review_attendance_correction(current_setting('test.stale')::uuid,true,'Stale review');raise exception 'Stale correction overwrote attendance';exception when raise_exception then if SQLERRM='Stale correction overwrote attendance' then raise;end if;end;
 if (select check_out from public.attendance where id='30000000-0000-4000-a000-000000000016') is distinct from (((current_date-1)+time '19:00') at time zone 'UTC') then raise exception 'Stale correction changed row';end if;
 perform public.review_attendance_correction(current_setting('test.stale')::uuid,false,'Attendance was already changed');
end $$;
reset role;
rollback;
