-- Tucker's Truckers Carrier Portal: onboarding extension
-- Run this in Supabase SQL Editor after the original database/admin/storage setup.
-- Safe to re-run: columns are added only when missing and policies are recreated by name.

alter table public.carrier_profiles
  add column if not exists business_name text,
  add column if not exists mc_number text,
  add column if not exists dot_number text,
  add column if not exists contact_name text,
  add column if not exists contact_email text,
  add column if not exists phone text,
  add column if not exists fleet_size integer,
  add column if not exists equipment text[] not null default '{}',
  add column if not exists mailing_address text,
  add column if not exists updated_at timestamptz not null default now();

create table if not exists public.carrier_documents (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  document_type text not null check (document_type in ('operating_authority','insurance','w9','voided_check','other')),
  file_name text not null,
  file_path text not null unique,
  content_type text not null,
  uploaded_at timestamptz not null default now()
);

alter table public.carrier_documents enable row level security;

drop policy if exists "Carriers view their own document records" on public.carrier_documents;
create policy "Carriers view their own document records"
on public.carrier_documents for select to authenticated
using (auth.uid() = user_id or public.is_portal_admin());

drop policy if exists "Carriers add their own document records" on public.carrier_documents;
create policy "Carriers add their own document records"
on public.carrier_documents for insert to authenticated
with check (auth.uid() = user_id and not public.is_portal_admin());

drop policy if exists "Admins manage document records" on public.carrier_documents;
create policy "Admins manage document records"
on public.carrier_documents for all to authenticated
using (public.is_portal_admin())
with check (public.is_portal_admin());

drop policy if exists "Carriers update their own profile" on public.carrier_profiles;
create policy "Carriers update their own profile"
on public.carrier_profiles for update to authenticated
using (auth.uid() = user_id and not public.is_portal_admin())
with check (auth.uid() = user_id and not public.is_portal_admin());

drop policy if exists "Carriers create their own profile" on public.carrier_profiles;
create policy "Carriers create their own profile"
on public.carrier_profiles for insert to authenticated
with check (auth.uid() = user_id and not public.is_portal_admin());

-- This portal extension does not let carriers change admin-controlled onboarding status.
