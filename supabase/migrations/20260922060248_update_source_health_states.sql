alter table public.sources
  drop constraint if exists sources_health_status_check;

alter table public.sources
  add constraint sources_health_status_check
  check (health_status in (
    'pending',
    'active',
    'degraded',
    'suspected_down',
    'down',
    'recovered',
    'blocked_or_unknown'
  ));

alter table private.source_health_checks
  drop constraint if exists source_health_checks_status_checked_check;

alter table private.source_health_checks
  add constraint source_health_checks_status_checked_check
  check (status_checked in (
    'pending',
    'active',
    'degraded',
    'suspected_down',
    'down',
    'recovered',
    'blocked_or_unknown'
  ));
