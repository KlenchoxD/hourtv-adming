-- Migration: create_top_liked
-- Fila "Lo que más gusta" del Inicio: los títulos con más "Me gusta" de todos
-- los perfiles. Como get_like_counts, solo devuelve el total por título
-- (nunca quién lo dio), así que la pueden consultar también quienes usan la
-- app sin cuenta.
--
-- Idempotente: se puede ejecutar más de una vez. Usa el índice
-- profile_extras_likes_idx creado en 20260928030000.

create or replace function public.get_top_liked(p_limit integer default 40)
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
  group by e.key
  order by likes desc, e.key
  limit least(greatest(coalesce(p_limit, 40), 1), 100);
$$;

revoke all on function public.get_top_liked(integer) from public;
grant execute on function public.get_top_liked(integer) to anon, authenticated;
