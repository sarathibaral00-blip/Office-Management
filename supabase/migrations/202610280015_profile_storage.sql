begin;
alter table public.profiles add column phone text,add column photo_path text;
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('profile-photos','profile-photos',false,5242880,array['image/jpeg','image/png','image/webp']) on conflict(id) do nothing;
-- Existing buckets are never made public or overwritten by this migration.
do $$ begin
 if exists(select 1 from storage.buckets where id='profile-photos' and (public or file_size_limit is null or file_size_limit>5242880 or allowed_mime_types is null or not allowed_mime_types <@ array['image/jpeg','image/png','image/webp'])) then raise exception 'Existing profile-photos bucket has incompatible access or file limits; review before applying'; end if;
end $$;
create policy own_profile_photo_read on storage.objects for select to authenticated using(bucket_id='profile-photos' and (storage.foldername(name))[1]=(select auth.uid())::text and (select public.current_role()) is not null);
create policy own_profile_photo_insert on storage.objects for insert to authenticated with check(bucket_id='profile-photos' and (storage.foldername(name))[1]=(select auth.uid())::text and (select public.current_role()) is not null);
-- No update/delete policy: photos are immutable uploads, preserving history.
create function public.validate_profile_contact() returns trigger language plpgsql set search_path='' as $$ begin
 if new.phone is not null and new.phone !~ '^\+?[0-9 ()-]{6,24}$' then raise exception 'Enter a valid phone number'; end if;
 if new.photo_path is not null and (split_part(new.photo_path,'/',1)<>new.id::text or not exists(select 1 from storage.objects where bucket_id='profile-photos' and name=new.photo_path)) then raise exception 'Upload a photo to your own profile folder first'; end if;
 return new;
end $$;
create trigger validate_profile_contact before update of phone,photo_path on public.profiles for each row execute function public.validate_profile_contact();
create function public.save_my_profile(p_phone text,p_photo_path text,p_replace_photo boolean default false,p_update_phone boolean default true) returns void language plpgsql security definer set search_path='' as $$ begin
 if public.current_role() is null then raise exception 'Active account required'; end if;
 update public.profiles set phone=case when p_update_phone then nullif(trim(p_phone),'') else phone end,photo_path=case when p_replace_photo then p_photo_path else photo_path end where id=auth.uid();
end $$;
revoke all on function public.validate_profile_contact() from public,anon,authenticated;
revoke all on function public.save_my_profile(text,text,boolean,boolean) from public,anon;
grant execute on function public.save_my_profile(text,text,boolean,boolean) to authenticated;
commit;
