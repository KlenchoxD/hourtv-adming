-- Migración de Fase 4: Esquema de Sincronización de Perfiles y Recomendaciones
-- Generada con: npx -y supabase migration new create_profile_sync_schema

-- 1. Atributo infantil estructurado en catálogo
ALTER TABLE public.titles ADD COLUMN IF NOT EXISTS is_kids_safe boolean NOT NULL DEFAULT false;
CREATE INDEX IF NOT EXISTS idx_titles_kids_safe ON public.titles(is_kids_safe) WHERE is_kids_safe = true;

-- 2. Clave única compuesta en perfiles para FK compuesta a prueba de suplantación
DO $$ BEGIN
  ALTER TABLE public.account_profiles ADD CONSTRAINT account_profiles_id_owner_id_key UNIQUE (id, owner_id);
EXCEPTION
  WHEN duplicate_table OR duplicate_object THEN null;
END $$;

-- 3. Tablas de sincronización de usuario con FK compuesta (profile_id, owner_id)

-- 3.1. Metadatos de sincronización
CREATE TABLE IF NOT EXISTS public.profile_sync_metadata (
  profile_id uuid PRIMARY KEY,
  owner_id uuid NOT NULL,
  latest_revision bigint NOT NULL DEFAULT 0,
  minimum_available_revision bigint NOT NULL DEFAULT 0,
  updated_at timestamptz NOT NULL DEFAULT now(),
  FOREIGN KEY (profile_id, owner_id) REFERENCES public.account_profiles(id, owner_id) ON DELETE CASCADE
);

-- 3.2. Ledger inmutable de operaciones
CREATE TABLE IF NOT EXISTS public.profile_operations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id uuid NOT NULL,
  profile_id uuid NOT NULL,
  operation_id uuid NOT NULL UNIQUE,
  device_id text NOT NULL CHECK (length(device_id) BETWEEN 1 AND 128),
  client_sequence bigint NOT NULL CHECK (client_sequence > 0),
  playback_session_id uuid,
  operation_type text NOT NULL CHECK (operation_type IN ('favorite_add', 'favorite_remove', 'progress_update', 'mark_completed', 'restart', 'history_append', 'preferences_update')),
  apply_status text NOT NULL CHECK (apply_status IN ('applied', 'ignored_stale')),
  content_key text NOT NULL CHECK (length(content_key) BETWEEN 1 AND 255),
  title_id uuid REFERENCES public.titles(id) ON DELETE SET NULL,
  episode_id uuid REFERENCES public.episodes(id) ON DELETE SET NULL,
  payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  server_revision bigint NOT NULL,
  server_received_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  client_timestamp timestamptz,
  UNIQUE (profile_id, device_id, client_sequence),
  FOREIGN KEY (profile_id, owner_id) REFERENCES public.account_profiles(id, owner_id) ON DELETE CASCADE,
  CHECK ((episode_id IS NULL) OR (title_id IS NOT NULL))
);

-- 3.3. Favoritos materializados
CREATE TABLE IF NOT EXISTS public.profile_favorites (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id uuid NOT NULL,
  profile_id uuid NOT NULL,
  content_key text NOT NULL,
  title_id uuid REFERENCES public.titles(id) ON DELETE SET NULL,
  is_favorite boolean NOT NULL DEFAULT true,
  server_revision bigint NOT NULL,
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz,
  UNIQUE (profile_id, content_key),
  FOREIGN KEY (profile_id, owner_id) REFERENCES public.account_profiles(id, owner_id) ON DELETE CASCADE
);

-- 3.4. Progreso de reproducción materializado
CREATE TABLE IF NOT EXISTS public.profile_playback_progress (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id uuid NOT NULL,
  profile_id uuid NOT NULL,
  content_key text NOT NULL,
  playback_session_id uuid NOT NULL,
  title_id uuid REFERENCES public.titles(id) ON DELETE SET NULL,
  episode_id uuid REFERENCES public.episodes(id) ON DELETE SET NULL,
  position_ms bigint NOT NULL DEFAULT 0 CHECK (position_ms >= 0),
  duration_ms bigint NOT NULL DEFAULT 0 CHECK (duration_ms >= 0),
  fraction double precision NOT NULL DEFAULT 0.0 CHECK (fraction >= 0.0 AND fraction <= 1.0),
  is_completed boolean NOT NULL DEFAULT false,
  last_watched_at timestamptz NOT NULL DEFAULT now(),
  server_revision bigint NOT NULL,
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz,
  UNIQUE (profile_id, content_key),
  FOREIGN KEY (profile_id, owner_id) REFERENCES public.account_profiles(id, owner_id) ON DELETE CASCADE,
  CHECK ((episode_id IS NULL) OR (title_id IS NOT NULL))
);

-- 3.5. Historial de sesiones acotado a 500
CREATE TABLE IF NOT EXISTS public.profile_history (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id uuid NOT NULL,
  profile_id uuid NOT NULL,
  operation_id uuid NOT NULL UNIQUE,
  content_key text NOT NULL,
  playback_session_id uuid NOT NULL,
  title_id uuid REFERENCES public.titles(id) ON DELETE SET NULL,
  episode_id uuid REFERENCES public.episodes(id) ON DELETE SET NULL,
  position_ms bigint NOT NULL DEFAULT 0 CHECK (position_ms >= 0),
  duration_ms bigint NOT NULL DEFAULT 0 CHECK (duration_ms >= 0),
  server_revision bigint NOT NULL,
  server_received_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  watched_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  client_timestamp timestamptz,
  FOREIGN KEY (profile_id, owner_id) REFERENCES public.account_profiles(id, owner_id) ON DELETE CASCADE,
  CHECK ((episode_id IS NULL) OR (title_id IS NOT NULL))
);

-- 3.6. Preferencias de reproducción del perfil
CREATE TABLE IF NOT EXISTS public.profile_preferences (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id uuid NOT NULL,
  profile_id uuid NOT NULL,
  preferred_audio_language text CHECK (preferred_audio_language IS NULL OR length(preferred_audio_language) <= 16),
  preferred_subtitle_language text CHECK (preferred_subtitle_language IS NULL OR length(preferred_subtitle_language) <= 16),
  subtitles_enabled boolean NOT NULL DEFAULT false,
  preferred_quality text CHECK (preferred_quality IS NULL OR length(preferred_quality) <= 32),
  server_revision bigint NOT NULL,
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (profile_id),
  FOREIGN KEY (profile_id, owner_id) REFERENCES public.account_profiles(id, owner_id) ON DELETE CASCADE
);

-- 3.7. Auditoría de importación del modo Invitado
CREATE TABLE IF NOT EXISTS public.guest_import_audit (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id uuid NOT NULL,
  target_profile_id uuid NOT NULL,
  import_batch_id uuid NOT NULL,
  status text NOT NULL CHECK (status IN ('in_progress', 'completed', 'failed')),
  favorites_count int NOT NULL DEFAULT 0 CHECK (favorites_count >= 0 AND favorites_count <= 10000),
  progress_count int NOT NULL DEFAULT 0 CHECK (progress_count >= 0 AND progress_count <= 10000),
  history_count int NOT NULL DEFAULT 0 CHECK (history_count >= 0 AND history_count <= 10000),
  error_message text CHECK (error_message IS NULL OR length(error_message) <= 500),
  created_at timestamptz NOT NULL DEFAULT now(),
  completed_at timestamptz,
  UNIQUE (target_profile_id, import_batch_id),
  FOREIGN KEY (target_profile_id, owner_id) REFERENCES public.account_profiles(id, owner_id) ON DELETE CASCADE
);

-- 4. Índices para Keyset Paging, RLS y Foreign Keys
CREATE INDEX IF NOT EXISTS idx_profile_operations_stream ON public.profile_operations (profile_id, server_revision ASC);
CREATE INDEX IF NOT EXISTS idx_profile_operations_owner ON public.profile_operations (owner_id);
CREATE INDEX IF NOT EXISTS idx_profile_history_timeline ON public.profile_history (profile_id, server_received_at DESC, server_revision DESC, id DESC);
CREATE INDEX IF NOT EXISTS idx_profile_history_owner ON public.profile_history (owner_id);
CREATE INDEX IF NOT EXISTS idx_profile_progress_lookup ON public.profile_playback_progress (profile_id, content_key);
CREATE INDEX IF NOT EXISTS idx_profile_progress_owner ON public.profile_playback_progress (owner_id);
CREATE INDEX IF NOT EXISTS idx_profile_favorites_lookup ON public.profile_favorites (profile_id, content_key);
CREATE INDEX IF NOT EXISTS idx_profile_favorites_owner ON public.profile_favorites (owner_id);
CREATE INDEX IF NOT EXISTS idx_profile_preferences_owner ON public.profile_preferences (owner_id);
CREATE INDEX IF NOT EXISTS idx_guest_import_audit_owner ON public.guest_import_audit (owner_id);
CREATE INDEX IF NOT EXISTS idx_profile_sync_metadata_owner ON public.profile_sync_metadata (owner_id);

-- 5. Row Level Security y Privilegios
ALTER TABLE public.profile_sync_metadata ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profile_operations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profile_favorites ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profile_playback_progress ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profile_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profile_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.guest_import_audit ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.profile_sync_metadata FROM PUBLIC, anon, authenticated;
REVOKE ALL ON TABLE public.profile_operations FROM PUBLIC, anon, authenticated;
REVOKE ALL ON TABLE public.profile_favorites FROM PUBLIC, anon, authenticated;
REVOKE ALL ON TABLE public.profile_playback_progress FROM PUBLIC, anon, authenticated;
REVOKE ALL ON TABLE public.profile_history FROM PUBLIC, anon, authenticated;
REVOKE ALL ON TABLE public.profile_preferences FROM PUBLIC, anon, authenticated;
REVOKE ALL ON TABLE public.guest_import_audit FROM PUBLIC, anon, authenticated;

GRANT SELECT ON TABLE public.profile_sync_metadata TO authenticated;
GRANT SELECT ON TABLE public.profile_operations TO authenticated;
GRANT SELECT ON TABLE public.profile_favorites TO authenticated;
GRANT SELECT ON TABLE public.profile_playback_progress TO authenticated;
GRANT SELECT ON TABLE public.profile_history TO authenticated;
GRANT SELECT ON TABLE public.profile_preferences TO authenticated;
GRANT SELECT ON TABLE public.guest_import_audit TO authenticated;

GRANT ALL ON TABLE public.profile_sync_metadata TO service_role;
GRANT ALL ON TABLE public.profile_operations TO service_role;
GRANT ALL ON TABLE public.profile_favorites TO service_role;
GRANT ALL ON TABLE public.profile_playback_progress TO service_role;
GRANT ALL ON TABLE public.profile_history TO service_role;
GRANT ALL ON TABLE public.profile_preferences TO service_role;
GRANT ALL ON TABLE public.guest_import_audit TO service_role;

DROP POLICY IF EXISTS profile_sync_metadata_select ON public.profile_sync_metadata;
CREATE POLICY profile_sync_metadata_select ON public.profile_sync_metadata
  FOR SELECT TO authenticated
  USING ((SELECT auth.uid()) IS NOT NULL AND owner_id = (SELECT auth.uid()));

DROP POLICY IF EXISTS profile_operations_select ON public.profile_operations;
CREATE POLICY profile_operations_select ON public.profile_operations
  FOR SELECT TO authenticated
  USING ((SELECT auth.uid()) IS NOT NULL AND owner_id = (SELECT auth.uid()));

DROP POLICY IF EXISTS profile_favorites_select ON public.profile_favorites;
CREATE POLICY profile_favorites_select ON public.profile_favorites
  FOR SELECT TO authenticated
  USING ((SELECT auth.uid()) IS NOT NULL AND owner_id = (SELECT auth.uid()));

DROP POLICY IF EXISTS profile_playback_progress_select ON public.profile_playback_progress;
CREATE POLICY profile_playback_progress_select ON public.profile_playback_progress
  FOR SELECT TO authenticated
  USING ((SELECT auth.uid()) IS NOT NULL AND owner_id = (SELECT auth.uid()));

DROP POLICY IF EXISTS profile_history_select ON public.profile_history;
CREATE POLICY profile_history_select ON public.profile_history
  FOR SELECT TO authenticated
  USING ((SELECT auth.uid()) IS NOT NULL AND owner_id = (SELECT auth.uid()));

DROP POLICY IF EXISTS profile_preferences_select ON public.profile_preferences;
CREATE POLICY profile_preferences_select ON public.profile_preferences
  FOR SELECT TO authenticated
  USING ((SELECT auth.uid()) IS NOT NULL AND owner_id = (SELECT auth.uid()));

DROP POLICY IF EXISTS guest_import_audit_select ON public.guest_import_audit;
CREATE POLICY guest_import_audit_select ON public.guest_import_audit
  FOR SELECT TO authenticated
  USING ((SELECT auth.uid()) IS NOT NULL AND owner_id = (SELECT auth.uid()));

-- 6. Funciones Privadas

-- 6.1. Poda privada de historial (máximo 500 registros deterministas)
CREATE OR REPLACE FUNCTION public._prune_profile_history_internal(
  p_profile_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  DELETE FROM public.profile_history
  WHERE profile_id = p_profile_id
    AND id NOT IN (
      SELECT id FROM public.profile_history
      WHERE profile_id = p_profile_id
      ORDER BY server_received_at DESC, server_revision DESC, id DESC
      LIMIT 500
    );
END;
$$;

REVOKE ALL ON FUNCTION public._prune_profile_history_internal(uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public._prune_profile_history_internal(uuid) TO service_role;

-- 7. Funciones Públicas RPCs (SECURITY DEFINER)

-- 7.1. push_profile_operations: Escritura atómica, validación y resolución de sesiones
CREATE OR REPLACE FUNCTION public.push_profile_operations(
  p_profile_id uuid,
  p_operations jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_owner_id uuid;
  v_meta_owner_id uuid;
  v_latest_rev bigint;
  v_min_rev bigint;
  v_op record;
  v_results jsonb := '[]'::jsonb;
  v_op_id uuid;
  v_device_id text;
  v_client_seq bigint;
  v_op_type text;
  v_content_key text;
  v_session_id uuid;
  v_title_id uuid;
  v_episode_id uuid;
  v_payload jsonb;
  v_client_ts timestamptz;
  v_existing_op record;
  v_existing_prog record;
  v_max_seq bigint;
  v_calc_fraction double precision;
  v_now timestamptz;
  v_batch_count int;
  v_apply_status text;
BEGIN
  v_owner_id := (SELECT auth.uid());
  IF v_owner_id IS NULL THEN
    RAISE EXCEPTION 'No autenticado' USING ERRCODE = '28000';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.account_profiles
    WHERE id = p_profile_id AND owner_id = v_owner_id
  ) THEN
    RAISE EXCEPTION 'Perfil no encontrado o acceso no autorizado' USING ERRCODE = '42501';
  END IF;

  IF p_operations IS NULL OR pg_catalog.jsonb_typeof(p_operations) <> 'array' THEN
    RAISE EXCEPTION 'p_operations debe ser un array JSON' USING ERRCODE = '22023';
  END IF;

  IF pg_catalog.pg_column_size(p_operations) > 65536 THEN
    RAISE EXCEPTION 'El lote excede el tamaño máximo de 64KB' USING ERRCODE = '22023';
  END IF;

  v_batch_count := pg_catalog.jsonb_array_length(p_operations);
  IF v_batch_count = 0 THEN
    RETURN '[]'::jsonb;
  ELSIF v_batch_count > 100 THEN
    RAISE EXCEPTION 'El lote excede el límite de 100 operaciones' USING ERRCODE = '22023';
  END IF;

  -- Inserción atómica y bloqueo pesimista contra carreras iniciales
  INSERT INTO public.profile_sync_metadata (profile_id, owner_id, latest_revision, minimum_available_revision, updated_at)
  VALUES (p_profile_id, v_owner_id, 0, 0, pg_catalog.clock_timestamp())
  ON CONFLICT (profile_id) DO NOTHING;

  SELECT latest_revision, minimum_available_revision, owner_id
  INTO v_latest_rev, v_min_rev, v_meta_owner_id
  FROM public.profile_sync_metadata
  WHERE profile_id = p_profile_id
  FOR UPDATE;

  IF v_meta_owner_id <> v_owner_id THEN
    RAISE EXCEPTION 'Inconsistencia de propiedad en metadatos' USING ERRCODE = '42501';
  END IF;

  FOR v_op IN SELECT * FROM pg_catalog.jsonb_to_recordset(p_operations) AS x(
    operation_id uuid,
    device_id text,
    client_sequence bigint,
    playback_session_id uuid,
    operation_type text,
    content_key text,
    title_id uuid,
    episode_id uuid,
    payload jsonb,
    client_timestamp timestamptz
  ) LOOP
    v_op_id := v_op.operation_id;
    v_device_id := trim(COALESCE(v_op.device_id, ''));
    v_client_seq := v_op.client_sequence;
    v_session_id := v_op.playback_session_id;
    v_op_type := v_op.operation_type;
    v_content_key := trim(COALESCE(v_op.content_key, ''));
    v_title_id := v_op.title_id;
    v_episode_id := v_op.episode_id;
    v_payload := v_op.payload;
    v_client_ts := v_op.client_timestamp;
    v_now := pg_catalog.clock_timestamp();
    v_apply_status := 'applied';

    IF v_op_id IS NULL THEN
      RAISE EXCEPTION 'operation_id es obligatorio' USING ERRCODE = '22023';
    END IF;

    IF length(v_device_id) = 0 OR length(v_device_id) > 128 THEN
      RAISE EXCEPTION 'device_id inválido' USING ERRCODE = '22023';
    END IF;

    IF v_client_seq IS NULL OR v_client_seq <= 0 THEN
      RAISE EXCEPTION 'client_sequence debe ser un entero positivo' USING ERRCODE = '22023';
    END IF;

    IF length(v_content_key) = 0 OR length(v_content_key) > 255 THEN
      RAISE EXCEPTION 'content_key inválido' USING ERRCODE = '22023';
    END IF;

    IF v_op_type IS NULL OR v_op_type NOT IN ('favorite_add', 'favorite_remove', 'progress_update', 'mark_completed', 'restart', 'history_append', 'preferences_update') THEN
      RAISE EXCEPTION 'operation_type inválido o nulo' USING ERRCODE = '22023';
    END IF;

    IF v_payload IS NULL OR pg_catalog.jsonb_typeof(v_payload) <> 'object' THEN
      RAISE EXCEPTION 'payload debe ser un objeto JSON' USING ERRCODE = '22023';
    END IF;

    IF pg_catalog.pg_column_size(v_payload) > 16384 THEN
      RAISE EXCEPTION 'Payload excede el límite de 16KB' USING ERRCODE = '22023';
    END IF;

    IF v_op_type IN ('progress_update', 'mark_completed', 'restart', 'history_append') AND v_session_id IS NULL THEN
      RAISE EXCEPTION 'playback_session_id obligatorio para %', v_op_type USING ERRCODE = '22023';
    END IF;

    -- Validar relación entre episode_id y title_id consultando el catálogo
    IF v_episode_id IS NOT NULL THEN
      IF v_title_id IS NULL THEN
        RAISE EXCEPTION 'episode_id requiere title_id' USING ERRCODE = '22023';
      END IF;
      IF NOT EXISTS (
        SELECT 1 FROM public.episodes e
        JOIN public.seasons s ON e.season_id = s.id
        WHERE e.id = v_episode_id AND s.title_id = v_title_id
      ) THEN
        RAISE EXCEPTION 'El episodio % no pertenece al título %', v_episode_id, v_title_id USING ERRCODE = '22023';
      END IF;
    END IF;

    -- A. Idempotencia profunda de operation_id
    SELECT profile_id, device_id, client_sequence, operation_type, content_key, playback_session_id, title_id, episode_id, payload, server_revision, apply_status
    INTO v_existing_op
    FROM public.profile_operations
    WHERE operation_id = v_op_id;

    IF FOUND THEN
      IF v_existing_op.profile_id <> p_profile_id THEN
        RAISE EXCEPTION 'Perfil no autorizado' USING ERRCODE = '42501';
      END IF;

      IF v_existing_op.device_id = v_device_id
         AND v_existing_op.client_sequence = v_client_seq
         AND v_existing_op.operation_type = v_op_type
         AND v_existing_op.content_key = v_content_key
         AND (v_existing_op.playback_session_id IS NOT DISTINCT FROM v_session_id)
         AND (v_existing_op.title_id IS NOT DISTINCT FROM v_title_id)
         AND (v_existing_op.episode_id IS NOT DISTINCT FROM v_episode_id)
         AND v_existing_op.payload = v_payload THEN
        v_results := v_results || pg_catalog.jsonb_build_object(
          'operation_id', v_op_id,
          'server_revision', v_existing_op.server_revision,
          'status', 'duplicate',
          'apply_status', v_existing_op.apply_status
        );
        CONTINUE;
      ELSE
        RAISE EXCEPTION 'Conflicto de idempotencia: operation_id % reutilizado con datos diferentes', v_op_id USING ERRCODE = '23505';
      END IF;
    END IF;

    -- B. Monotonicidad estricta de secuencia por dispositivo
    SELECT COALESCE(MAX(client_sequence), 0)
    INTO v_max_seq
    FROM public.profile_operations
    WHERE profile_id = p_profile_id AND device_id = v_device_id;

    IF v_client_seq <= v_max_seq THEN
      RAISE EXCEPTION 'Secuencia no monotónica % <= % para dispositivo %', v_client_seq, v_max_seq, v_device_id USING ERRCODE = '22023';
    END IF;

    -- C. Validación exhaustiva de payload por tipo
    CASE v_op_type
      WHEN 'favorite_add', 'favorite_remove' THEN
        IF v_payload <> '{}'::jsonb THEN
          RAISE EXCEPTION 'Payload para % debe ser vacío {}', v_op_type USING ERRCODE = '22023';
        END IF;

      WHEN 'restart' THEN
        IF (v_payload - 'duration_ms') <> '{}'::jsonb THEN
          RAISE EXCEPTION 'Payload para restart contiene claves no permitidas' USING ERRCODE = '22023';
        END IF;
        IF v_payload ? 'duration_ms' THEN
          IF pg_catalog.jsonb_typeof(v_payload->'duration_ms') <> 'number' OR (v_payload->>'duration_ms')::bigint < 0 OR (v_payload->>'duration_ms')::bigint > 86400000 THEN
            RAISE EXCEPTION 'duration_ms inválido en restart' USING ERRCODE = '22023';
          END IF;
        END IF;

      WHEN 'mark_completed' THEN
        IF (v_payload - 'duration_ms') <> '{}'::jsonb THEN
          RAISE EXCEPTION 'Payload para mark_completed contiene claves no permitidas' USING ERRCODE = '22023';
        END IF;
        IF v_payload ? 'duration_ms' THEN
          IF pg_catalog.jsonb_typeof(v_payload->'duration_ms') <> 'number' OR (v_payload->>'duration_ms')::bigint <= 0 OR (v_payload->>'duration_ms')::bigint > 86400000 THEN
            RAISE EXCEPTION 'duration_ms inválido en mark_completed' USING ERRCODE = '22023';
          END IF;
        END IF;

      WHEN 'progress_update' THEN
        IF (v_payload - 'position_ms' - 'duration_ms') <> '{}'::jsonb THEN
          RAISE EXCEPTION 'Payload para progress_update contiene claves no permitidas' USING ERRCODE = '22023';
        END IF;
        IF pg_catalog.jsonb_typeof(v_payload->'position_ms') <> 'number' OR pg_catalog.jsonb_typeof(v_payload->'duration_ms') <> 'number' THEN
          RAISE EXCEPTION 'position_ms y duration_ms deben ser numéricos' USING ERRCODE = '22023';
        END IF;
        IF (v_payload->>'position_ms')::bigint < 0 OR (v_payload->>'duration_ms')::bigint < 0 THEN
          RAISE EXCEPTION 'position_ms y duration_ms deben ser >= 0' USING ERRCODE = '22023';
        END IF;
        IF (v_payload->>'duration_ms')::bigint > 0 AND (v_payload->>'position_ms')::bigint > ((v_payload->>'duration_ms')::bigint + 5000) THEN
          RAISE EXCEPTION 'position_ms excede coherentemente duration_ms' USING ERRCODE = '22023';
        END IF;

      WHEN 'history_append' THEN
        IF (v_payload - 'position_ms' - 'duration_ms') <> '{}'::jsonb THEN
          RAISE EXCEPTION 'Payload para history_append contiene claves no permitidas' USING ERRCODE = '22023';
        END IF;
        IF pg_catalog.jsonb_typeof(v_payload->'position_ms') <> 'number' OR pg_catalog.jsonb_typeof(v_payload->'duration_ms') <> 'number' THEN
          RAISE EXCEPTION 'position_ms y duration_ms deben ser numéricos en historial' USING ERRCODE = '22023';
        END IF;
        DECLARE
          v_hpos bigint := (v_payload->>'position_ms')::bigint;
          v_hdur bigint := (v_payload->>'duration_ms')::bigint;
        BEGIN
          IF v_hpos < 0 OR v_hdur < 0 THEN
            RAISE EXCEPTION 'Valores negativos en historial' USING ERRCODE = '22023';
          END IF;
          IF v_hpos < 60000 AND (v_hdur = 0 OR v_hpos < (v_hdur * 0.9)::bigint) THEN
            RAISE EXCEPTION 'Sesión de reproducción no significativa para historial (<60s)' USING ERRCODE = '22023';
          END IF;
        END;

      WHEN 'preferences_update' THEN
        IF (v_payload - 'preferred_audio_language' - 'preferred_subtitle_language' - 'subtitles_enabled' - 'preferred_quality') <> '{}'::jsonb THEN
          RAISE EXCEPTION 'Payload para preferences_update contiene claves no permitidas' USING ERRCODE = '22023';
        END IF;
        IF v_payload ? 'subtitles_enabled' AND pg_catalog.jsonb_typeof(v_payload->'subtitles_enabled') <> 'boolean' THEN
          RAISE EXCEPTION 'subtitles_enabled debe ser booleano' USING ERRCODE = '22023';
        END IF;
        IF v_payload ? 'preferred_audio_language' AND length(v_payload->>'preferred_audio_language') > 16 THEN
          RAISE EXCEPTION 'preferred_audio_language excede 16 caracteres' USING ERRCODE = '22023';
        END IF;
        IF v_payload ? 'preferred_subtitle_language' AND length(v_payload->>'preferred_subtitle_language') > 16 THEN
          RAISE EXCEPTION 'preferred_subtitle_language excede 16 caracteres' USING ERRCODE = '22023';
        END IF;
        IF v_payload ? 'preferred_quality' AND length(v_payload->>'preferred_quality') > 32 THEN
          RAISE EXCEPTION 'preferred_quality excede 32 caracteres' USING ERRCODE = '22023';
        END IF;
    END CASE;

    -- D. Determinar apply_status evaluando la sesión activa
    IF v_op_type = 'progress_update' THEN
      SELECT playback_session_id, is_completed, position_ms
      INTO v_existing_prog
      FROM public.profile_playback_progress
      WHERE profile_id = p_profile_id AND content_key = v_content_key;

      IF FOUND AND (v_existing_prog.playback_session_id <> v_session_id OR v_existing_prog.is_completed) THEN
        v_apply_status := 'ignored_stale';
      END IF;
    ELSIF v_op_type = 'mark_completed' THEN
      SELECT playback_session_id INTO v_existing_prog
      FROM public.profile_playback_progress
      WHERE profile_id = p_profile_id AND content_key = v_content_key;

      IF FOUND AND v_existing_prog.playback_session_id <> v_session_id THEN
        v_apply_status := 'ignored_stale';
      END IF;
    END IF;

    -- E. Incrementar revisión e insertar en ledger
    v_latest_rev := v_latest_rev + 1;

    INSERT INTO public.profile_operations (
      owner_id, profile_id, operation_id, device_id, client_sequence,
      playback_session_id, operation_type, apply_status, content_key, title_id, episode_id,
      payload, server_revision, server_received_at, client_timestamp
    ) VALUES (
      v_owner_id, p_profile_id, v_op_id, v_device_id, v_client_seq,
      v_session_id, v_op_type, v_apply_status, v_content_key, v_title_id, v_episode_id,
      v_payload, v_latest_rev, v_now, v_client_ts
    );

    -- F. Materialización de estado si apply_status == 'applied'
    IF v_apply_status = 'applied' THEN
      CASE v_op_type
        WHEN 'favorite_add' THEN
          INSERT INTO public.profile_favorites (owner_id, profile_id, content_key, title_id, is_favorite, server_revision, updated_at, deleted_at)
          VALUES (v_owner_id, p_profile_id, v_content_key, v_title_id, true, v_latest_rev, v_now, NULL)
          ON CONFLICT (profile_id, content_key) DO UPDATE SET
            is_favorite = true,
            title_id = COALESCE(EXCLUDED.title_id, public.profile_favorites.title_id),
            server_revision = v_latest_rev,
            updated_at = v_now,
            deleted_at = NULL;

        WHEN 'favorite_remove' THEN
          INSERT INTO public.profile_favorites (owner_id, profile_id, content_key, title_id, is_favorite, server_revision, updated_at, deleted_at)
          VALUES (v_owner_id, p_profile_id, v_content_key, v_title_id, false, v_latest_rev, v_now, v_now)
          ON CONFLICT (profile_id, content_key) DO UPDATE SET
            is_favorite = false,
            title_id = COALESCE(EXCLUDED.title_id, public.profile_favorites.title_id),
            server_revision = v_latest_rev,
            updated_at = v_now,
            deleted_at = v_now;

        WHEN 'restart' THEN
          DECLARE
            v_rdur bigint := COALESCE((v_payload->>'duration_ms')::bigint, 0);
          BEGIN
            INSERT INTO public.profile_playback_progress (
              owner_id, profile_id, content_key, playback_session_id, title_id, episode_id,
              position_ms, duration_ms, fraction, is_completed, last_watched_at, server_revision, updated_at, deleted_at
            ) VALUES (
              v_owner_id, p_profile_id, v_content_key, v_session_id, v_title_id, v_episode_id,
              0, v_rdur, 0.0, false, v_now, v_latest_rev, v_now, NULL
            )
            ON CONFLICT (profile_id, content_key) DO UPDATE SET
              playback_session_id = v_session_id,
              position_ms = 0,
              duration_ms = CASE WHEN v_rdur > 0 THEN v_rdur ELSE public.profile_playback_progress.duration_ms END,
              fraction = 0.0,
              is_completed = false,
              title_id = COALESCE(EXCLUDED.title_id, public.profile_playback_progress.title_id),
              episode_id = COALESCE(EXCLUDED.episode_id, public.profile_playback_progress.episode_id),
              last_watched_at = v_now,
              server_revision = v_latest_rev,
              updated_at = v_now,
              deleted_at = NULL;
          END;

        WHEN 'progress_update' THEN
          DECLARE
            v_pos bigint := (v_payload->>'position_ms')::bigint;
            v_dur bigint := (v_payload->>'duration_ms')::bigint;
            v_final_pos bigint;
          BEGIN
            IF v_existing_prog IS NOT NULL THEN
              v_final_pos := GREATEST(v_existing_prog.position_ms, v_pos);
              v_calc_fraction := CASE WHEN v_dur > 0 THEN LEAST(1.0, v_final_pos::double precision / v_dur::double precision) ELSE 0.0 END;

              UPDATE public.profile_playback_progress SET
                position_ms = v_final_pos,
                duration_ms = v_dur,
                fraction = v_calc_fraction,
                title_id = COALESCE(v_title_id, public.profile_playback_progress.title_id),
                episode_id = COALESCE(v_episode_id, public.profile_playback_progress.episode_id),
                last_watched_at = v_now,
                server_revision = v_latest_rev,
                updated_at = v_now,
                deleted_at = NULL
              WHERE profile_id = p_profile_id AND content_key = v_content_key;
            ELSE
              v_calc_fraction := CASE WHEN v_dur > 0 THEN LEAST(1.0, v_pos::double precision / v_dur::double precision) ELSE 0.0 END;
              INSERT INTO public.profile_playback_progress (
                owner_id, profile_id, content_key, playback_session_id, title_id, episode_id,
                position_ms, duration_ms, fraction, is_completed, last_watched_at, server_revision, updated_at, deleted_at
              ) VALUES (
                v_owner_id, p_profile_id, v_content_key, v_session_id, v_title_id, v_episode_id,
                v_pos, v_dur, v_calc_fraction, false, v_now, v_latest_rev, v_now, NULL
              );
            END IF;
          END;

        WHEN 'mark_completed' THEN
          DECLARE
            v_mdur bigint := COALESCE((v_payload->>'duration_ms')::bigint, 0);
          BEGIN
            INSERT INTO public.profile_playback_progress (
              owner_id, profile_id, content_key, playback_session_id, title_id, episode_id,
              position_ms, duration_ms, fraction, is_completed, last_watched_at, server_revision, updated_at, deleted_at
            ) VALUES (
              v_owner_id, p_profile_id, v_content_key, v_session_id, v_title_id, v_episode_id,
              v_mdur, v_mdur, 1.0, true, v_now, v_latest_rev, v_now, NULL
            )
            ON CONFLICT (profile_id, content_key) DO UPDATE SET
              playback_session_id = v_session_id,
              position_ms = CASE WHEN v_mdur > 0 THEN v_mdur ELSE public.profile_playback_progress.duration_ms END,
              duration_ms = CASE WHEN v_mdur > 0 THEN v_mdur ELSE public.profile_playback_progress.duration_ms END,
              fraction = 1.0,
              is_completed = true,
              title_id = COALESCE(EXCLUDED.title_id, public.profile_playback_progress.title_id),
              episode_id = COALESCE(EXCLUDED.episode_id, public.profile_playback_progress.episode_id),
              last_watched_at = v_now,
              server_revision = v_latest_rev,
              updated_at = v_now,
              deleted_at = NULL;
          END;

        WHEN 'history_append' THEN
          INSERT INTO public.profile_history (
            owner_id, profile_id, operation_id, content_key, playback_session_id,
            title_id, episode_id, position_ms, duration_ms, server_revision,
            server_received_at, watched_at, client_timestamp
          ) VALUES (
            v_owner_id, p_profile_id, v_op_id, v_content_key, v_session_id,
            v_title_id, v_episode_id,
            (v_payload->>'position_ms')::bigint,
            (v_payload->>'duration_ms')::bigint,
            v_latest_rev, v_now, v_now, v_client_ts
          );
          PERFORM public._prune_profile_history_internal(p_profile_id);

        WHEN 'preferences_update' THEN
          INSERT INTO public.profile_preferences (
            owner_id, profile_id, preferred_audio_language, preferred_subtitle_language,
            subtitles_enabled, preferred_quality, server_revision, updated_at
          ) VALUES (
            v_owner_id, p_profile_id,
            v_payload->>'preferred_audio_language',
            v_payload->>'preferred_subtitle_language',
            COALESCE((v_payload->>'subtitles_enabled')::boolean, false),
            v_payload->>'preferred_quality',
            v_latest_rev, v_now
          )
          ON CONFLICT (profile_id) DO UPDATE SET
            preferred_audio_language = v_payload->>'preferred_audio_language',
            preferred_subtitle_language = v_payload->>'preferred_subtitle_language',
            subtitles_enabled = COALESCE((v_payload->>'subtitles_enabled')::boolean, false),
            preferred_quality = v_payload->>'preferred_quality',
            server_revision = v_latest_rev,
            updated_at = v_now;
      END CASE;
    END IF;

    v_results := v_results || pg_catalog.jsonb_build_object(
      'operation_id', v_op_id,
      'server_revision', v_latest_rev,
      'status', CASE WHEN v_apply_status = 'applied' THEN 'applied' ELSE 'ignored_stale' END,
      'apply_status', v_apply_status
    );
  END LOOP;

  UPDATE public.profile_sync_metadata
  SET latest_revision = v_latest_rev, updated_at = pg_catalog.clock_timestamp()
  WHERE profile_id = p_profile_id;

  RETURN v_results;
END;
$$;

REVOKE ALL ON FUNCTION public.push_profile_operations(uuid, jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.push_profile_operations(uuid, jsonb) TO authenticated, service_role;

-- 7.2. pull_profile_changes: Keyset paging con orden explícito y FOR SHARE
CREATE OR REPLACE FUNCTION public.pull_profile_changes(
  p_profile_id uuid,
  p_since_revision bigint DEFAULT 0,
  p_limit int DEFAULT 100
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_owner_id uuid;
  v_latest_rev bigint := 0;
  v_min_rev bigint := 0;
  v_capped_limit int;
  v_operations jsonb := '[]'::jsonb;
  v_next_cursor bigint := p_since_revision;
  v_has_more boolean := false;
BEGIN
  v_owner_id := (SELECT auth.uid());
  IF v_owner_id IS NULL THEN
    RAISE EXCEPTION 'No autenticado' USING ERRCODE = '28000';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.account_profiles
    WHERE id = p_profile_id AND owner_id = v_owner_id
  ) THEN
    RAISE EXCEPTION 'Perfil no encontrado o acceso no autorizado' USING ERRCODE = '42501';
  END IF;

  IF p_since_revision < 0 THEN
    RAISE EXCEPTION 'p_since_revision debe ser >= 0' USING ERRCODE = '22023';
  END IF;

  v_capped_limit := LEAST(GREATEST(COALESCE(p_limit, 100), 1), 500);

  -- Garantizar fila de metadatos primero para evitar carreras iniciales
  INSERT INTO public.profile_sync_metadata (profile_id, owner_id, latest_revision, minimum_available_revision, updated_at)
  VALUES (p_profile_id, v_owner_id, 0, 0, pg_catalog.clock_timestamp())
  ON CONFLICT (profile_id) DO NOTHING;

  -- Bloqueo FOR SHARE: previene compactación concurrente durante lectura
  SELECT latest_revision, minimum_available_revision
  INTO v_latest_rev, v_min_rev
  FROM public.profile_sync_metadata
  WHERE profile_id = p_profile_id
  FOR SHARE;

  -- Evaluación formal de full-resync
  IF (p_since_revision + 1 < v_min_rev) AND (v_min_rev > 1) THEN
    RETURN pg_catalog.jsonb_build_object(
      'profile_id', p_profile_id,
      'latest_revision', v_latest_rev,
      'minimum_available_revision', v_min_rev,
      'full_resync_required', true,
      'has_more', false,
      'next_cursor', v_latest_rev,
      'operations', '[]'::jsonb
    );
  END IF;

  -- Keyset pagination con orden explícito en la agregación
  SELECT
    COALESCE(pg_catalog.jsonb_agg(sub.op ORDER BY sub.server_revision ASC), '[]'::jsonb),
    COALESCE(MAX(sub.server_revision), p_since_revision)
  INTO v_operations, v_next_cursor
  FROM (
    SELECT
      pg_catalog.jsonb_build_object(
        'operation_id', operation_id,
        'device_id', device_id,
        'client_sequence', client_sequence,
        'playback_session_id', playback_session_id,
        'operation_type', operation_type,
        'apply_status', apply_status,
        'content_key', content_key,
        'title_id', title_id,
        'episode_id', episode_id,
        'payload', payload,
        'server_revision', server_revision,
        'server_received_at', server_received_at,
        'client_timestamp', client_timestamp
      ) AS op,
      server_revision
    FROM public.profile_operations
    WHERE profile_id = p_profile_id
      AND server_revision > p_since_revision
    ORDER BY server_revision ASC
    LIMIT v_capped_limit
  ) sub;

  IF v_next_cursor < v_latest_rev THEN
    v_has_more := true;
  END IF;

  RETURN pg_catalog.jsonb_build_object(
    'profile_id', p_profile_id,
    'latest_revision', v_latest_rev,
    'minimum_available_revision', v_min_rev,
    'full_resync_required', false,
    'has_more', v_has_more,
    'next_cursor', v_next_cursor,
    'operations', v_operations
  );
END;
$$;

REVOKE ALL ON FUNCTION public.pull_profile_changes(uuid, bigint, int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.pull_profile_changes(uuid, bigint, int) TO authenticated, service_role;

-- 7.3. get_profile_snapshot: Snapshot consistente con historial completo y FOR SHARE
CREATE OR REPLACE FUNCTION public.get_profile_snapshot(
  p_profile_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_owner_id uuid;
  v_latest_rev bigint;
  v_favorites jsonb;
  v_progress jsonb;
  v_preferences jsonb;
  v_history jsonb;
BEGIN
  v_owner_id := (SELECT auth.uid());
  IF v_owner_id IS NULL THEN
    RAISE EXCEPTION 'No autenticado' USING ERRCODE = '28000';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.account_profiles
    WHERE id = p_profile_id AND owner_id = v_owner_id
  ) THEN
    RAISE EXCEPTION 'Perfil no encontrado o acceso no autorizado' USING ERRCODE = '42501';
  END IF;

  -- Garantizar fila de metadatos primero para evitar carrera en perfiles nuevos
  INSERT INTO public.profile_sync_metadata (profile_id, owner_id, latest_revision, minimum_available_revision, updated_at)
  VALUES (p_profile_id, v_owner_id, 0, 0, pg_catalog.clock_timestamp())
  ON CONFLICT (profile_id) DO NOTHING;

  -- Bloqueo FOR SHARE: compatible con lecturas, incompatible con FOR UPDATE de push
  SELECT latest_revision INTO v_latest_rev
  FROM public.profile_sync_metadata
  WHERE profile_id = p_profile_id
  FOR SHARE;

  -- Lectura atómica bajo la misma frontera transaccional
  SELECT COALESCE(pg_catalog.jsonb_agg(
    pg_catalog.jsonb_build_object(
      'content_key', content_key,
      'title_id', title_id,
      'is_favorite', is_favorite,
      'server_revision', server_revision,
      'updated_at', updated_at
    )
  ), '[]'::jsonb)
  INTO v_favorites
  FROM public.profile_favorites
  WHERE profile_id = p_profile_id AND deleted_at IS NULL AND is_favorite = true;

  SELECT COALESCE(pg_catalog.jsonb_agg(
    pg_catalog.jsonb_build_object(
      'content_key', content_key,
      'playback_session_id', playback_session_id,
      'title_id', title_id,
      'episode_id', episode_id,
      'position_ms', position_ms,
      'duration_ms', duration_ms,
      'fraction', fraction,
      'is_completed', is_completed,
      'last_watched_at', last_watched_at,
      'server_revision', server_revision
    )
  ), '[]'::jsonb)
  INTO v_progress
  FROM public.profile_playback_progress
  WHERE profile_id = p_profile_id AND deleted_at IS NULL;

  SELECT pg_catalog.jsonb_build_object(
    'preferred_audio_language', preferred_audio_language,
    'preferred_subtitle_language', preferred_subtitle_language,
    'subtitles_enabled', subtitles_enabled,
    'preferred_quality', preferred_quality,
    'server_revision', server_revision
  )
  INTO v_preferences
  FROM public.profile_preferences
  WHERE profile_id = p_profile_id;

  SELECT COALESCE(pg_catalog.jsonb_agg(sub.h ORDER BY sub.server_received_at DESC, sub.server_revision DESC, sub.id DESC), '[]'::jsonb)
  INTO v_history
  FROM (
    SELECT id, server_received_at, server_revision,
      pg_catalog.jsonb_build_object(
        'operation_id', operation_id,
        'content_key', content_key,
        'playback_session_id', playback_session_id,
        'title_id', title_id,
        'episode_id', episode_id,
        'position_ms', position_ms,
        'duration_ms', duration_ms,
        'server_revision', server_revision,
        'server_received_at', server_received_at,
        'watched_at', watched_at
      ) AS h
    FROM public.profile_history
    WHERE profile_id = p_profile_id
    ORDER BY server_received_at DESC, server_revision DESC, id DESC
    LIMIT 500
  ) sub;

  RETURN pg_catalog.jsonb_build_object(
    'profile_id', p_profile_id,
    'snapshot_revision', COALESCE(v_latest_rev, 0),
    'favorites', v_favorites,
    'progress', v_progress,
    'preferences', COALESCE(v_preferences, '{}'::jsonb),
    'history', v_history
  );
END;
$$;

REVOKE ALL ON FUNCTION public.get_profile_snapshot(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_profile_snapshot(uuid) TO authenticated, service_role;

-- 7.4. update_guest_import_audit: Máquina de estados estricta y segura contra carreras
CREATE OR REPLACE FUNCTION public.update_guest_import_audit(
  p_profile_id uuid,
  p_import_batch_id uuid,
  p_status text,
  p_favorites_count int DEFAULT 0,
  p_progress_count int DEFAULT 0,
  p_history_count int DEFAULT 0,
  p_error_message text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_owner_id uuid;
  v_clean_error text;
  v_existing record;
BEGIN
  v_owner_id := (SELECT auth.uid());
  IF v_owner_id IS NULL THEN
    RAISE EXCEPTION 'No autenticado' USING ERRCODE = '28000';
  END IF;

  IF p_import_batch_id IS NULL THEN
    RAISE EXCEPTION 'import_batch_id es obligatorio' USING ERRCODE = '22023';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.account_profiles
    WHERE id = p_profile_id AND owner_id = v_owner_id
  ) THEN
    RAISE EXCEPTION 'Perfil no autorizado' USING ERRCODE = '42501';
  END IF;

  IF p_status NOT IN ('in_progress', 'completed', 'failed') THEN
    RAISE EXCEPTION 'Estado de importación inválido' USING ERRCODE = '22023';
  END IF;

  IF p_favorites_count < 0 OR p_favorites_count > 10000 OR
     p_progress_count < 0 OR p_progress_count > 10000 OR
     p_history_count < 0 OR p_history_count > 10000 THEN
    RAISE EXCEPTION 'Contadores de importación fuera de rango (0..10000)' USING ERRCODE = '22023';
  END IF;

  v_clean_error := CASE WHEN p_status = 'failed' THEN substr(trim(COALESCE(p_error_message, '')), 1, 500) ELSE NULL END;

  -- 1. Si se solicita in_progress, asegurar la inserción inicial sin carreras concurrentes
  IF p_status = 'in_progress' THEN
    INSERT INTO public.guest_import_audit (
      owner_id, target_profile_id, import_batch_id, status,
      favorites_count, progress_count, history_count, error_message,
      created_at, completed_at
    ) VALUES (
      v_owner_id, p_profile_id, p_import_batch_id, 'in_progress',
      p_favorites_count, p_progress_count, p_history_count, NULL,
      pg_catalog.clock_timestamp(), NULL
    )
    ON CONFLICT (target_profile_id, import_batch_id) DO NOTHING;
  END IF;

  -- 2. Bloquear registro existente con FOR UPDATE
  SELECT * INTO v_existing
  FROM public.guest_import_audit
  WHERE target_profile_id = p_profile_id AND import_batch_id = p_import_batch_id
  FOR UPDATE;

  IF NOT FOUND THEN
    -- Si no existe y no fue in_progress, rechazar la transición desde inexistente
    RAISE EXCEPTION 'Un lote nuevo debe comenzar estrictamente como in_progress' USING ERRCODE = '22023';
  END IF;

  -- 3. Máquina de estados estricta
  IF v_existing.status = 'completed' THEN
    IF p_status <> 'completed' THEN
      RAISE EXCEPTION 'Un lote completado no puede transicionar a %', p_status USING ERRCODE = '22023';
    END IF;

    -- Validar que los recuentos coincidan exactamente para aceptar la llamada idempotente
    IF v_existing.favorites_count <> p_favorites_count OR
       v_existing.progress_count <> p_progress_count OR
       v_existing.history_count <> p_history_count THEN
      RAISE EXCEPTION 'Conflicto: lote completado con recuentos diferentes' USING ERRCODE = '23505';
    END IF;

    RETURN pg_catalog.jsonb_build_object(
      'target_profile_id', v_existing.target_profile_id,
      'import_batch_id', v_existing.import_batch_id,
      'status', 'completed'
    );
  ELSIF v_existing.status = 'failed' THEN
    -- failed solo puede transicionar a in_progress (reintento) o failed (actualización de error)
    IF p_status NOT IN ('in_progress', 'failed') THEN
      RAISE EXCEPTION 'Un lote fallido solo puede reiniciarse como in_progress o actualizarse como failed' USING ERRCODE = '22023';
    END IF;
  ELSIF v_existing.status = 'in_progress' THEN
    -- in_progress puede transicionar a in_progress, completed o failed (todas permitidas)
    NULL;
  END IF;

  -- 4. Aplicar actualización de estado
  UPDATE public.guest_import_audit SET
    status = p_status,
    favorites_count = p_favorites_count,
    progress_count = p_progress_count,
    history_count = p_history_count,
    error_message = v_clean_error,
    completed_at = CASE WHEN p_status IN ('completed', 'failed') THEN pg_catalog.clock_timestamp() ELSE NULL END
  WHERE target_profile_id = p_profile_id AND import_batch_id = p_import_batch_id;

  RETURN pg_catalog.jsonb_build_object(
    'target_profile_id', p_profile_id,
    'import_batch_id', p_import_batch_id,
    'status', p_status
  );
END;
$$;

REVOKE ALL ON FUNCTION public.update_guest_import_audit(uuid, uuid, text, int, int, int, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.update_guest_import_audit(uuid, uuid, text, int, int, int, text) TO authenticated, service_role;

-- 7.5. compact_profile_operations: Compactación de operaciones con ventana segura
CREATE OR REPLACE FUNCTION public.compact_profile_operations(
  p_profile_id uuid,
  p_retain_days int DEFAULT 30,
  p_min_operations_to_keep int DEFAULT 1000
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_cutoff timestamptz;
  v_safe_rev bigint;
  v_deleted_count int := 0;
  v_current_latest bigint;
  v_current_min bigint;
  v_new_min bigint;
BEGIN
  IF p_retain_days < 7 OR p_retain_days > 365 THEN
    RAISE EXCEPTION 'p_retain_days debe estar entre 7 y 365 días' USING ERRCODE = '22023';
  END IF;

  IF p_min_operations_to_keep < 500 THEN
    RAISE EXCEPTION 'p_min_operations_to_keep debe ser al menos 500' USING ERRCODE = '22023';
  END IF;

  -- Bloqueo pesimista del perfil
  SELECT latest_revision, minimum_available_revision
  INTO v_current_latest, v_current_min
  FROM public.profile_sync_metadata
  WHERE profile_id = p_profile_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Perfil no encontrado en metadatos' USING ERRCODE = '22023';
  END IF;

  v_cutoff := pg_catalog.clock_timestamp() - (p_retain_days || ' days')::interval;

  SELECT server_revision INTO v_safe_rev
  FROM public.profile_operations
  WHERE profile_id = p_profile_id
    AND server_received_at < v_cutoff
  ORDER BY server_revision DESC
  OFFSET p_min_operations_to_keep
  LIMIT 1;

  IF v_safe_rev IS NOT NULL AND v_safe_rev >= v_current_min THEN
    DELETE FROM public.profile_operations
    WHERE profile_id = p_profile_id AND server_revision <= v_safe_rev;

    GET DIAGNOSTICS v_deleted_count = ROW_COUNT;

    v_new_min := v_safe_rev + 1;
    UPDATE public.profile_sync_metadata
    SET minimum_available_revision = v_new_min,
        updated_at = pg_catalog.clock_timestamp()
    WHERE profile_id = p_profile_id;
  ELSE
    v_new_min := v_current_min;
  END IF;

  RETURN pg_catalog.jsonb_build_object(
    'profile_id', p_profile_id,
    'deleted_count', v_deleted_count,
    'new_minimum_available_revision', v_new_min
  );
END;
$$;

REVOKE ALL ON FUNCTION public.compact_profile_operations(uuid, int, int) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.compact_profile_operations(uuid, int, int) TO service_role;
