-- Tucker's Truckers progressive onboarding and role foundation
-- Run in Supabase SQL Editor after the existing portal/admin/storage setup.
-- This does not enable electronic signing; signing remains disabled until a real auditable flow is configured.
alter table public.carrier_profiles add column if not exists fmcsa_name text, add column if not exists fmcsa_address text;
alter table public.carrier_documents drop constraint if exists carrier_documents_document_type_check;
alter table public.carrier_documents add constraint carrier_documents_document_type_check check (document_type in ('operating_authority','insurance','w9','voided_check','noa','cab_card','cdl','additional_certificate','other'));

create table if not exists public.portal_user_roles (
 user_id uuid primary key references auth.users(id) on delete cascade,
 role text not null check (role in ('platform_owner','dispatcher_admin','dispatcher','carrier_admin','carrier','driver')),
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
alter table public.portal_user_roles enable row level security;
drop policy if exists "Users read own role or platform admins read all" on public.portal_user_roles;
create policy "Users read own role or platform admins read all" on public.portal_user_roles for select to authenticated using (auth.uid()=user_id or public.is_portal_admin());
drop policy if exists "Platform admins manage portal roles" on public.portal_user_roles;
create policy "Platform admins manage portal roles" on public.portal_user_roles for all to authenticated using (public.is_portal_admin()) with check (public.is_portal_admin());

create table if not exists public.driver_profiles (
 user_id uuid primary key references auth.users(id) on delete cascade, full_name text not null default '', email text not null default '',
 phone text, mailing_address text, license_state text, license_number text, owns_truck boolean not null default false, updated_at timestamptz not null default now()
);
alter table public.driver_profiles enable row level security;
drop policy if exists "Drivers read own profile" on public.driver_profiles;
create policy "Drivers read own profile" on public.driver_profiles for select to authenticated using (auth.uid()=user_id or public.is_portal_admin());
drop policy if exists "Drivers create own profile" on public.driver_profiles;
create policy "Drivers create own profile" on public.driver_profiles for insert to authenticated with check (auth.uid()=user_id and not public.is_portal_admin());
drop policy if exists "Drivers update own profile" on public.driver_profiles;
create policy "Drivers update own profile" on public.driver_profiles for update to authenticated using (auth.uid()=user_id and not public.is_portal_admin()) with check (auth.uid()=user_id and not public.is_portal_admin());
drop policy if exists "Platform admins manage driver profiles" on public.driver_profiles;
create policy "Platform admins manage driver profiles" on public.driver_profiles for all to authenticated using (public.is_portal_admin()) with check (public.is_portal_admin());

create table if not exists public.portal_setup_progress (
 user_id uuid primary key references auth.users(id) on delete cascade,
 initial_profile_complete boolean not null default false,
 agreement_status text not null default 'pending' check (agreement_status in ('pending','sent','signed','declined')),
 agreement_signed_at timestamptz,
 fleet_complete boolean not null default false, documents_complete boolean not null default false,
 drivers_complete boolean not null default false, credentials_complete boolean not null default false,
 updated_at timestamptz not null default now()
);
alter table public.portal_setup_progress enable row level security;
drop policy if exists "Users read own setup progress" on public.portal_setup_progress;
create policy "Users read own setup progress" on public.portal_setup_progress for select to authenticated using (auth.uid()=user_id or public.is_portal_admin());
drop policy if exists "Users initialize own setup progress" on public.portal_setup_progress;
create policy "Users initialize own setup progress" on public.portal_setup_progress for insert to authenticated with check (auth.uid()=user_id and not public.is_portal_admin());
drop policy if exists "Users update own setup progress" on public.portal_setup_progress;
create policy "Users update own setup progress" on public.portal_setup_progress for update to authenticated using (auth.uid()=user_id and not public.is_portal_admin()) with check (auth.uid()=user_id and not public.is_portal_admin());
drop policy if exists "Platform admins manage setup progress" on public.portal_setup_progress;
create policy "Platform admins manage setup progress" on public.portal_setup_progress for all to authenticated using (public.is_portal_admin()) with check (public.is_portal_admin());

create or replace function public.guard_portal_agreement_fields() returns trigger language plpgsql security definer set search_path = '' as $$
begin
 if auth.uid() is not null and not public.is_portal_admin() then
  if new.agreement_status is distinct from old.agreement_status or new.agreement_signed_at is distinct from old.agreement_signed_at then
   raise exception 'Agreement status can only be updated by the authorized signing workflow.';
  end if;
 end if;
 return new;
end;
$$;
drop trigger if exists guard_portal_agreement_fields_trigger on public.portal_setup_progress;
create trigger guard_portal_agreement_fields_trigger before update on public.portal_setup_progress for each row execute function public.guard_portal_agreement_fields();

-- Role assignments are not self-service. Only platform admins can manage portal_user_roles.
-- Users without a role row are temporarily treated as carriers by the workspace UI.
-- Assign driver/dispatcher roles through a secure admin workflow before inviting those users.
