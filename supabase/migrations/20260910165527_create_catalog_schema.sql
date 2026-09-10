-- HourTV Catálogo Paginado y Sincronización Incremental (Fase 3)
-- Esquema relacional normalizado, triggers anti-filtración, funciones blindadas y RLS

CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA extensions;
CREATE EXTENSION IF NOT EXISTS unaccent WITH SCHEMA extensions;

-- Enums
DO $$ BEGIN
  CREATE TYPE public.media_type AS ENUM ('movie', 'series', 'anime', 'novela', 'live');
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
  CREATE TYPE public.catalog_entity_type AS ENUM ('title', 'season', 'episode', 'source', 'title_genre', 'genre', 'language');
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

-- 1. Idiomas
CREATE TABLE IF NOT EXISTS public.languages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text UNIQUE NOT NULL,
  name text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- 2. Géneros
CREATE TABLE IF NOT EXISTS public.genres (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  slug text UNIQUE NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- 3. Títulos
CREATE TABLE IF NOT EXISTS public.titles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  legacy_id text UNIQUE,
  media_type public.media_type NOT NULL,
  title text NOT NULL,
  original_title text,
  normalized_title text NOT NULL,
  plot text,
  year int,
  release_date date,
  duration text,
  rating numeric(3, 1),
  poster_url text,
  backdrop_url text,
  is_featured boolean NOT NULL DEFAULT false,
  is_published boolean NOT NULL DEFAULT true,
  cast_members text,
  director text,
  writer text,
  country_code text,
  tmdb_id int,
  imdb_id text,
  trakt_id int,
  tvmaze_id int,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz
);

-- 4. Relación Títulos y Géneros
CREATE TABLE IF NOT EXISTS public.title_genres (
  title_id uuid NOT NULL REFERENCES public.titles(id) ON DELETE CASCADE,
  genre_id uuid NOT NULL REFERENCES public.genres(id) ON DELETE CASCADE,
  PRIMARY KEY (title_id, genre_id)
);

-- 5. Temporadas
CREATE TABLE IF NOT EXISTS public.seasons (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title_id uuid NOT NULL REFERENCES public.titles(id) ON DELETE CASCADE,
  season_number int NOT NULL,
  name text,
  plot text,
  poster_url text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz,
  UNIQUE (title_id, season_number)
);

-- 6. Episodios
CREATE TABLE IF NOT EXISTS public.episodes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  season_id uuid NOT NULL REFERENCES public.seasons(id) ON DELETE CASCADE,
  episode_number int NOT NULL,
  title text NOT NULL,
  plot text,
  duration text,
  still_url text,
  release_date date,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz,
  UNIQUE (season_id, episode_number)
);

-- 7. Fuentes de Streaming
CREATE TABLE IF NOT EXISTS public.sources (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title_id uuid REFERENCES public.titles(id) ON DELETE CASCADE,
  episode_id uuid REFERENCES public.episodes(id) ON DELETE CASCADE,
  language_id uuid REFERENCES public.languages(id) ON DELETE SET NULL,
  name text NOT NULL,
  url text NOT NULL,
  order_index int NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'verified', 'down', 'requires_webview')),
  requires_webview boolean NOT NULL DEFAULT false,
  referer_url text,
  origin_url text,
  user_agent_profile text CHECK (user_agent_profile IS NULL OR user_agent_profile IN ('default', 'vlc_desktop', 'exo_player', 'browser_mobile')),
  verified_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz,
  CONSTRAINT chk_sources_target CHECK (
    (title_id IS NOT NULL AND episode_id IS NULL) OR
    (title_id IS NULL AND episode_id IS NOT NULL)
  ),
  CONSTRAINT chk_sources_url_secure CHECK (
    url ~* '^https://'
    AND url !~* '^(https://)?([^/@]+@)'
    AND url !~* '^(https://)?(localhost|127\.|0\.0\.0\.0|\[::1\])'
    AND url !~* '^(https://)?(10\.|172\.(1[6-9]|2[0-9]|3[0-1])\.|192\.168\.|169\.254\.|\[fe80:)'
    AND url !~* '(\?|&|#)(token|api_key|secret|auth|cookie|jwt)='
  ),
  CONSTRAINT chk_sources_referer_secure CHECK (
    referer_url IS NULL OR (
      referer_url ~* '^https://'
      AND referer_url !~* '^(https://)?([^/@]+@)'
      AND referer_url !~* '^(https://)?(localhost|127\.|0\.0\.0\.0|\[::1\])'
      AND referer_url !~* '^(https://)?(10\.|172\.(1[6-9]|2[0-9]|3[0-1])\.|192\.168\.|169\.254\.|\[fe80:)'
      AND referer_url !~* '(\?|&|#)(token|api_key|secret|auth|cookie|jwt)='
    )
  ),
  CONSTRAINT chk_sources_origin_secure CHECK (
    origin_url IS NULL OR (
      origin_url ~* '^https://[a-zA-Z0-9.-]+(:[0-9]+)?$'
      AND origin_url !~* '^(https://)?([^/@]+@)'
      AND origin_url !~* '^(https://)?(localhost|127\.|0\.0\.0\.0|\[::1\])'
      AND origin_url !~* '^(https://)?(10\.|172\.(1[6-9]|2[0-9]|3[0-1])\.|192\.168\.|169\.254\.|\[fe80:)'
    )
  )
);

-- 8. Registro de Cambios y Revisiones Incrementales
CREATE TABLE IF NOT EXISTS public.catalog_changes (
  revision bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  entity_type public.catalog_entity_type NOT NULL,
  entity_id text NOT NULL,
  operation text NOT NULL CHECK (operation IN ('upsert', 'delete')),
  changed_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_catalog_changes_revision ON public.catalog_changes (revision ASC);

-- 9. Metadatos de Sincronización y Retención
CREATE TABLE IF NOT EXISTS public.catalog_sync_metadata (
  id int PRIMARY KEY DEFAULT 1 CHECK (id = 1),
  minimum_available_revision bigint NOT NULL DEFAULT 1,
  latest_revision bigint NOT NULL DEFAULT 0,
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT chk_revision_invariants CHECK (minimum_available_revision <= latest_revision OR latest_revision = 0)
);

-- Inserción garantizada de la fila singleton
INSERT INTO public.catalog_sync_metadata (id, minimum_available_revision, latest_revision)
VALUES (1, 1, 0)
ON CONFLICT (id) DO NOTHING;

-- ============================================================================
-- Funciones PostgreSQL Blindadas y Triggers
-- ============================================================================

-- 1. Trigger para actualizar automáticamente latest_revision en metadata
CREATE OR REPLACE FUNCTION public.fn_update_catalog_sync_metadata_latest()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
  UPDATE public.catalog_sync_metadata
  SET latest_revision = NEW.revision,
      updated_at = now()
  WHERE id = 1;
  RETURN NEW;
END;
$$;
ALTER FUNCTION public.fn_update_catalog_sync_metadata_latest() OWNER TO postgres;
REVOKE ALL ON FUNCTION public.fn_update_catalog_sync_metadata_latest() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.fn_update_catalog_sync_metadata_latest() FROM anon;
REVOKE ALL ON FUNCTION public.fn_update_catalog_sync_metadata_latest() FROM authenticated;

DROP TRIGGER IF EXISTS trg_catalog_changes_update_latest ON public.catalog_changes;
CREATE TRIGGER trg_catalog_changes_update_latest
AFTER INSERT ON public.catalog_changes
FOR EACH ROW
EXECUTE FUNCTION public.fn_update_catalog_sync_metadata_latest();

-- 2. Función Administrativa: Compactación transaccional de revisiones
CREATE OR REPLACE FUNCTION public.compact_catalog_changes(p_keep_revisions bigint)
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_latest bigint;
  v_new_min bigint;
BEGIN
  SELECT latest_revision INTO v_latest FROM public.catalog_sync_metadata WHERE id = 1;
  IF v_latest IS NULL OR v_latest = 0 THEN
    RETURN 1;
  END IF;

  v_new_min := GREATEST(1, v_latest - p_keep_revisions);

  DELETE FROM public.catalog_changes WHERE revision < v_new_min;

  UPDATE public.catalog_sync_metadata
  SET minimum_available_revision = v_new_min,
      updated_at = now()
  WHERE id = 1;

  RETURN v_new_min;
END;
$$;
ALTER FUNCTION public.compact_catalog_changes(bigint) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.compact_catalog_changes(bigint) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.compact_catalog_changes(bigint) FROM anon;
REVOKE ALL ON FUNCTION public.compact_catalog_changes(bigint) FROM authenticated;

-- 3. Triggers Anti-Filtración en titles
CREATE OR REPLACE FUNCTION public.fn_catalog_changes_titles()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    IF NEW.is_published = true AND NEW.deleted_at IS NULL THEN
      INSERT INTO public.catalog_changes (entity_type, entity_id, operation, changed_at)
      VALUES ('title', NEW.id::text, 'upsert', now());
    END IF;
    RETURN NEW;
  ELSIF TG_OP = 'UPDATE' THEN
    IF (OLD.is_published = false OR OLD.deleted_at IS NOT NULL) AND (NEW.is_published = true AND NEW.deleted_at IS NULL) THEN
      INSERT INTO public.catalog_changes (entity_type, entity_id, operation, changed_at)
      VALUES ('title', NEW.id::text, 'upsert', now());

      INSERT INTO public.catalog_changes (entity_type, entity_id, operation, changed_at)
      SELECT 'season', s.id::text, 'upsert', now()
      FROM public.seasons s
      WHERE s.title_id = NEW.id AND s.deleted_at IS NULL;

      INSERT INTO public.catalog_changes (entity_type, entity_id, operation, changed_at)
      SELECT 'episode', e.id::text, 'upsert', now()
      FROM public.episodes e
      JOIN public.seasons s ON s.id = e.season_id
      WHERE s.title_id = NEW.id AND e.deleted_at IS NULL;

      INSERT INTO public.catalog_changes (entity_type, entity_id, operation, changed_at)
      SELECT 'source', src.id::text, 'upsert', now()
      FROM public.sources src
      WHERE src.title_id = NEW.id AND src.deleted_at IS NULL;

      INSERT INTO public.catalog_changes (entity_type, entity_id, operation, changed_at)
      SELECT 'source', src.id::text, 'upsert', now()
      FROM public.sources src
      JOIN public.episodes e ON e.id = src.episode_id
      JOIN public.seasons s ON s.id = e.season_id
      WHERE s.title_id = NEW.id AND src.deleted_at IS NULL;

      INSERT INTO public.catalog_changes (entity_type, entity_id, operation, changed_at)
      SELECT 'title_genre', tg.title_id::text || ':' || tg.genre_id::text, 'upsert', now()
      FROM public.title_genres tg
      WHERE tg.title_id = NEW.id;

    ELSIF (OLD.is_published = true AND OLD.deleted_at IS NULL) AND (NEW.is_published = true AND NEW.deleted_at IS NULL) THEN
      INSERT INTO public.catalog_changes (entity_type, entity_id, operation, changed_at)
      VALUES ('title', NEW.id::text, 'upsert', now());

    ELSIF (OLD.is_published = true AND OLD.deleted_at IS NULL) AND (NEW.is_published = false OR NEW.deleted_at IS NOT NULL) THEN
      INSERT INTO public.catalog_changes (entity_type, entity_id, operation, changed_at)
      VALUES ('title', NEW.id::text, 'delete', now());
    END IF;
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    IF OLD.is_published = true AND OLD.deleted_at IS NULL THEN
      INSERT INTO public.catalog_changes (entity_type, entity_id, operation, changed_at)
      VALUES ('title', OLD.id::text, 'delete', now());
    END IF;
    RETURN OLD;
  END IF;
  RETURN NULL;
END;
$$;
ALTER FUNCTION public.fn_catalog_changes_titles() OWNER TO postgres;
REVOKE ALL ON FUNCTION public.fn_catalog_changes_titles() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.fn_catalog_changes_titles() FROM anon;
REVOKE ALL ON FUNCTION public.fn_catalog_changes_titles() FROM authenticated;

DROP TRIGGER IF EXISTS trg_catalog_changes_titles ON public.titles;
CREATE TRIGGER trg_catalog_changes_titles
AFTER INSERT OR UPDATE OR DELETE ON public.titles
FOR EACH ROW
EXECUTE FUNCTION public.fn_catalog_changes_titles();

-- 4. Triggers en seasons
CREATE OR REPLACE FUNCTION public.fn_catalog_changes_seasons()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $$
DECLARE
  v_is_public boolean;
BEGIN
  IF TG_OP = 'INSERT' THEN
    SELECT (t.is_published = true AND t.deleted_at IS NULL) INTO v_is_public
    FROM public.titles t WHERE t.id = NEW.title_id;
    IF v_is_public = true AND NEW.deleted_at IS NULL THEN
      INSERT INTO public.catalog_changes (entity_type, entity_id, operation, changed_at)
      VALUES ('season', NEW.id::text, 'upsert', now());
    END IF;
    RETURN NEW;
  ELSIF TG_OP = 'UPDATE' THEN
    SELECT (t.is_published = true AND t.deleted_at IS NULL) INTO v_is_public
    FROM public.titles t WHERE t.id = NEW.title_id;
    IF v_is_public = true THEN
      IF NEW.deleted_at IS NOT NULL AND OLD.deleted_at IS NULL THEN
        INSERT INTO public.catalog_changes (entity_type, entity_id, operation, changed_at)
        VALUES ('season', NEW.id::text, 'delete', now());
      ELSIF NEW.deleted_at IS NULL THEN
        INSERT INTO public.catalog_changes (entity_type, entity_id, operation, changed_at)
        VALUES ('season', NEW.id::text, 'upsert', now());
      END IF;
    END IF;
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    SELECT (t.is_published = true AND t.deleted_at IS NULL) INTO v_is_public
    FROM public.titles t WHERE t.id = OLD.title_id;
    IF v_is_public = true AND OLD.deleted_at IS NULL THEN
      INSERT INTO public.catalog_changes (entity_type, entity_id, operation, changed_at)
      VALUES ('season', OLD.id::text, 'delete', now());
    END IF;
    RETURN OLD;
  END IF;
  RETURN NULL;
END;
$$;
ALTER FUNCTION public.fn_catalog_changes_seasons() OWNER TO postgres;
REVOKE ALL ON FUNCTION public.fn_catalog_changes_seasons() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.fn_catalog_changes_seasons() FROM anon;
REVOKE ALL ON FUNCTION public.fn_catalog_changes_seasons() FROM authenticated;

DROP TRIGGER IF EXISTS trg_catalog_changes_seasons ON public.seasons;
CREATE TRIGGER trg_catalog_changes_seasons
AFTER INSERT OR UPDATE OR DELETE ON public.seasons
FOR EACH ROW
EXECUTE FUNCTION public.fn_catalog_changes_seasons();

-- 5. Triggers en episodes
CREATE OR REPLACE FUNCTION public.fn_catalog_changes_episodes()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $$
DECLARE
  v_is_public boolean;
BEGIN
  IF TG_OP = 'INSERT' THEN
    SELECT (t.is_published = true AND t.deleted_at IS NULL AND s.deleted_at IS NULL) INTO v_is_public
    FROM public.seasons s
    JOIN public.titles t ON t.id = s.title_id
    WHERE s.id = NEW.season_id;
    IF v_is_public = true AND NEW.deleted_at IS NULL THEN
      INSERT INTO public.catalog_changes (entity_type, entity_id, operation, changed_at)
      VALUES ('episode', NEW.id::text, 'upsert', now());
    END IF;
    RETURN NEW;
  ELSIF TG_OP = 'UPDATE' THEN
    SELECT (t.is_published = true AND t.deleted_at IS NULL AND s.deleted_at IS NULL) INTO v_is_public
    FROM public.seasons s
    JOIN public.titles t ON t.id = s.title_id
    WHERE s.id = NEW.season_id;
    IF v_is_public = true THEN
      IF NEW.deleted_at IS NOT NULL AND OLD.deleted_at IS NULL THEN
        INSERT INTO public.catalog_changes (entity_type, entity_id, operation, changed_at)
        VALUES ('episode', NEW.id::text, 'delete', now());
      ELSIF NEW.deleted_at IS NULL THEN
        INSERT INTO public.catalog_changes (entity_type, entity_id, operation, changed_at)
        VALUES ('episode', NEW.id::text, 'upsert', now());
      END IF;
    END IF;
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    SELECT (t.is_published = true AND t.deleted_at IS NULL AND s.deleted_at IS NULL) INTO v_is_public
    FROM public.seasons s
    JOIN public.titles t ON t.id = s.title_id
    WHERE s.id = OLD.season_id;
    IF v_is_public = true AND OLD.deleted_at IS NULL THEN
      INSERT INTO public.catalog_changes (entity_type, entity_id, operation, changed_at)
      VALUES ('episode', OLD.id::text, 'delete', now());
    END IF;
    RETURN OLD;
  END IF;
  RETURN NULL;
END;
$$;
ALTER FUNCTION public.fn_catalog_changes_episodes() OWNER TO postgres;
REVOKE ALL ON FUNCTION public.fn_catalog_changes_episodes() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.fn_catalog_changes_episodes() FROM anon;
REVOKE ALL ON FUNCTION public.fn_catalog_changes_episodes() FROM authenticated;

DROP TRIGGER IF EXISTS trg_catalog_changes_episodes ON public.episodes;
CREATE TRIGGER trg_catalog_changes_episodes
AFTER INSERT OR UPDATE OR DELETE ON public.episodes
FOR EACH ROW
EXECUTE FUNCTION public.fn_catalog_changes_episodes();

-- 6. Triggers en sources
CREATE OR REPLACE FUNCTION public.fn_catalog_changes_sources()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $$
DECLARE
  v_is_public boolean := false;
BEGIN
  IF TG_OP = 'INSERT' THEN
    IF NEW.title_id IS NOT NULL THEN
      SELECT (t.is_published = true AND t.deleted_at IS NULL) INTO v_is_public
      FROM public.titles t WHERE t.id = NEW.title_id;
    ELSIF NEW.episode_id IS NOT NULL THEN
      SELECT (t.is_published = true AND t.deleted_at IS NULL AND s.deleted_at IS NULL AND e.deleted_at IS NULL) INTO v_is_public
      FROM public.episodes e
      JOIN public.seasons s ON s.id = e.season_id
      JOIN public.titles t ON t.id = s.title_id
      WHERE e.id = NEW.episode_id;
    END IF;
    IF v_is_public = true AND NEW.deleted_at IS NULL THEN
      INSERT INTO public.catalog_changes (entity_type, entity_id, operation, changed_at)
      VALUES ('source', NEW.id::text, 'upsert', now());
    END IF;
    RETURN NEW;
  ELSIF TG_OP = 'UPDATE' THEN
    IF NEW.title_id IS NOT NULL THEN
      SELECT (t.is_published = true AND t.deleted_at IS NULL) INTO v_is_public
      FROM public.titles t WHERE t.id = NEW.title_id;
    ELSIF NEW.episode_id IS NOT NULL THEN
      SELECT (t.is_published = true AND t.deleted_at IS NULL AND s.deleted_at IS NULL AND e.deleted_at IS NULL) INTO v_is_public
      FROM public.episodes e
      JOIN public.seasons s ON s.id = e.season_id
      JOIN public.titles t ON t.id = s.title_id
      WHERE e.id = NEW.episode_id;
    END IF;
    IF v_is_public = true THEN
      IF NEW.deleted_at IS NOT NULL AND OLD.deleted_at IS NULL THEN
        INSERT INTO public.catalog_changes (entity_type, entity_id, operation, changed_at)
        VALUES ('source', NEW.id::text, 'delete', now());
      ELSIF NEW.deleted_at IS NULL THEN
        INSERT INTO public.catalog_changes (entity_type, entity_id, operation, changed_at)
        VALUES ('source', NEW.id::text, 'upsert', now());
      END IF;
    END IF;
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    IF OLD.title_id IS NOT NULL THEN
      SELECT (t.is_published = true AND t.deleted_at IS NULL) INTO v_is_public
      FROM public.titles t WHERE t.id = OLD.title_id;
    ELSIF OLD.episode_id IS NOT NULL THEN
      SELECT (t.is_published = true AND t.deleted_at IS NULL AND s.deleted_at IS NULL AND e.deleted_at IS NULL) INTO v_is_public
      FROM public.episodes e
      JOIN public.seasons s ON s.id = e.season_id
      JOIN public.titles t ON t.id = s.title_id
      WHERE e.id = OLD.episode_id;
    END IF;
    IF v_is_public = true AND OLD.deleted_at IS NULL THEN
      INSERT INTO public.catalog_changes (entity_type, entity_id, operation, changed_at)
      VALUES ('source', OLD.id::text, 'delete', now());
    END IF;
    RETURN OLD;
  END IF;
  RETURN NULL;
END;
$$;
ALTER FUNCTION public.fn_catalog_changes_sources() OWNER TO postgres;
REVOKE ALL ON FUNCTION public.fn_catalog_changes_sources() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.fn_catalog_changes_sources() FROM anon;
REVOKE ALL ON FUNCTION public.fn_catalog_changes_sources() FROM authenticated;

DROP TRIGGER IF EXISTS trg_catalog_changes_sources ON public.sources;
CREATE TRIGGER trg_catalog_changes_sources
AFTER INSERT OR UPDATE OR DELETE ON public.sources
FOR EACH ROW
EXECUTE FUNCTION public.fn_catalog_changes_sources();

-- 7. Triggers en title_genres
CREATE OR REPLACE FUNCTION public.fn_catalog_changes_title_genres()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $$
DECLARE
  v_is_public boolean;
BEGIN
  IF TG_OP = 'INSERT' THEN
    SELECT (t.is_published = true AND t.deleted_at IS NULL) INTO v_is_public
    FROM public.titles t WHERE t.id = NEW.title_id;
    IF v_is_public = true THEN
      INSERT INTO public.catalog_changes (entity_type, entity_id, operation, changed_at)
      VALUES ('title_genre', NEW.title_id::text || ':' || NEW.genre_id::text, 'upsert', now());
    END IF;
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    SELECT (t.is_published = true AND t.deleted_at IS NULL) INTO v_is_public
    FROM public.titles t WHERE t.id = OLD.title_id;
    IF v_is_public = true THEN
      INSERT INTO public.catalog_changes (entity_type, entity_id, operation, changed_at)
      VALUES ('title_genre', OLD.title_id::text || ':' || OLD.genre_id::text, 'delete', now());
    END IF;
    RETURN OLD;
  END IF;
  RETURN NULL;
END;
$$;
ALTER FUNCTION public.fn_catalog_changes_title_genres() OWNER TO postgres;
REVOKE ALL ON FUNCTION public.fn_catalog_changes_title_genres() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.fn_catalog_changes_title_genres() FROM anon;
REVOKE ALL ON FUNCTION public.fn_catalog_changes_title_genres() FROM authenticated;

DROP TRIGGER IF EXISTS trg_catalog_changes_title_genres ON public.title_genres;
CREATE TRIGGER trg_catalog_changes_title_genres
AFTER INSERT OR DELETE ON public.title_genres
FOR EACH ROW
EXECUTE FUNCTION public.fn_catalog_changes_title_genres();

-- 8. Triggers en genres
CREATE OR REPLACE FUNCTION public.fn_catalog_changes_genres()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
  IF TG_OP = 'INSERT' OR TG_OP = 'UPDATE' THEN
    INSERT INTO public.catalog_changes (entity_type, entity_id, operation, changed_at)
    VALUES ('genre', NEW.id::text, 'upsert', now());
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    INSERT INTO public.catalog_changes (entity_type, entity_id, operation, changed_at)
    VALUES ('genre', OLD.id::text, 'delete', now());
    RETURN OLD;
  END IF;
  RETURN NULL;
END;
$$;
ALTER FUNCTION public.fn_catalog_changes_genres() OWNER TO postgres;
REVOKE ALL ON FUNCTION public.fn_catalog_changes_genres() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.fn_catalog_changes_genres() FROM anon;
REVOKE ALL ON FUNCTION public.fn_catalog_changes_genres() FROM authenticated;

DROP TRIGGER IF EXISTS trg_catalog_changes_genres ON public.genres;
CREATE TRIGGER trg_catalog_changes_genres
AFTER INSERT OR UPDATE OR DELETE ON public.genres
FOR EACH ROW
EXECUTE FUNCTION public.fn_catalog_changes_genres();

-- 9. Triggers en languages
CREATE OR REPLACE FUNCTION public.fn_catalog_changes_languages()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
  IF TG_OP = 'INSERT' OR TG_OP = 'UPDATE' THEN
    INSERT INTO public.catalog_changes (entity_type, entity_id, operation, changed_at)
    VALUES ('language', NEW.id::text, 'upsert', now());
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    INSERT INTO public.catalog_changes (entity_type, entity_id, operation, changed_at)
    VALUES ('language', OLD.id::text, 'delete', now());
    RETURN OLD;
  END IF;
  RETURN NULL;
END;
$$;
ALTER FUNCTION public.fn_catalog_changes_languages() OWNER TO postgres;
REVOKE ALL ON FUNCTION public.fn_catalog_changes_languages() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.fn_catalog_changes_languages() FROM anon;
REVOKE ALL ON FUNCTION public.fn_catalog_changes_languages() FROM authenticated;

DROP TRIGGER IF EXISTS trg_catalog_changes_languages ON public.languages;
CREATE TRIGGER trg_catalog_changes_languages
AFTER INSERT OR UPDATE OR DELETE ON public.languages
FOR EACH ROW
EXECUTE FUNCTION public.fn_catalog_changes_languages();

-- ============================================================================
-- Índices para consultas de alta velocidad y paginación determinista
-- ============================================================================
CREATE UNIQUE INDEX IF NOT EXISTS idx_titles_media_tmdb
ON public.titles (media_type, tmdb_id)
WHERE tmdb_id IS NOT NULL AND deleted_at IS NULL;

CREATE UNIQUE INDEX IF NOT EXISTS idx_titles_imdb
ON public.titles (imdb_id)
WHERE imdb_id IS NOT NULL AND deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_titles_cursor_comp
ON public.titles (created_at DESC, id DESC)
WHERE is_published = true AND deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_titles_cursor_year
ON public.titles (year DESC, id DESC)
WHERE is_published = true AND deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_titles_type_cursor
ON public.titles (media_type, created_at DESC, id DESC)
WHERE is_published = true AND deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_titles_featured
ON public.titles (created_at DESC)
WHERE is_featured = true AND is_published = true AND deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_titles_search_trgm
ON public.titles USING gin (normalized_title extensions.gin_trgm_ops)
WHERE is_published = true AND deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_title_genres_lookup
ON public.title_genres (genre_id, title_id);

CREATE INDEX IF NOT EXISTS idx_episodes_lookup
ON public.episodes (season_id, episode_number);

CREATE INDEX IF NOT EXISTS idx_sources_title
ON public.sources (title_id, order_index ASC);

CREATE INDEX IF NOT EXISTS idx_sources_episode
ON public.sources (episode_id, order_index ASC);

-- ============================================================================
-- Vista Segura de Resúmenes de Tarjetas
-- ============================================================================
CREATE OR REPLACE VIEW public.title_summaries
WITH (security_invoker = true)
AS
SELECT
  t.id,
  t.legacy_id,
  t.media_type,
  t.title,
  t.original_title,
  t.normalized_title,
  t.plot,
  t.year,
  t.release_date,
  t.rating,
  t.poster_url,
  t.backdrop_url,
  t.is_featured,
  t.is_published,
  t.created_at,
  t.updated_at,
  t.deleted_at,
  COALESCE(
    (
      SELECT json_agg(json_build_object('id', g.id, 'name', g.name, 'slug', g.slug))
      FROM public.title_genres tg
      JOIN public.genres g ON g.id = tg.genre_id
      WHERE tg.title_id = t.id
    ),
    '[]'::json
  ) AS genres
FROM public.titles t
WHERE t.is_published = true AND t.deleted_at IS NULL;

-- ============================================================================
-- Revocación de Privilegios y Políticas RLS
-- ============================================================================
REVOKE ALL ON
  public.titles,
  public.genres,
  public.title_genres,
  public.seasons,
  public.episodes,
  public.languages,
  public.sources,
  public.catalog_changes,
  public.catalog_sync_metadata,
  public.title_summaries
FROM PUBLIC, anon, authenticated;

GRANT SELECT ON
  public.titles,
  public.genres,
  public.title_genres,
  public.seasons,
  public.episodes,
  public.languages,
  public.sources,
  public.catalog_changes,
  public.catalog_sync_metadata,
  public.title_summaries
TO anon, authenticated;

ALTER TABLE public.titles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.genres ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.title_genres ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.seasons ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.episodes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.languages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sources ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.catalog_changes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.catalog_sync_metadata ENABLE ROW LEVEL SECURITY;

-- Políticas SELECT
DROP POLICY IF EXISTS p_titles_select_public ON public.titles;
CREATE POLICY p_titles_select_public ON public.titles
FOR SELECT TO anon, authenticated
USING (is_published = true AND deleted_at IS NULL);

DROP POLICY IF EXISTS p_genres_select_public ON public.genres;
CREATE POLICY p_genres_select_public ON public.genres
FOR SELECT TO anon, authenticated
USING (true);

DROP POLICY IF EXISTS p_languages_select_public ON public.languages;
CREATE POLICY p_languages_select_public ON public.languages
FOR SELECT TO anon, authenticated
USING (true);

DROP POLICY IF EXISTS p_seasons_select_public ON public.seasons;
CREATE POLICY p_seasons_select_public ON public.seasons
FOR SELECT TO anon, authenticated
USING (
  deleted_at IS NULL AND
  EXISTS (
    SELECT 1 FROM public.titles t
    WHERE t.id = seasons.title_id AND t.is_published = true AND t.deleted_at IS NULL
  )
);

DROP POLICY IF EXISTS p_episodes_select_public ON public.episodes;
CREATE POLICY p_episodes_select_public ON public.episodes
FOR SELECT TO anon, authenticated
USING (
  deleted_at IS NULL AND
  EXISTS (
    SELECT 1 FROM public.seasons s
    JOIN public.titles t ON t.id = s.title_id
    WHERE s.id = episodes.season_id
      AND s.deleted_at IS NULL
      AND t.is_published = true
      AND t.deleted_at IS NULL
  )
);

DROP POLICY IF EXISTS p_sources_select_public ON public.sources;
CREATE POLICY p_sources_select_public ON public.sources
FOR SELECT TO anon, authenticated
USING (
  deleted_at IS NULL AND (
    (title_id IS NOT NULL AND EXISTS (
      SELECT 1 FROM public.titles t
      WHERE t.id = sources.title_id AND t.is_published = true AND t.deleted_at IS NULL
    ))
    OR
    (episode_id IS NOT NULL AND EXISTS (
      SELECT 1 FROM public.episodes e
      JOIN public.seasons s ON s.id = e.season_id
      JOIN public.titles t ON t.id = s.title_id
      WHERE e.id = sources.episode_id
        AND e.deleted_at IS NULL
        AND s.deleted_at IS NULL
        AND t.is_published = true
        AND t.deleted_at IS NULL
    ))
  )
);

DROP POLICY IF EXISTS p_title_genres_select_public ON public.title_genres;
CREATE POLICY p_title_genres_select_public ON public.title_genres
FOR SELECT TO anon, authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.titles t
    WHERE t.id = title_genres.title_id AND t.is_published = true AND t.deleted_at IS NULL
  )
);

DROP POLICY IF EXISTS p_catalog_changes_select_public ON public.catalog_changes;
CREATE POLICY p_catalog_changes_select_public ON public.catalog_changes
FOR SELECT TO anon, authenticated
USING (true);

DROP POLICY IF EXISTS p_catalog_sync_metadata_select_public ON public.catalog_sync_metadata;
CREATE POLICY p_catalog_sync_metadata_select_public ON public.catalog_sync_metadata
FOR SELECT TO anon, authenticated
USING (true);
