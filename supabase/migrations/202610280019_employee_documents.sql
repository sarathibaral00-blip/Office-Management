begin;
create table public.employee_documents(id uuid primary key default gen_random_uuid(),employee_id uuid not null references public.profiles(id),uploaded_by uuid not null references public.profiles(id),kind text not null check(kind in ('nid','cv','certificate','contract')),title text not null,storage_path text not null unique,created_at timestamptz not null default now());
create index documents_employee_idx on public.employee_documents(employee_id,created_at);create index documents_uploader_idx on public.employee_documents(uploaded_by);
alter table public.employee_documents enable row level security;revoke all on public.employee_documents from public,anon,authenticated;grant select on public.employee_documents to authenticated;grant all on public.employee_documents to service_role;
create policy documents_private on public.employee_documents for select to authenticated using((select public.current_role()) is not null and (employee_id=(select auth.uid()) or (select public.has_permission('documents.manage'))));
create trigger audit_change after insert on public.employee_documents for each row execute function public.audit_change();
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('employee-documents','employee-documents',false,10485760,array['application/pdf','image/png','image/jpeg']) on conflict(id) do nothing;
do $$ begin if exists(select 1 from storage.buckets where id='employee-documents' and public) then raise exception 'Employee document bucket must be private';end if;end $$;
create policy documents_storage_read on storage.objects for select to authenticated using(bucket_id='employee-documents' and (select public.current_role()) is not null and ((storage.foldername(name))[1]=(select auth.uid())::text or (select public.has_permission('documents.manage'))));
create policy documents_storage_insert on storage.objects for insert to authenticated with check(bucket_id='employee-documents' and (select public.current_role()) is not null and ((storage.foldername(name))[1]=(select auth.uid())::text or ((select public.has_permission('documents.manage')) and exists(select 1 from public.profiles p where p.id::text=(storage.foldername(name))[1]))));
create function public.register_employee_document(p_employee uuid,p_kind text,p_title text,p_path text) returns uuid language plpgsql security definer set search_path='' as $$ declare result uuid;begin
 if public.current_role() is null or (p_employee is distinct from auth.uid() and not public.has_permission('documents.manage')) then raise exception 'Document access denied';end if;
 if p_kind not in ('nid','cv','certificate','contract') or length(trim(coalesce(p_title,'')))<3 then raise exception 'Choose a document type and title';end if;
 if split_part(coalesce(p_path,''),'/',1) is distinct from p_employee::text or not exists(select 1 from storage.objects where bucket_id='employee-documents' and name=p_path) then raise exception 'Upload to the employee document folder first';end if;
 insert into public.employee_documents(employee_id,uploaded_by,kind,title,storage_path) values(p_employee,auth.uid(),p_kind,trim(p_title),p_path) returning id into result;return result;
end $$;
revoke all on function public.register_employee_document(uuid,text,text,text) from public,anon;grant execute on function public.register_employee_document(uuid,text,text,text) to authenticated;
commit;
