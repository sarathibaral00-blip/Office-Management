-- Execute as postgres on the linked dev database AFTER migration 006.
-- No existing data is removed: fixtures, edits, PINs and credentials roll back.
begin;
insert into auth.users(id,email,raw_user_meta_data) values
 ('10000000-0000-4000-a000-000000000001','fallback-hr@example.invalid','{}'),
 ('10000000-0000-4000-a000-000000000002','fallback-manual@example.invalid','{}'),
 ('10000000-0000-4000-a000-000000000003','fallback-kiosk@example.invalid','{}'),
 ('10000000-0000-4000-a000-000000000004','fallback-temp@example.invalid','{}');
insert into public.branches(id,name,timezone) values('10000000-0000-4000-a000-000000000010','Fallback test branch','UTC');
insert into public.allowed_networks(label,branch_id,network) values('Fallback test IP','10000000-0000-4000-a000-000000000010','203.0.113.10/32');
insert into public.shifts(id,name,starts_at,ends_at) values('10000000-0000-4000-a000-000000000011','Fallback test shift','09:00','18:00');
update public.profiles set role='hr' where id='10000000-0000-4000-a000-000000000001';
update public.profiles set branch_id='10000000-0000-4000-a000-000000000010',shift_id='10000000-0000-4000-a000-000000000011' where id::text like '10000000-0000-4000-a000-00000000000%';

do $$
declare hr uuid:='10000000-0000-4000-a000-000000000001'; employee uuid:='10000000-0000-4000-a000-000000000002';
 kiosk_employee uuid:='10000000-0000-4000-a000-000000000003'; temp_employee uuid:='10000000-0000-4000-a000-000000000004';
 branch uuid:='10000000-0000-4000-a000-000000000010'; value jsonb; credential jsonb; temporary jsonb;
 code text; temp_code text; d date:=(date_trunc('month',now())-interval '1 month')::date; entry uuid; i integer;
begin
 if has_function_privilege('authenticated','public.manual_attendance(uuid,uuid,timestamptz,timestamptz,text,inet,uuid)','execute')
 or has_function_privilege('authenticated','public.device_attendance(uuid,text,text,text,text,text,inet)','execute')
 or has_function_privilege('anon','public.device_attendance(uuid,text,text,text,text,text,inet)','execute')
 or has_function_privilege('authenticated','public.manage_attendance_fallback(uuid,text,jsonb,inet)','execute') then raise exception 'Fallback RPC exposed to client'; end if;
 if has_schema_privilege('authenticated','attendance_private','usage') or has_table_privilege('authenticated','attendance_private.employee_pins','select') then raise exception 'PIN schema or table exposed'; end if;
 if has_table_privilege('authenticated','public.attendance','insert') or has_table_privilege('authenticated','public.attendance','update') then raise exception 'Attendance direct writes exposed'; end if;
 begin
  perform public.manual_attendance(employee,employee,(d+time '09:00') at time zone 'UTC',(d+time '17:00') at time zone 'UTC','Not allowed','203.0.113.10');
  raise exception 'Employee authorization bypass';
 exception when raise_exception then if SQLERRM='Employee authorization bypass' then raise; end if; end;
 perform public.manage_attendance_fallback(hr,'set_limit','{"limit":3,"reason":"Test policy"}','203.0.113.10');
 for i in 0..3 loop
  value:=public.manual_attendance(hr,employee,((d+i)+time '09:00') at time zone 'UTC',((d+i)+time '17:00') at time zone 'UTC','Forgot employee phone','203.0.113.10');
 end loop;
 if (value->>'manual_count')::integer<>4 or not (value->>'limit_exceeded')::boolean then raise exception 'Monthly manual limit not counted'; end if;
 if not exists(select 1 from public.hr_attendance_alerts where employee_id=employee and month=d and manual_count=4) then raise exception 'Persistent HR alert missing'; end if;
 entry:=(value->'attendance'->>'id')::uuid;
 value:=public.manual_attendance(hr,employee,((d+3)+time '09:00') at time zone 'UTC',((d+3)+time '18:00') at time zone 'UTC','Corrected checkout with HR','203.0.113.10',entry);
 if (value->>'manual_count')::integer<>4 then raise exception 'Editing counted as another manual day'; end if;
 if not exists(select 1 from public.audit_log where table_name='attendance' and record_id=entry::text and actor_id=hr and employee_id=employee and old_values is not null and new_values->>'source'='manual' and reason='Corrected checkout with HR') then raise exception 'Complete manual audit missing'; end if;
 begin
  perform public.manual_attendance(hr,employee,((d+3)+time '09:00') at time zone 'UTC',null,'','203.0.113.10',entry);
  raise exception 'Empty manual reason accepted';
 exception when raise_exception then if SQLERRM='Empty manual reason accepted' then raise; end if; end;
 select employee_code into code from public.profiles where id=kiosk_employee;
 select employee_code into temp_code from public.profiles where id=temp_employee;
 perform public.manage_attendance_fallback(hr,'set_pin',jsonb_build_object('employee_id',kiosk_employee,'pin','654321'),'203.0.113.10');
 perform public.manage_attendance_fallback(hr,'set_pin',jsonb_build_object('employee_id',temp_employee,'pin','654321'),'203.0.113.10');
 if exists(select 1 from attendance_private.employee_pins where employee_id=kiosk_employee and pin_hash='654321') then raise exception 'PIN stored in plaintext'; end if;
 credential:=public.manage_attendance_fallback(hr,'register_device',jsonb_build_object('label','Kiosk fixture','kind','kiosk','branch_id',branch,'reason','Test approval'),'203.0.113.10');
 value:=public.device_attendance((credential->>'device_id')::uuid,credential->>'device_token','kiosk',code,'654321','check_in','203.0.113.99');
 if value->>'code' is distinct from 'OFFICE_WIFI_REQUIRED' then raise exception 'Kiosk accepted outside office'; end if;
 for i in 1..5 loop
  value:=public.device_attendance((credential->>'device_id')::uuid,credential->>'device_token','kiosk',code,'000000','check_in','203.0.113.10');
 end loop;
 if not exists(select 1 from attendance_private.employee_pins where employee_id=kiosk_employee and failed_attempts=5 and locked_at is not null) then raise exception 'Five-failure PIN lock did not persist'; end if;
 value:=public.device_attendance((credential->>'device_id')::uuid,credential->>'device_token','kiosk',code,'654321','check_in','203.0.113.10');
 if (value->>'ok')::boolean then raise exception 'Locked PIN accepted'; end if;
 perform public.manage_attendance_fallback(hr,'set_pin',jsonb_build_object('employee_id',kiosk_employee,'pin','654321'),'203.0.113.10');
 value:=public.device_attendance((credential->>'device_id')::uuid,credential->>'device_token','kiosk',code,'654321','check_in','203.0.113.10');
 if (value->>'ok')::boolean is distinct from true or value->'attendance'->>'source'<>'kiosk' then raise exception 'Approved kiosk punch failed'; end if;
 value:=public.device_attendance((credential->>'device_id')::uuid,credential->>'device_token','kiosk',code,'654321','check_in','203.0.113.10');
 if (value->>'ok')::boolean then raise exception 'Duplicate kiosk check-in accepted'; end if;
 value:=public.device_attendance((credential->>'device_id')::uuid,credential->>'device_token','kiosk',code,'654321','check_out','203.0.113.10');
 if (value->>'ok')::boolean is distinct from true then raise exception 'Kiosk checkout failed'; end if;
 -- Saturate the device window without needing to submit twenty bcrypt checks.
 update attendance_private.device_credentials set window_attempts=20 where device_id=(credential->>'device_id')::uuid;
 value:=public.device_attendance((credential->>'device_id')::uuid,credential->>'device_token','kiosk',code,'654321','check_in','203.0.113.10');
 if value->>'code' is distinct from 'RATE_LIMITED' then raise exception 'Device rate limit bypass'; end if;
 perform public.manage_attendance_fallback(hr,'rotate_device',jsonb_build_object('id',credential->>'device_id','reason','Test rotation'),'203.0.113.10');
 value:=public.device_attendance((credential->>'device_id')::uuid,credential->>'device_token','kiosk',code,'654321','check_in','203.0.113.10');
 if value->>'code' is distinct from 'DEVICE_REJECTED' then raise exception 'Old device credential still valid'; end if;
 temporary:=public.manage_attendance_fallback(hr,'register_device',jsonb_build_object('label','Temporary fixture','kind','temporary','branch_id',branch,'employee_id',temp_employee,'reason','Employee borrowed device'),'203.0.113.10');
 value:=public.device_attendance((temporary->>'device_id')::uuid,temporary->>'device_token','temporary',code,'654321','check_in','203.0.113.10');
 if (value->>'ok')::boolean then raise exception 'Temporary approval accepted another employee'; end if;
 value:=public.device_attendance((temporary->>'device_id')::uuid,temporary->>'device_token','temporary',temp_code,'654321','check_in','203.0.113.10');
 if (value->>'ok')::boolean is distinct from true then raise exception 'Temporary approval did not work'; end if;
 -- Simulate passage of time in this rollback-only fixture.
 update public.attendance_devices set approved_at=now()-interval '1 hour',expires_at=now()-interval '1 second' where id=(temporary->>'device_id')::uuid;
 value:=public.device_attendance((temporary->>'device_id')::uuid,temporary->>'device_token','temporary',temp_code,'654321','check_out','203.0.113.10');
 if value->>'code' is distinct from 'DEVICE_REJECTED' then raise exception 'Expired temporary approval accepted'; end if;
 if not exists(select 1 from public.attendance_devices where id=(temporary->>'device_id')::uuid and revoked_at is not null) then raise exception 'Expiry revocation not recorded'; end if;
 if exists(select 1 from public.audit_log where table_name='employee_pins' and (coalesce(old_values,'{}') ? 'pin_hash' or coalesce(new_values,'{}') ? 'pin_hash')) then raise exception 'PIN hash leaked into audit'; end if;
end $$;
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-a000-000000000002","role":"authenticated"}',true);
do $$ begin
 if exists(select 1 from public.attendance_devices) or exists(select 1 from public.hr_attendance_alerts) then raise exception 'HR data leaked to employee'; end if;
 if exists(select 1 from public.attendance where employee_id<>auth.uid()) then raise exception 'Other employee attendance leaked'; end if;
 begin
  perform pin_hash from attendance_private.employee_pins;
  raise exception 'Employee read PIN hash';
 exception when insufficient_privilege then null; end;
 begin
  update public.profiles set employee_code='IMPERSONATE' where id=auth.uid();
  raise exception 'Employee changed Employee ID';
 exception when raise_exception then if SQLERRM='Employee changed Employee ID' then raise; end if; end;
end $$;
select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-a000-000000000001","role":"authenticated"}',true);
do $$ begin
 if not exists(select 1 from public.audit_log where employee_id='10000000-0000-4000-a000-000000000002' and table_name='attendance' and old_values is not null) then raise exception 'HR cannot review attendance audit'; end if;
 begin
  perform pin_hash from attendance_private.employee_pins;
  raise exception 'HR read PIN hash directly';
 exception when insufficient_privilege then null; end;
end $$;
reset role;
rollback;
