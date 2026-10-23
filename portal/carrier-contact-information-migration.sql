-- Tucker's Truckers carrier setup: FMCSA and personal contact fields
-- Run this in Supabase SQL Editor after deploying the updated portal/workspace.html.
-- This only adds profile columns; it does not change roles, policies, or existing records.

alter table public.carrier_profiles
  add column if not exists dba_name text,
  add column if not exists fmcsa_phone text,
  add column if not exists fmcsa_email text,
  add column if not exists personal_address text,
  add column if not exists personal_phone text,
  add column if not exists personal_email text,
  add column if not exists cell_phone text,
  add column if not exists secondary_phone text,
  add column if not exists same_address_as_fmcsa boolean not null default false,
  add column if not exists same_phone_as_fmcsa boolean not null default false,
  add column if not exists same_email_as_fmcsa boolean not null default false;

-- Keep existing fields (business_name, mc_number, dot_number, contact_name,
-- contact_email, phone, mailing_address, and fmcsa_address) for compatibility.
