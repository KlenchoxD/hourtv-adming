-- Migration: create_title_like_counts
-- "Me gusta" globales: cuántos perfiles le dieron Me gusta a cada película o
-- serie. Cada perfil guarda su Me gusta en profile_extras (kind = 'like',
-- key = clave estable del título, value = true/false). Esta función solo
-- devuelve el total por título, nunca quién lo dio, así que la pueden
-- consultar también quienes usan la app sin cuenta.
--
-- Idempotente: se puede ejecutar más de una vez.

create index if not exists profile_extras_likes_idx
  on public.profile_extras (key)
  where kind = 'like' and value = 'true'::jsonb;

create or replace function public.get_like_counts(p_keys text[])
returns table (key text, likes bigint)
language sql
stable
security definer
set search_path = ''
as $$
  select e.key, count(*)::bigint as likes
  from public.profile_extras e
  where e.kind = 'like'
    and e.value = 'true'::jsonb
    and e.key = any (p_keys)
    and pg_catalog.cardinality(p_keys) <= 500
  group by e.key;
$$;

revoke all on function public.get_like_counts(text[]) from public;
grant execute on function public.get_like_counts(text[]) to anon, authenticated;
