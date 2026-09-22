create table public.backup_providers (
  id uuid primary key default gen_random_uuid(),
  name text not null unique check (length(btrim(name)) between 1 and 120),
  base_url text,
  adapter_name text not null check (adapter_name ~ '^[a-z0-9][a-z0-9-]*$'),
  priority integer not null check (priority >= 0),
  is_active boolean not null default true,
  last_tested_at timestamptz,
  last_error text,
  successful_searches bigint not null default 0 check (successful_searches >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint backup_providers_base_url_secure check (
    base_url is null or (
      base_url ~* '^https://[a-z0-9.-]+(:[0-9]+)?(/.*)?$'
      and base_url !~* '^(https://)?([^/@]+@)'
      and base_url !~* '^(https://)?(localhost|127\.|0\.0\.0\.0|\[::1\]|10\.|172\.(1[6-9]|2[0-9]|3[0-1])\.|192\.168\.|169\.254\.|\[fe80:)'
      and base_url !~* '(\?|&|#)(token|api_key|secret|auth|cookie|jwt)='
    )
  )
);

create unique index backup_providers_priority_unique_idx on public.backup_providers(priority);
create index backup_providers_active_priority_idx on public.backup_providers(priority, id) where is_active;

create table public.replacement_candidates (
  id uuid primary key default gen_random_uuid(),
  source_id uuid not null references public.sources(id) on delete cascade,
  backup_provider_id uuid not null references public.backup_providers(id) on delete restrict,
  proposed_url text not null,
  proposed_name text,
  proposed_language_code text,
  content_type text not null check (content_type in ('movie', 'episode')),
  tmdb_id integer,
  normalized_title text not null,
  release_year integer check (release_year is null or release_year between 1888 and 2200),
  season_number integer check (season_number is null or season_number >= 0),
  episode_number integer check (episode_number is null or episode_number > 0),
  is_reproducible boolean not null default false,
  confidence text not null check (confidence in ('high', 'medium', 'low', 'rejected')),
  confidence_reasons jsonb not null default '[]'::jsonb check (jsonb_typeof(confidence_reasons) = 'array'),
  status text not null default 'pending' check (status in ('pending', 'approved', 'discarded', 'applied', 'failed', 'expired')),
  checked_at timestamptz not null,
  expires_at timestamptz not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint replacement_candidates_episode_identity check (
    (content_type = 'movie' and season_number is null and episode_number is null)
    or (content_type = 'episode' and season_number is not null and episode_number is not null)
  ),
  constraint replacement_candidates_expiry check (expires_at > checked_at),
  constraint replacement_candidates_url_secure check (
    proposed_url ~* '^https://'
    and proposed_url !~* '^(https://)?([^/@]+@)'
    and proposed_url !~* '^(https://)?(localhost|127\.|0\.0\.0\.0|\[::1\]|10\.|172\.(1[6-9]|2[0-9]|3[0-1])\.|192\.168\.|169\.254\.|\[fe80:)'
    and proposed_url !~* '(\?|&|#)(token|api_key|secret|auth|cookie|jwt)='
  )
);

create unique index replacement_candidates_source_url_pending_idx
  on public.replacement_candidates(source_id, proposed_url)
  where status in ('pending', 'approved');
create index replacement_candidates_source_status_idx
  on public.replacement_candidates(source_id, status, confidence, checked_at desc);
create index replacement_candidates_provider_idx
  on public.replacement_candidates(backup_provider_id, created_at desc);

create table public.admin_notifications (
  id uuid primary key default gen_random_uuid(),
  notification_type text not null check (notification_type in (
    'suspected_down', 'confirmed_down', 'replacement_found', 'recovered',
    'backup_provider_error', 'replacement_unavailable', 'publish_completed', 'publish_failed'
  )),
  source_id uuid references public.sources(id) on delete cascade,
  candidate_id uuid references public.replacement_candidates(id) on delete set null,
  message text not null check (length(btrim(message)) > 0),
  status text not null default 'open' check (status in ('open', 'processing', 'resolved', 'dismissed', 'failed')),
  is_read boolean not null default false,
  read_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint admin_notifications_read_state check (
    (is_read = false and read_at is null) or (is_read = true and read_at is not null)
  )
);

create index admin_notifications_unread_idx on public.admin_notifications(created_at desc) where not is_read;
create index admin_notifications_source_status_idx on public.admin_notifications(source_id, status, created_at desc);

create table public.source_replacement_events (
  id uuid primary key default gen_random_uuid(),
  source_id uuid not null references public.sources(id) on delete restrict,
  replacement_source_id uuid references public.sources(id) on delete restrict,
  candidate_id uuid references public.replacement_candidates(id) on delete set null,
  event_type text not null check (event_type in ('approved', 'discarded', 'applied', 'failed', 'rolled_back')),
  actor_id uuid not null default auth.uid() references auth.users(id) on delete restrict,
  previous_state jsonb not null default '{}'::jsonb check (jsonb_typeof(previous_state) = 'object'),
  resulting_state jsonb not null default '{}'::jsonb check (jsonb_typeof(resulting_state) = 'object'),
  failure_reason text,
  created_at timestamptz not null default now(),
  constraint source_replacement_events_distinct_sources check (
    replacement_source_id is null or replacement_source_id <> source_id
  )
);

create index source_replacement_events_source_idx on public.source_replacement_events(source_id, created_at desc);
create index source_replacement_events_candidate_idx on public.source_replacement_events(candidate_id, created_at desc);

alter table public.backup_providers enable row level security;
alter table public.replacement_candidates enable row level security;
alter table public.admin_notifications enable row level security;
alter table public.source_replacement_events enable row level security;

revoke all on public.backup_providers, public.replacement_candidates,
  public.admin_notifications, public.source_replacement_events from public, anon, authenticated;
grant select, insert, update, delete on public.backup_providers, public.replacement_candidates,
  public.admin_notifications, public.source_replacement_events to authenticated;

create policy backup_providers_admin_select on public.backup_providers
  for select to authenticated using ((select public.is_admin()));
create policy backup_providers_admin_insert on public.backup_providers
  for insert to authenticated with check ((select public.is_admin()));
create policy backup_providers_admin_update on public.backup_providers
  for update to authenticated using ((select public.is_admin())) with check ((select public.is_admin()));
create policy backup_providers_admin_delete on public.backup_providers
  for delete to authenticated using ((select public.is_admin()));

create policy replacement_candidates_admin_select on public.replacement_candidates
  for select to authenticated using ((select public.is_admin()));
create policy replacement_candidates_admin_insert on public.replacement_candidates
  for insert to authenticated with check ((select public.is_admin()));
create policy replacement_candidates_admin_update on public.replacement_candidates
  for update to authenticated using ((select public.is_admin())) with check ((select public.is_admin()));
create policy replacement_candidates_admin_delete on public.replacement_candidates
  for delete to authenticated using ((select public.is_admin()));

create policy admin_notifications_admin_select on public.admin_notifications
  for select to authenticated using ((select public.is_admin()));
create policy admin_notifications_admin_insert on public.admin_notifications
  for insert to authenticated with check ((select public.is_admin()));
create policy admin_notifications_admin_update on public.admin_notifications
  for update to authenticated using ((select public.is_admin())) with check ((select public.is_admin()));
create policy admin_notifications_admin_delete on public.admin_notifications
  for delete to authenticated using ((select public.is_admin()));

create policy source_replacement_events_admin_select on public.source_replacement_events
  for select to authenticated using ((select public.is_admin()));
create policy source_replacement_events_admin_insert on public.source_replacement_events
  for insert to authenticated with check ((select public.is_admin()) and actor_id = (select auth.uid()));
create policy source_replacement_events_admin_update on public.source_replacement_events
  for update to authenticated using ((select public.is_admin()))
  with check ((select public.is_admin()) and actor_id = (select auth.uid()));
create policy source_replacement_events_admin_delete on public.source_replacement_events
  for delete to authenticated using ((select public.is_admin()));
