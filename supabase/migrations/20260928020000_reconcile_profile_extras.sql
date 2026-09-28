-- Migration: reconcile_profile_extras
-- En el servidor se ejecutó una versión distinta de profile_extras (columna
-- item_key, id propio, trigger que pisa updated_at con la hora del servidor).
-- La app escribe en la columna "key" y necesita conservar la fecha de cada
-- cambio para que gane el más reciente entre equipos.
--
-- 1. Si existe esa otra versión y está VACÍA, se elimina (junto con sus
--    funciones). Si tuviera datos, se detiene sin borrar nada.
-- 2. Se crea la versión que usa la app (igual a create_profile_extras).
--
-- Idempotente: se puede ejecutar más de una vez.

do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'profile_extras'
      and column_name = 'item_key'
  ) then
    if exists (select 1 from public.profile_extras limit 1) then
      raise exception
        'profile_extras (versión item_key) tiene datos: no se borra automáticamente';
    end if;
    drop table public.profile_extras cascade;
  end if;
end;
$$;

drop function if exists public.enforce_profile_extras_limit() cascade;
drop function if exists public.touch_profile_extras_updated_at() cascade;


create table if not exists public.profile_extras (
  profile_id uuid not null
    references public.account_profiles(id) on delete cascade,
  owner_id uuid not null default auth.uid()
    references auth.users(id) on delete cascade,
  kind text not null check (kind in ('like', 'watch_count', 'setting')),
  key text not null check (char_length(key) between 1 and 512),
  value jsonb not null,
  updated_at timestamptz not null default now(),
  primary key (profile_id, kind, key)
);

create index if not exists profile_extras_owner_idx
  on public.profile_extras(owner_id);

alter table public.profile_extras enable row level security;
revoke all on table public.profile_extras from anon, authenticated;
grant select, insert, update, delete on table public.profile_extras to authenticated;

drop policy if exists "profile_extras_select_owned" on public.profile_extras;
create policy "profile_extras_select_owned"
on public.profile_extras for select to authenticated
using ((select auth.uid()) is not null and (select auth.uid()) = owner_id);

-- Solo en perfiles propios: el perfil tiene que ser del mismo dueño.
drop policy if exists "profile_extras_insert_owned" on public.profile_extras;
create policy "profile_extras_insert_owned"
on public.profile_extras for insert to authenticated
with check (
  (select auth.uid()) is not null
  and (select auth.uid()) = owner_id
  and exists (
    select 1 from public.account_profiles p
    where p.id = profile_id and p.owner_id = (select auth.uid())
  )
);

drop policy if exists "profile_extras_update_owned" on public.profile_extras;
create policy "profile_extras_update_owned"
on public.profile_extras for update to authenticated
using ((select auth.uid()) is not null and (select auth.uid()) = owner_id)
with check (
  (select auth.uid()) = owner_id
  and exists (
    select 1 from public.account_profiles p
    where p.id = profile_id and p.owner_id = (select auth.uid())
  )
);

drop policy if exists "profile_extras_delete_owned" on public.profile_extras;
create policy "profile_extras_delete_owned"
on public.profile_extras for delete to authenticated
using ((select auth.uid()) is not null and (select auth.uid()) = owner_id);

create or replace function public.profile_extras_merge()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  -- Nunca cambia de dueño ni de perfil.
  new.owner_id := old.owner_id;
  new.profile_id := old.profile_id;

  if new.kind = 'watch_count' then
    if pg_catalog.jsonb_typeof(new.value) <> 'number' then
      raise exception 'watch_count debe ser numérico' using errcode = '22023';
    end if;
    if pg_catalog.jsonb_typeof(old.value) = 'number'
       and (old.value)::text::numeric > (new.value)::text::numeric then
      new.value := old.value;
    end if;
    new.updated_at := greatest(old.updated_at, new.updated_at);
    return new;
  end if;

  -- like / setting: si llega un cambio más viejo, se conserva el actual.
  if new.updated_at < old.updated_at then
    return null;
  end if;
  return new;
end;
$$;

drop trigger if exists profile_extras_merge_trg on public.profile_extras;
create trigger profile_extras_merge_trg
before update on public.profile_extras
for each row execute function public.profile_extras_merge();

-- Límite sano por perfil (evita que un error de la app llene la tabla).
create or replace function public.profile_extras_limit()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if (select count(*) from public.profile_extras
      where profile_id = new.profile_id) >= 20000 then
    raise exception 'profile_extras_limit_exceeded' using errcode = '23514';
  end if;
  return new;
end;
$$;

drop trigger if exists profile_extras_limit_trg on public.profile_extras;
create trigger profile_extras_limit_trg
before insert on public.profile_extras
for each row execute function public.profile_extras_limit();
