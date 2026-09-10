-- Migration: create_account_profiles
-- Phase 2: HourTV account profiles, Row Level Security, and 5-profile invariant

create table public.account_profiles (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  name text not null check (char_length(btrim(name)) between 1 and 32),
  avatar_id text not null check (char_length(btrim(avatar_id)) between 1 and 64),
  is_kids boolean not null default false,
  position smallint not null check (position between 0 and 4),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (owner_id, position)
);

create index account_profiles_owner_id_idx
  on public.account_profiles(owner_id);

alter table public.account_profiles enable row level security;
revoke all on table public.account_profiles from anon, authenticated;
grant select, insert, update, delete on table public.account_profiles to authenticated;

create policy "account_profiles_select_owned"
on public.account_profiles for select to authenticated
using ((select auth.uid()) is not null and (select auth.uid()) = owner_id);

create policy "account_profiles_insert_owned"
on public.account_profiles for insert to authenticated
with check ((select auth.uid()) is not null and (select auth.uid()) = owner_id);

create policy "account_profiles_update_owned"
on public.account_profiles for update to authenticated
using ((select auth.uid()) is not null and (select auth.uid()) = owner_id)
with check ((select auth.uid()) is not null and (select auth.uid()) = owner_id);

create policy "account_profiles_delete_owned"
on public.account_profiles for delete to authenticated
using ((select auth.uid()) is not null and (select auth.uid()) = owner_id);

create function public.enforce_account_profile_limit()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
  existing_count integer;
begin
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(new.owner_id::text, 0)
  );
  select count(*) into existing_count
  from public.account_profiles
  where owner_id = new.owner_id;
  if existing_count >= 5 then
    raise exception using
      errcode = '23514',
      message = 'profile_limit_exceeded';
  end if;
  return new;
end;
$$;

revoke all on function public.enforce_account_profile_limit() from public;

create trigger account_profiles_limit_before_insert
before insert on public.account_profiles
for each row execute function public.enforce_account_profile_limit();

create function public.touch_account_profile_updated_at()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  new.updated_at = pg_catalog.now();
  return new;
end;
$$;

revoke all on function public.touch_account_profile_updated_at() from public;

create trigger account_profiles_touch_before_update
before update on public.account_profiles
for each row execute function public.touch_account_profile_updated_at();
