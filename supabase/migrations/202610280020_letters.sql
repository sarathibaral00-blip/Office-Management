begin;
create table public.generated_letters(id uuid primary key default gen_random_uuid(),employee_id uuid not null references public.profiles(id),issued_by uuid not null references public.profiles(id),kind text not null check(kind in ('appointment','confirmation','experience','salary_certificate','noc')),purpose text not null,snapshot jsonb not null,created_at timestamptz not null default now());
create index letters_employee_idx on public.generated_letters(employee_id,created_at);create index letters_issuer_idx on public.generated_letters(issued_by);
alter table public.generated_letters enable row level security;revoke all on public.generated_letters from public,anon,authenticated;grant select on public.generated_letters to authenticated;grant all on public.generated_letters to service_role;
create policy letters_hr_read on public.generated_letters for select to authenticated using((select public.has_permission('letters.issue')));
create trigger audit_change after insert on public.generated_letters for each row execute function public.audit_change();
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('company-assets','company-assets',false,2097152,array['image/png','image/jpeg']) on conflict(id) do nothing;
do $$ begin if exists(select 1 from storage.buckets where id='company-assets' and public) then raise exception 'Company asset bucket must be private';end if;end $$;
create policy company_assets_read on storage.objects for select to authenticated using(bucket_id='company-assets' and (select public.current_role()) is not null and ((storage.foldername(name))[1]='logos' or (select public.has_permission('letters.issue')) or (select public.has_permission('settings.manage'))));
create policy company_assets_insert on storage.objects for insert to authenticated with check(bucket_id='company-assets' and (select public.has_permission('settings.manage')) and (storage.foldername(name))[1] in ('logos','signatures'));
create function public.issue_letter(p_employee uuid,p_kind text,p_purpose text) returns uuid language plpgsql security definer set search_path='' as $$
declare p public.profiles;cfg public.company_settings;salary numeric;result uuid;begin
 if not public.has_permission('letters.issue') then raise exception 'Letter issuance access required';end if;
 if p_kind not in ('appointment','confirmation','experience','salary_certificate','noc') or length(trim(coalesce(p_purpose,'')))<3 or length(p_purpose)>2000 then raise exception 'Choose a template and enter the letter purpose';end if;
 select * into p from public.profiles where id=p_employee;if not found then raise exception 'Employee not found';end if;select * into cfg from public.company_settings where singleton;
 if cfg.logo_path is null or cfg.signature_path is null then raise exception 'Configure the company logo and authorized signature first';end if;
 select basic+house_rent+medical+conveyance into salary from public.salary_structures where employee_id=p.id;
 insert into public.generated_letters(employee_id,issued_by,kind,purpose,snapshot) values(p.id,auth.uid(),p_kind,trim(p_purpose),jsonb_build_object('employee',jsonb_build_object('name',p.full_name,'code',p.employee_code,'designation',p.designation,'joined_at',p.joined_at,'salary',coalesce(salary,p.salary)),'company',jsonb_build_object('name',cfg.company_name,'address',cfg.address,'registration_no',cfg.registration_no,'currency',cfg.currency,'logo_path',cfg.logo_path,'signature_path',cfg.signature_path))) returning id into result;return result;
end $$;
revoke all on function public.issue_letter(uuid,text,text) from public,anon;grant execute on function public.issue_letter(uuid,text,text) to authenticated;
commit;
