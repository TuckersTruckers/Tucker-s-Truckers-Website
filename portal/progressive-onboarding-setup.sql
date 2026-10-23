-- Tucker's Truckers progressive onboarding and role foundation
-- Run in Supabase SQL Editor after the existing portal/admin setup.
-- This adds role assignments and staged setup without changing the existing auth or private storage configuration.

create table if not exists public.portal_user_roles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  role text not null check (role in ('platform_owner','dispatcher_admin','dispatcher','carrier_admin','carrier','driver')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.portal_user_roles enable row level security;
drop policy if exists "Users read own role or platform admins read all" on public.portal_user_roles;
create policy "Users read own role or platform admins read all" on public.portal_user_roles
for select to authenticated using (auth.uid() = user_id or public.is_portal_admin());
drop policy if exists "Platform admins manage portal roles" on public.portal_user_roles;
create policy "Platform admins manage portal roles" on public.portal_user_roles
for all to authenticated using (public.is_portal_admin()) with check (public.is_portal_admin());

create table if not exists public.driver_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null default '',
  email text not null default '',
  phone text,
  mailing_address text,
  license_state text,
  license_number text,
  owns_truck boolean not null default false,
  updated_at timestamptz not null default now()
);
alter table public.driver_profiles enable row level security;
drop policy if exists "Drivers read own profile" on public.driver_profiles;
create policy "Drivers read own profile" on public.driver_profiles
for select to authenticated using (auth.uid() = user_id or public.is_portal_admin());
drop policy if exists "Drivers create own profile" on public.driver_profiles;
create policy "Drivers create own profile" on public.driver_profiles
for insert to authenticated with check (auth.uid() = user_id and not public.is_portal_admin());
drop policy if exists "Drivers update own profile" on public.driver_profiles;
create policy "Drivers update own profile" on public.driver_profiles
for update to authenticated using (auth.uid() = user_id and not public.is_portal_admin())
with check (auth.uid() = user_id and not public.is_portal_admin());
drop policy if exists "Platform admins manage driver profiles" on public.driver_profiles;
create policy "Platform admins manage driver profiles" on public.driver_profiles
for all to authenticated using (public.is_portal_admin()) with check (public.is_portal_admin());

create table if not exists public.portal_setup_progress (
  user_id uuid primary key references auth.users(id) on delete cascade,
  initial_profile_complete boolean not null default false,
  agreement_status text not null default 'pending' check (agreement_status in ('pending','sent','signed','declined')),
  agreement_signed_at timestamptz,
  fleet_complete boolean not null default false,
  documents_complete boolean not null default false,
  drivers_complete boolean not null default false,
  credentials_complete boolean not null default false,
  updated_at timestamptz not null default now()
);
alter table public.portal_setup_progress enable row level security;
drop policy if exists "Users read own setup progress" on public.portal_setup_progress;
create policy "Users read own setup progress" on public.portal_setup_progress
for select to authenticated using (auth.uid() = user_id or public.is_portal_admin());
drop policy if exists "Users initialize own setup progress" on public.portal_setup_progress;
create policy "Users initialize own setup progress" on public.portal_setup_progress
for insert to authenticated with check (auth.uid() = user_id and not public.is_portal_admin());
drop policy if exists "Users update own setup progress" on public.portal_setup_progress;
create policy "Users update own setup progress" on public.portal_setup_progress
for update to authenticated using (auth.uid() = user_id and not public.is_portal_admin())
with check (auth.uid() = user_id and not public.is_portal_admin());
drop policy if exists "Platform admins manage setup progress" on public.portal_setup_progress;
create policy "Platform admins manage setup progress" on public.portal_setup_progress
for all to authenticated using (public.is_portal_admin()) with check (public.is_portal_admin());

-- Do not allow users to self-assign roles. Only platform admins can change portal_user_roles.
-- Agreement status is not marked signed by a checkbox; use a real e-sign provider/auditable signing flow.
