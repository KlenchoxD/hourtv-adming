
-- El panel necesita ver también las fuentes activas para poder revalidarlas
-- manualmente y detectar reproductores embebidos que fallen aunque la página
-- contenedora responda 200.
create or replace view public.admin_source_health_view
with (security_invoker = true) as
select
  s.id as source_id,
  s.name as source_name,
  s.url as source_url,
  l.code as language_code,
  s.order_index,
  s.health_status,
  s.health_last_error,
  s.health_http_code,
  s.health_consecutive_failures,
  s.health_first_failure_at,
  s.health_last_success_at,
  s.health_last_check,
  t.id as title_id,
  t.legacy_id,
  t.tmdb_id,
  t.normalized_title,
  t.year as release_year,
  t.title as title_name,
  t.media_type,
  e.id as episode_id,
  e.episode_number,
  e.title as episode_name,
  se.season_number
from public.sources s
join public.titles t on t.id = coalesce(
  s.title_id,
  (select se2.title_id
   from public.episodes e2
   join public.seasons se2 on se2.id = e2.season_id
   where e2.id = s.episode_id)
)
left join public.languages l on l.id = s.language_id
left join public.episodes e on e.id = s.episode_id
left join public.seasons se on se.id = e.season_id
where public.is_admin();

revoke all on public.admin_source_health_view from public, anon, authenticated;
grant select on public.admin_source_health_view to authenticated;
