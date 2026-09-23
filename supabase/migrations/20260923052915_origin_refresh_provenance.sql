-- Conserva la página que originó cada fuente para poder volver a consultarla
-- cuando el enlace extraído deja de funcionar.
create table if not exists public.source_origin_refreshes (
  id uuid primary key default gen_random_uuid(),
  source_id uuid not null references public.sources(id) on delete cascade,
  origin_url text not null,
  previous_url text not null,
  new_url text not null,
  evidence jsonb not null default '{}'::jsonb check (jsonb_typeof(evidence) = 'object'),
  detected_at timestamptz not null default now()
);

create index if not exists source_origin_refreshes_source_idx
  on public.source_origin_refreshes(source_id, detected_at desc);

alter table public.source_origin_refreshes enable row level security;
revoke all on public.source_origin_refreshes from public, anon, authenticated;
grant select, insert on public.source_origin_refreshes to authenticated;
drop policy if exists source_origin_refreshes_admin_select on public.source_origin_refreshes;
create policy source_origin_refreshes_admin_select on public.source_origin_refreshes
  for select to authenticated using ((select public.is_admin()));
drop policy if exists source_origin_refreshes_admin_insert on public.source_origin_refreshes;
create policy source_origin_refreshes_admin_insert on public.source_origin_refreshes
  for insert to authenticated with check ((select public.is_admin()));

-- Las fuentes generadas por Server Hunter llevan la página original en
-- referer_url. El origen se conserva por separado para validación/diagnóstico.
alter table public.admin_notifications
  drop constraint if exists admin_notifications_notification_type_check;
alter table public.admin_notifications
  add constraint admin_notifications_notification_type_check check (notification_type in (
    'suspected_down', 'confirmed_down', 'replacement_found', 'recovered',
    'origin_refreshed', 'backup_provider_error', 'replacement_unavailable',
    'publish_completed', 'publish_failed'
  ));

drop view if exists public.admin_source_health_view;
create view public.admin_source_health_view
with (security_invoker = true) as
select
  s.id as source_id,
  s.name as source_name,
  s.url as source_url,
  s.referer_url,
  s.origin_url,
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
