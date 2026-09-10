-- HourTV Supabase local seed file
-- Phase 2: Account profiles are owned per authenticated user (auth.uid()).
-- Seed data is populated dynamically during test runs.

-- Phase 3: Metadatos iniciales de sincronización del catálogo
INSERT INTO public.catalog_sync_metadata (id, minimum_available_revision, latest_revision, updated_at)
VALUES (1, 1, 0, now())
ON CONFLICT (id) DO NOTHING;

-- Géneros iniciales predeterminados
INSERT INTO public.genres (id, name, slug) VALUES
  ('20000000-0000-0000-0000-000000000001', 'Acción', 'accion'),
  ('20000000-0000-0000-0000-000000000002', 'Comedia', 'comedia'),
  ('20000000-0000-0000-0000-000000000003', 'Drama', 'drama'),
  ('20000000-0000-0000-0000-000000000004', 'Terror', 'terror'),
  ('20000000-0000-0000-0000-000000000005', 'Ciencia Ficción', 'ciencia-ficcion'),
  ('20000000-0000-0000-0000-000000000006', 'Animación', 'animacion')
ON CONFLICT (slug) DO NOTHING;

-- Idiomas iniciales predeterminados
INSERT INTO public.languages (id, code, name) VALUES
  ('10000000-0000-0000-0000-000000000001', 'es', 'Español'),
  ('10000000-0000-0000-0000-000000000002', 'lat', 'Latino'),
  ('10000000-0000-0000-0000-000000000003', 'sub', 'Subtitulado'),
  ('10000000-0000-0000-0000-000000000004', 'en', 'Inglés')
ON CONFLICT (code) DO NOTHING;
