
-- El chequeo manual debe poder persistir toda la evidencia de salud, pero
-- únicamente para el rol autenticado que satisface public.is_admin().
grant update (
  health_status,
  health_last_error,
  health_http_code,
  health_consecutive_failures,
  health_first_failure_at,
  health_last_success_at,
  health_last_check,
  health_last_check_run_id
) on public.sources to authenticated;
