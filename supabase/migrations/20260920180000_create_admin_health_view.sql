-- Vista de administración para Servidores Caídos
-- Permite a los administradores ver información de fuentes y sus últimos chequeos de salud.

-- 1. Función para verificar si el usuario actual es administrador
-- Usamos current_setting con restrictor 't' (true) para que no falle si falta la variable,
-- asegurando que no haya escalada de privilegios en el search_path
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = ''
AS $$
  SELECT coalesce(current_setting('request.jwt.claims', true)::jsonb -> 'app_metadata' ->> 'role', '') = 'admin';
$$;

-- 2. Vista segura para consultar las fuentes caídas
-- Se ejecuta con los privilegios de quien la invoca (security_invoker = true),
-- por lo que respeta íntegramente las políticas RLS de sources, titles, episodes y seasons.
CREATE OR REPLACE VIEW public.admin_down_sources_view
WITH (security_invoker = true) AS
SELECT
    s.id AS source_id,
    s.name AS source_name,
    s.url AS source_url,
    s.health_status,
    s.health_last_error,
    s.health_http_code,
    s.health_consecutive_failures,
    s.health_first_failure_at,
    s.health_last_check,
    t.id AS title_id,
    t.title AS title_name,
    t.media_type,
    e.id AS episode_id,
    e.episode_number,
    e.title AS episode_name,
    se.season_number
FROM public.sources s
LEFT JOIN public.titles t ON s.title_id = t.id
LEFT JOIN public.episodes e ON s.episode_id = e.id
LEFT JOIN public.seasons se ON e.season_id = se.id
WHERE s.health_status = 'down'
  AND public.is_admin();

-- 3. Revocar accesos por defecto y conceder solo a usuarios autenticados
REVOKE ALL ON public.admin_down_sources_view FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.admin_down_sources_view TO authenticated;
