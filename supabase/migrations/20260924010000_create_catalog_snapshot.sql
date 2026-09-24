-- El catálogo publicado en GitHub (catalog.json) se sirve por
-- raw.githubusercontent.com, cuya red de distribución (CDN) puede tardar
-- minutos en propagar una actualización a todas las regiones, y de forma
-- desigual: un usuario puede ver el catálogo nuevo mientras otro, en otra
-- zona, sigue viendo uno viejo con la misma URL. Esta tabla guarda una
-- copia exacta del catálogo publicado para que la app la lea directo de
-- Postgres (sin caché de CDN de por medio): se actualiza al instante para
-- todos apenas el panel publica.
CREATE TABLE IF NOT EXISTS public.catalog_snapshot (
  id int PRIMARY KEY DEFAULT 1 CHECK (id = 1),
  content text NOT NULL,
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.catalog_snapshot ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON public.catalog_snapshot FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.catalog_snapshot TO anon, authenticated;
GRANT UPDATE (content, updated_at) ON public.catalog_snapshot TO authenticated;
GRANT INSERT ON public.catalog_snapshot TO authenticated;

DROP POLICY IF EXISTS p_catalog_snapshot_select_public ON public.catalog_snapshot;
CREATE POLICY p_catalog_snapshot_select_public ON public.catalog_snapshot
FOR SELECT TO anon, authenticated
USING (true);

DROP POLICY IF EXISTS p_catalog_snapshot_write_admin ON public.catalog_snapshot;
CREATE POLICY p_catalog_snapshot_write_admin ON public.catalog_snapshot
FOR ALL TO authenticated
USING (public.is_admin())
WITH CHECK (public.is_admin());
