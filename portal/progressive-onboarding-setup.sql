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
  if tg_op = 'INSERT' then
   if new.agreement_status <> 'pending' or new.agreement_signed_at is not null then
    raise exception 'Agreement status can only be set by the authorized signing workflow.';
   end if;
  elsif new.agreement_status is distinct from old.agreement_status or new.agreement_signed_at is distinct from old.agreement_signed_at then
   raise exception 'Agreement status can only be updated by the authorized signing workflow.';
  end if;
 end if;
 return new;
end;
$;
drop trigger if exists guard_portal_agreement_fields_trigger on public.portal_setup_progress;
create trigger guard_portal_agreement_fields_trigger before insert or update on public.portal_setup_progress for each row execute function public.guard_portal_agreement_fields();

-- Role assignments are not self-service. Only platform admins can manage portal_user_roles.
-- Users without a role row are temporarily treated as carriers by the workspace UI.
-- Assign driver/dispatcher roles through a secure admin workflow before inviting those users.


-- Platform-owner invitation preparation: choose the intended login type before sending the Supabase invite.
create table if not exists public.portal_invites (
 id uuid primary key default gen_random_uuid(),
 email text not null unique,
 role text not null check (role in ('dispatcher_admin','dispatcher','carrier_admin','carrier','driver')),
 status text not null default 'prepared' check (status in ('prepared','used','cancelled')),
 prepared_by uuid references auth.users(id),
 created_at timestamptz not null default now(),
 used_at timestamptz
);
alter table public.portal_invites enable row level security;
drop policy if exists "Platform admins manage prepared invites" on public.portal_invites;
create policy "Platform admins manage prepared invites" on public.portal_invites
for all to authenticated using (public.is_portal_admin()) with check (public.is_portal_admin());

create or replace function public.prepare_portal_invite(invite_email text, invite_role text)
returns void language plpgsql security definer set search_path = '' as $$
begin
 if not public.is_portal_admin() then raise exception 'Only platform admins can prepare invitations.'; end if;
 if lower(trim(invite_email)) = '' then raise exception 'Email is required.'; end if;
 if invite_role not in ('dispatcher_admin','dispatcher','carrier_admin','carrier','driver') then raise exception 'Invalid login type.'; end if;
 insert into public.portal_invites(email,role,status,prepared_by,created_at,used_at)
 values(lower(trim(invite_email)),invite_role,'prepared',auth.uid(),now(),null)
 on conflict (email) do update set role=excluded.role,status='prepared',prepared_by=auth.uid(),created_at=now(),used_at=null;
end;
$$;
grant execute on function public.prepare_portal_invite(text,text) to authenticated;

create or replace function public.apply_prepared_portal_invite()
returns trigger language plpgsql security definer set search_path = '' as $$
declare invitation public.portal_invites%rowtype;
begin
 select * into invitation from public.portal_invites
 where lower(email)=lower(new.email) and status='prepared' limit 1;
 if found then
  insert into public.portal_user_roles(user_id,role,created_at,updated_at)
  values(new.id,invitation.role,now(),now())
  on conflict (user_id) do update set role=excluded.role,updated_at=now();
  update public.portal_invites set status='used',used_at=now() where id=invitation.id;
 end if;
 return new;
end;
$$;
drop trigger if exists apply_prepared_portal_invite_trigger on auth.users;
create trigger apply_prepared_portal_invite_trigger after insert on auth.users
for each row execute function public.apply_prepared_portal_invite();

-- Do not put platform_owner in invite choices. The existing portal_admins table remains the source of super-admin status.
