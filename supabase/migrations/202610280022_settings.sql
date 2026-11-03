begin;
create function public.save_company_settings(p_data jsonb) returns void language plpgsql security definer set search_path='' as $$
declare c public.company_settings;fee numeric;multiplier numeric;max_ot numeric;free_count integer;begin
 if not public.has_permission('settings.manage') then raise exception 'Settings access required';end if;
 select * into c from public.company_settings where singleton for update;
 fee:=coalesce((p_data->>'late_fee')::numeric,c.late_fee);multiplier:=coalesce((p_data->>'overtime_multiplier')::numeric,c.overtime_multiplier);max_ot:=coalesce((p_data->>'max_daily_overtime')::numeric,c.max_daily_overtime);free_count:=coalesce((p_data->>'free_lates')::integer,c.free_lates);
 if least(fee,multiplier,max_ot,free_count)<0 or fee>=1000000000000 or fee::text in ('NaN','Infinity','-Infinity') or multiplier>5 or max_ot>12 or free_count>31 then raise exception 'Invalid late or overtime policy';end if;
 if length(trim(coalesce(p_data->>'company_name',c.company_name)))<2 or coalesce(p_data->>'currency',c.currency) !~ '^[A-Z]{3}$' then raise exception 'Company name and a three-letter currency are required';end if;
 perform set_config('app.audit_reason','Company profile and payroll policy updated',true);
 update public.company_settings set company_name=coalesce(p_data->>'company_name',company_name),address=coalesce(p_data->>'address',address),registration_no=coalesce(p_data->>'registration_no',registration_no),currency=coalesce(p_data->>'currency',currency),deduct_absence=coalesce((p_data->>'deduct_absence')::boolean,deduct_absence),late_fee=fee,free_lates=free_count,overtime_multiplier=multiplier,max_daily_overtime=max_ot,updated_at=now() where singleton;
end $$;
create function public.set_company_asset(p_kind text,p_path text) returns void language plpgsql security definer set search_path='' as $$ begin
 if not public.has_permission('settings.manage') then raise exception 'Settings access required';end if;
 if p_kind is null or p_path is null or p_kind not in ('logo','signature') or split_part(coalesce(p_path,''),'/',1)<>(case when p_kind='logo' then 'logos' else 'signatures' end) or not exists(select 1 from storage.objects where bucket_id='company-assets' and name=p_path) then raise exception 'Upload the matching company asset first';end if;
 perform set_config('app.audit_reason','Company '||p_kind||' asset changed',true);
 update public.company_settings set logo_path=case when p_kind='logo' then p_path else logo_path end,signature_path=case when p_kind='signature' then p_path else signature_path end,updated_at=now() where singleton;
end $$;
create function public.save_shift(p_id uuid,p_name text,p_start text,p_end text,p_grace integer,p_days integer[],p_default boolean) returns uuid language plpgsql security definer set search_path='' as $$ declare result uuid;begin
 if not public.has_permission('settings.manage') then raise exception 'Settings access required';end if;
 if length(trim(coalesce(p_name,'')))<2 or coalesce(p_start,'') !~ '^([01][0-9]|2[0-3]):[0-5][0-9]$' or coalesce(p_end,'') !~ '^([01][0-9]|2[0-3]):[0-5][0-9]$' or p_grace is null or p_grace not between 0 and 120 or coalesce(cardinality(p_days),0)=0 or not p_days <@ array[0,1,2,3,4,5,6] or p_default is null then raise exception 'Enter a valid shift, 24-hour times, grace period and working days';end if;
 perform pg_advisory_xact_lock(hashtext('company-shifts'));
 if p_id is not null and not p_default and exists(select 1 from public.shifts where id=p_id and is_default) then raise exception 'Choose another default shift before clearing this default';end if;
 perform set_config('app.audit_reason','Shift schedule, working days and grace updated',true);
 if p_default then update public.shifts set is_default=false where is_default;end if;
 if p_id is null then insert into public.shifts(name,starts_at,ends_at,grace_minutes,work_days,is_default) values(trim(p_name),p_start::time,p_end::time,p_grace,p_days,p_default) returning id into result;
 else update public.shifts set name=trim(p_name),starts_at=p_start::time,ends_at=p_end::time,grace_minutes=p_grace,work_days=p_days,is_default=p_default where id=p_id returning id into result;end if;
 if result is null then raise exception 'Shift not found';end if;return result;
end $$;
create function public.set_role_permission(p_role public.app_role,p_key text,p_enabled boolean) returns void language plpgsql security definer set search_path='' as $$ begin
 if public.current_role()<>'super_admin' or public.current_role() is null then raise exception 'Super admin access required';end if;
 if p_role='super_admin' or p_enabled is null then raise exception 'Super admin capabilities cannot be disabled';end if;
 if p_enabled and p_role not in ('hr','super_admin') and not(p_key='reports.export_own' or (p_role='manager' and p_key='reports.export_team')) then raise exception 'Capabilities cannot expand the role security ceiling';end if;
 perform set_config('app.audit_reason','Super admin changed role capability '||p_key,true);
 update public.role_permissions set enabled=p_enabled where role=p_role and permission=p_key;if not found then raise exception 'Capability not found';end if;
end $$;
create function public.audit_records(p_offset integer default 0,p_table text default null) returns jsonb language plpgsql stable security definer set search_path='' as $$ declare result jsonb;begin
 if not public.is_hr() or not public.has_permission('audit.view') then raise exception 'Audit access required';end if;
 if p_offset is null or p_offset<0 then raise exception 'Invalid audit page';end if;
 with page as(select * from public.audit_log a where (p_table is null or a.table_name=p_table) and
 (public.current_role()='super_admin' or case when a.table_name in ('payroll','payroll_runs','salary_structures') then public.has_permission('payroll.manage') when a.table_name in ('employee_financing','payroll_installments') then public.has_permission('financing.review') when a.table_name='expense_claims' then public.has_permission('expenses.review') when a.table_name='employee_documents' then public.has_permission('documents.manage') when a.table_name='generated_letters' then public.has_permission('letters.issue') when a.table_name='company_settings' then public.has_permission('settings.manage') when a.table_name='role_permissions' then false else true end)
 order by created_at desc,id desc offset p_offset limit 51)
 select jsonb_build_object('rows',coalesce((select jsonb_agg(to_jsonb(r)) from(select * from page limit 50) r),'[]'::jsonb),'has_more',(select count(*)>50 from page)) into result;return result;
end $$;
revoke all on function public.save_company_settings(jsonb),public.set_company_asset(text,text),public.save_shift(uuid,text,text,text,integer,integer[],boolean),public.set_role_permission(public.app_role,text,boolean),public.audit_records(integer,text) from public,anon;
grant execute on function public.save_company_settings(jsonb),public.set_company_asset(text,text),public.save_shift(uuid,text,text,text,integer,integer[],boolean),public.set_role_permission(public.app_role,text,boolean),public.audit_records(integer,text) to authenticated;
commit;
