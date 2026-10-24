-- Tucker's Truckers private carrier document storage policies
-- Project: bvrlpwkzqmqfcupqjugf
-- Bucket ID must exactly match the private bucket created in Supabase: carrier-documents
--
-- Run only after confirming there are no other permissive storage.objects policies
-- that grant broader access to this bucket. Supabase combines permissive policies with OR,
-- so an older broad policy could override these restrictions.

-- Carrier accounts can only read files in their own top-level user-id folder.
drop policy if exists "TT carrier documents read own folder" on storage.objects;
create policy "TT carrier documents read own folder"
on storage.objects for select to authenticated
using (
  bucket_id = 'carrier-documents'
  and (
    (storage.foldername(name))[1] = (select auth.uid())::text
    or public.is_portal_admin()
  )
);

-- Carriers can upload only into their own user-id folder; platform admins can upload
-- documents into the appropriate carrier's folder from the admin workflow.
drop policy if exists "TT carrier documents upload own folder" on storage.objects;
create policy "TT carrier documents upload own folder"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'carrier-documents'
  and (
    (storage.foldername(name))[1] = (select auth.uid())::text
    or public.is_portal_admin()
  )
);

-- Allow removal of an upload if its database record could not be saved, and allow
-- platform administrators to manage carrier files.
drop policy if exists "TT carrier documents delete own folder" on storage.objects;
create policy "TT carrier documents delete own folder"
on storage.objects for delete to authenticated
using (
  bucket_id = 'carrier-documents'
  and (
    (storage.foldername(name))[1] = (select auth.uid())::text
    or public.is_portal_admin()
  )
);

-- Updating/replacing objects is not required by the portal today, but keep any future
-- update operation tenant-scoped in the same way.
drop policy if exists "TT carrier documents update own folder" on storage.objects;
create policy "TT carrier documents update own folder"
on storage.objects for update to authenticated
using (
  bucket_id = 'carrier-documents'
  and (
    (storage.foldername(name))[1] = (select auth.uid())::text
    or public.is_portal_admin()
  )
)
with check (
  bucket_id = 'carrier-documents'
  and (
    (storage.foldername(name))[1] = (select auth.uid())::text
    or public.is_portal_admin()
  )
);

-- Review all policies after applying. Confirm there are no broader policies that can
-- grant anon/public access or bypass the carrier-folder restriction.
select schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
from pg_policies
where schemaname = 'storage' and tablename = 'objects'
order by policyname;
