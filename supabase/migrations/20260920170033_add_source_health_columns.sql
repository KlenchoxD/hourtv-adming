ALTER TABLE public.sources
  ADD COLUMN health_status text NOT NULL DEFAULT 'pending'
      CHECK (health_status IN ('pending', 'active', 'degraded', 'down', 'recovered')),
  ADD COLUMN health_last_error text,
  ADD COLUMN health_http_code int CHECK (health_http_code IS NULL OR (health_http_code >= 100 AND health_http_code <= 599)),
  ADD COLUMN health_consecutive_failures int NOT NULL DEFAULT 0 CHECK (health_consecutive_failures >= 0),
  ADD COLUMN health_first_failure_at timestamptz,
  ADD COLUMN health_last_success_at timestamptz,
  ADD COLUMN health_last_check timestamptz,
  ADD COLUMN health_last_check_run_id text,
  ADD COLUMN replaced_by_id uuid REFERENCES public.sources(id) ON DELETE SET NULL;

CREATE INDEX idx_sources_health_status ON public.sources(health_status);

CREATE SCHEMA IF NOT EXISTS private;
REVOKE ALL ON SCHEMA private FROM PUBLIC, anon, authenticated;

CREATE TABLE private.source_health_checks (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  source_id uuid NOT NULL REFERENCES public.sources(id) ON DELETE CASCADE,
  run_id text NOT NULL,
  status_checked text NOT NULL CHECK (status_checked IN ('pending', 'active', 'degraded', 'down', 'recovered')),
  error_msg text,
  http_code int CHECK (http_code IS NULL OR (http_code >= 100 AND http_code <= 599)),
  checked_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE private.source_health_checks ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON private.source_health_checks FROM PUBLIC, anon, authenticated;

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA private
  REVOKE ALL ON TABLES FROM PUBLIC, anon, authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA private
  REVOKE ALL ON SEQUENCES FROM PUBLIC, anon, authenticated;

CREATE INDEX idx_source_health_checks_sid_checked_at ON private.source_health_checks(source_id, checked_at);
