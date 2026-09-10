# HourTV Catálogo Paginado en Supabase, Caché Local Indexada y Sincronización Incremental (Fase 3) - Plan de Implementación

> **Para desarrolladores y agentes:** SUB-HABILIDAD REQUERIDA: Usar `superpowers:subagent-driven-development` o `superpowers:executing-plans` para implementar este plan tarea por tarea. Cada paso utiliza sintaxis de casillas de verificación (`- [ ]`) para seguimiento estricto.

**Objetivo:** Evolucionar HourTV desde un catálogo monolítico en memoria (`catalog.json` / `SharedPreferences`) hacia una arquitectura híbrida de alto rendimiento: catálogo relacional normalizado en Supabase con paginación determinista por cursor compuesta, registro transaccional de cambios filtrado contra filtraciones (`catalog_changes`) con funciones PostgreSQL blindadas (`REVOKE ALL FROM PUBLIC/anon/authenticated`, `SET search_path = ''`), actualización automática de `latest_revision` y compactación administrativa, caché local indexada en Flutter con Drift (SQLite) en un isolate en segundo plano (`NativeDatabase.createInBackground`) con búsqueda FTS5 sanitizada y parametrizada (`MATCH`), sincronización incremental con checkpoint atómico y recuperación segura por resincronización completa, funcionamiento *offline-first* transparente, respaldo de emergencia al JSON actual y capacidad probada para más de 10,000 títulos.

**Arquitectura:**
- **Remota (Supabase / PostgreSQL 15+):** Esquema relacional normalizado (`titles`, `genres`, `title_genres`, `seasons`, `episodes`, `languages`, `sources`, `catalog_changes`, `catalog_sync_metadata`).
  - Paginación determinista por cursor basada en tuplas `(created_at, id)` con la condición estricta:
    `created_at < cursor.createdAt OR (created_at = cursor.createdAt AND id < cursor.id)` y orden `created_at DESC, id DESC`.
  - Registro de cambios `catalog_changes` con revisiones incrementales (`bigint generated always as identity`) para sincronizar deltas transaccionales entre todas las entidades (`title`, `season`, `episode`, `source`, `title_genre`, `genre`, `language`).
  - **Blindaje Estricto de Funciones PostgreSQL:**
    - Después de crear cada función del catálogo (administrativa, auxiliar o de trigger):
      - `REVOKE ALL ON FUNCTION ... FROM PUBLIC;`
      - `REVOKE ALL ON FUNCTION ... FROM anon;`
      - `REVOKE ALL ON FUNCTION ... FROM authenticated;`
      Esto incluye obligatoriamente `compact_catalog_changes(bigint)`, `fn_update_catalog_sync_metadata_latest()`, todas las funciones de triggers que escriben en `catalog_changes` (`fn_catalog_changes_titles`, `fn_catalog_changes_seasons`, `fn_catalog_changes_episodes`, `fn_catalog_changes_sources`, `fn_catalog_changes_title_genres`, `fn_catalog_changes_genres`, `fn_catalog_changes_languages`) y cualquier función auxiliar administrativa.
    - `compact_catalog_changes(bigint)` es exclusivamente administrativa:
      - Sin `GRANT EXECUTE` a `anon` ni `authenticated`.
      - No se expone como RPC utilizable por la APK en PostgREST (inaccesible para clientes).
      - Ejecutada únicamente mediante conexión administrativa local (`127.0.0.1:54322` con usuario `postgres`) o backend confiable futuro.
    - Para funciones `SECURITY DEFINER` (como `compact_catalog_changes`):
      - Usar obligatoriamente `SET search_path = ''`.
      - Referenciar todas las tablas y funciones con nombres totalmente calificados `public.*`.
      - Evitar estrictamente SQL dinámico (usar solo sentencias estáticas parametrizadas).
      - Fijar propietario administrativo (`OWNER TO postgres`).
      - Revocar `EXECUTE` de `PUBLIC`, `anon` y `authenticated` antes de cualquier `GRANT` explícito (sin otorgar ninguno a roles de cliente).
    - Para todas las funciones trigger:
      - Usar obligatoriamente `SET search_path = ''` y objetos totalmente calificados (`public.*`) para impedir ataques por resolución de nombres.
      - Fijar propietario administrativo (`OWNER TO postgres`).
      - Revocar todos los permisos a `PUBLIC`, `anon` y `authenticated` tras su creación. Los triggers operan internamente en el contexto del DML administrativo sin requerir privilegios de ejecución para roles de cliente.
  - **Actualización automática de `catalog_sync_metadata`:** Trigger en `catalog_changes` (`AFTER INSERT`) que actualiza atómicamente `latest_revision = NEW.revision`. Invariante `minimum_available_revision <= latest_revision` protegido por constraint. Función transaccional administrativa `compact_catalog_changes` que avanza `minimum_available_revision` y purga revisiones obsoletas.
  - **Prevención estricta de filtraciones en `catalog_changes`:** Los triggers de base de datos emiten eventos `upsert` únicamente si el título raíz está publicado (`is_published = true`) y no eliminado (`deleted_at IS NULL`). Si un título es borrador o privado, nunca genera registros en `catalog_changes`. Un evento `delete` solo se emite cuando un contenido previamente público es despublicado o eliminado.
  - **Lápidas (*tombstones*) mínimas y públicas:** `catalog_changes` expone `(revision, entity_type, entity_id, operation='delete', changed_at)` sin metadatos privados, permitiendo que `anon` y `authenticated` borren registros locales aun cuando la fila original en `titles` esté oculta por RLS.
  - **Validación uniforme y estricta de URLs de reproducción:**
    - `url`, `referer_url` y `origin_url` exigen exclusivamente `^https://` (sin excepciones de texto plano).
    - Prohibición idéntica en las tres columnas contra loopback IPv4/IPv6 (`127.0.0.0/8`, `[::1]`, `localhost`), IPs privadas (`10.0.0.0/8`, `192.168.0.0/16`, `172.16.0.0/12`), link-local (`169.254.0.0/16`, `[fe80:]`), credenciales embebidas (`user:pass@host`) y parámetros de query/fragmento con secretos (`token=`, `api_key=`, `secret=`, `auth=`, `cookie=`, `jwt=`).
    - `origin_url` restringido estrictamente al origen (`https://host` o `https://host:port`) sin ruta, query ni fragmento.
    - `user_agent_profile` restringido a enum (`default`, `vlc_desktop`, `exo_player`, `browser_mobile`).
  - **Defensa en Profundidad y Mitigación de DNS Rebinding:**
    - Los `CHECK` de PostgreSQL validan sintaxis y direcciones literales.
    - El validador del importador y de verificación de fuentes en Dart resuelve DNS antes de conectar y rechaza cualquier host que resuelva a rangos privados, loopback, link-local, multicast o reservados.
    - Re-validación de IP al momento de abrir la conexión HTTP/stream para proteger contra ataques de DNS Rebinding.
  - **Políticas RLS y Revocación de Privilegios:** Se revocan todos los permisos de `PUBLIC`. Solo se concede `SELECT` a `anon` y `authenticated`. Las políticas en `seasons`, `episodes`, `sources` y `title_genres` encadenan la validación hasta comprobar que el título raíz esté publicado y no eliminado.
- **Local (Flutter / Drift SQLite):** Base de datos relacional local en isolate dedicado (`NativeDatabase.createInBackground`) con tablas para resúmenes de tarjetas, detalles bajo demanda, relaciones con géneros y estado de sincronización (`catalog_sync_state` con `lastCatalogRevision` tipado como `integer` mapeado a `int` de 64 bits de Dart).
  - **Búsqueda FTS5 Segura y Parametrizada:** Tabla virtual FTS5 (`local_titles_fts`) con tokenizador `unicode61`. Las consultas nunca concatenan texto crudo; utilizan `sanitizeFts5Query` (normalización, escape de operadores FTS5, prefijos solo en tokens alfanuméricos seguros y parámetros enlazados `:matchQuery`).
- **Sincronización:** Patrón *Stale-While-Revalidate* con checkpoint atómico. Cada lote delta aplica sus cambios y actualiza `lastCatalogRevision` en una misma transacción Drift; si falla cualquier elemento, el checkpoint no avanza. Si el cliente está desfasado por debajo de `minimum_available_revision`, ejecuta una resincronización completa (*full resync*) reemplazando la caché del catálogo sin tocar favoritos ni progreso de usuario.
- **Tolerancia a Fallos y Fallback:** Si Supabase no está disponible, la app utiliza la caché local indexada. En caso de primera instalación sin red o caída total de la infraestructura remota con caché vacía, se activa el cargador de emergencia hacia `catalog.json` (o el empaquetado `assets/data/sources.json`), volcando los datos en Drift para conservar la indexación sin duplicidad permanente.
- **Compatibilidad Focalizada:** `ContentStore` deja de materializar todo el catálogo como `List<Channel>` para Inicio y Buscar. Las filas de Inicio y la cuadrícula de Buscar en `lib/mobile_ui/hourtv_mobile_shell.dart` consumen directamente consultas paginadas de Drift. La ficha de detalle hidrata un `Channel` o `XtreamSeries` bajo demanda para conservar el reproductor actual sin alterar su API.
- **Importador Local Administrativo:** `tool/import_catalog_to_supabase.dart` utiliza el driver oficial `postgres` de Dart conectando exclusivamente a `127.0.0.1:54322` con `--dry-run` por defecto y `--apply` explícito. Las credenciales se obtienen de variables de entorno locales, nunca se imprimen en logs y cualquier intento de conexión remota se aborta antes de abrir sockets.

**Pila Tecnológica Exacta:** Flutter 3.44.6 / Dart 3.12.2, `supabase_flutter: 2.17.2`, `drift: 2.35.0`, `drift_flutter: 0.3.1`, dev: `drift_dev: 2.35.0`, dev: `build_runner: 2.16.1`, dev: `postgres: ^3.2.1`, PostgreSQL 15+, Supabase CLI 2.117.0+, pgTAP. (Nota técnica: `sqlite3_flutter_libs` no se utiliza, ya que Drift 2.32+ y sqlite3 3.x gestionan las bibliotecas nativas automáticamente mediante hooks).

**Especificación de Referencia:** `docs/superpowers/specs/2026-09-09-hourtv-supabase-catalog-sync-performance-design.md`

---

## Restricciones Globales Obligatorias

1. **Versión fija:** Mantener estrictamente la versión `1.1.14+16` en `pubspec.yaml`. No generar tags ni publicar releases.
2. **Entorno local exclusivo:** No conectar, enlazar ni ejecutar `supabase db push` contra proyectos Supabase remotos durante esta fase. Toda la validación remota se realiza en el contenedor PostgreSQL local (`npx -y supabase test db`).
3. **Generación reproducible de migraciones:** No inventar nombres manuales de migración. Ejecutar obligatoriamente `npx -y supabase migration new create_catalog_schema`, capturar la ruta generada por la CLI y usar esa ruta exacta en `git add` sin comodines.
4. **No regresión de migraciones:** No modificar ni renombrar la migración existente de la Fase 2 (`supabase/migrations/20260910032210_create_account_profiles.sql`).
5. **Seguridad y privilegios mínimos:** Prohibir cualquier clave `service_role`, `sb_secret_` o credencial administrativa en código Flutter, repositorios, logs, assets o pruebas de integración. La APK solo interactúa mediante `SUPABASE_URL` y `SUPABASE_PUBLISHABLE_KEY`.
6. **Límite de Fase 3:** Esta fase abarca catálogo paginado, caché local, sincronización incremental y fallback JSON. **NO** implementar en esta fase la sincronización en la nube de favoritos, progreso de reproducción, recomendaciones personalizadas ni migración de datos de Invitado (reservados para la Fase 4).
7. **Preservación del cargador actual:** No eliminar `catalog.json` ni los analizadores existentes en `lib/services/catalog_parser.dart` y `lib/services/content_store.dart`. Sirven de soporte para el fallback de emergencia y transición gradual.
8. **Fuentes públicas y observables:** Cualquier URL de reproducción enviada a la APK es observable por el cliente. Supabase no puede convertir un enlace de streaming en un secreto; la protección radica en no almacenar cabeceras sensibles, credenciales de administración ni rutas internas.
9. **Importador local y seguro:** El script de importación de la Fase 3 solo opera contra Supabase local en `127.0.0.1:54322`, corre en modo `--dry-run` por defecto y rechaza cualquier conexión remota antes de abrir sockets.
10. **Disciplina TDD y commits atómicos:** Ningún código de producción se escribe antes de su prueba fallida correspondiente. Cada tarea debe completarse con pruebas pasando y un commit atómico individual. No utilizar `git add .` ni `git add -A`.

---

## Hallazgos de la Inspección del Código Existente

Antes de definir las tareas, se documentan los 7 puntos de análisis del código actual en `lib/` y `test/`:

### 1. Representación Actual de Modelos
- **Películas (`Channel` en `lib/models/channel.dart`):** Objeto con `forcedType = 'movie'` (o detectado por la URL del stream que contiene `/movie/`). Contiene metadatos de TMDB: `name`, `url` (stream directo), `logo` (póster vertical), `backdrop` (imagen 16:9), `tvgId` (identificador interno o del proveedor), `genre` (cadena de géneros separados por comas), `categories` (`List<String>` como 'populares', 'accion', 'recomendado'), `plot`, `year`, `rating`, `duration`, `cast`, `director`, `writer`, `releaseDate`, `isFeatured` y `servers` (`List<ChannelServer>`).
- **Series (`XtreamSeries` en `lib/services/xtream_service.dart` y `Channel`):** `XtreamSeries` agrupa metadatos globales (`seriesId` tipo `catalog:<id>`, `name`, `cover`, `backdrop`, `plot`, `year`, `rating`, `genre`, `categories`, `isFeatured`) y una lista `episodes` de tipo `List<Channel>`.
- **Temporadas y Episodios:** En `catalog.json` / `sources.json`, las series contienen una jerarquía `seasons: [{number: "1", episodes: [...]}]`. En Flutter, `CatalogParser._parseSeries` aplana los episodios en objetos `Channel` donde `group` almacena la temporada (ej. `'T1'`), `tvgId` almacena la clave jerárquica `'$seriesId:$seasonNumber:$episodeNumber'`, y cada episodio posee su propia lista de `servers`.
- **Idiomas y Servidores (`ChannelServer` en `lib/models/channel.dart`):** `ChannelServer(name: String, url: String, language: String?)`. El campo `language` guarda etiquetas textuales como `"Español"`, `"Latino"`, `"Subtitulado"`, `"Inglés"`.
- **Mirrors:** Se representan como múltiples instancias independientes en la lista `servers` del título o episodio.

### 2. Obtención, Fusión y Guardado en `ContentStore`
- En `ContentStore.load()` (`lib/services/content_store.dart`):
  1. Fase `openingCache`: Lee desde `StorageService.loadChannels()` y `StorageService.loadSeries()` (almacenados como cadenas JSON completas en `SharedPreferences`).
  2. Si la memoria está vacía, intenta cargar `_loadAssetSources()` (primero busca en la caché persistida de GitHub raw `remoteSourcesCache` y luego en el asset empaquetado `assets/data/sources.json`).
  3. Pasa a `ready` o `offlineReady`, desbloqueando la interfaz inmediatamente.
  4. En segundo plano (`_refreshContent`): si no hay restricción de `wifiOnly`, descarga el catálogo remoto desde GitHub raw (`https://raw.githubusercontent.com/KlenchoxD/hourtv-adming/master/catalog.json` con cache-buster `?_={timestamp}`).
  5. Descarga y parsea fuentes M3U, Xtream y Stalker de usuario.
  6. **Deduplicación:** El catálogo administrado (`assetSources.channels`) entra primero indexado por `id:${channel.tvgId}` y por título normalizado (`TmdbService.normalizeTitle(channel.displayName)`). Si una lista externa del usuario trae el mismo título, la versión administrada tiene prioridad y la externa se descarta.
  7. **Persistencia:** `_persistSnapshot()` serializa toda la lista `all` y `series` a JSON y la guarda en `SharedPreferences`.

### 3. Consumo en `CatalogPresentationIndex` y Pantallas Reales
- `lib/services/catalog_presentation_index.dart`:
  - Construye un snapshot inmutable precomputando `normalizedTitle`, `searchableText`, `normalizedGenres`, `parsedYear`, y banderas booleanas.
  - Ofrece métodos inmutables `search(CatalogQuery)` y `featured(limit)`.
- **Ubicación Real de Pantallas:**
  - `HourTvMobileHome` (Inicio) reside en `lib/mobile_ui/hourtv_mobile_shell.dart` (línea 275).
  - `HourTvMobileSearch` (Buscar) reside en `lib/mobile_ui/hourtv_mobile_shell.dart` (línea 845).
  - `HourTvMobileLibrary` (Biblioteca) reside en `lib/mobile_ui/hourtv_mobile_shell.dart` (línea 1482).
- En la Fase 3, `CatalogPresentationIndex` y las pantallas de `hourtv_mobile_shell.dart` se adaptan para alimentarse de consultas paginadas de Drift, evitando materializar listas gigantes en memoria.

### 4. Identificadores Estables Existentes
- **TMDB:** `tmdbId` / `tmdb_id` (entero, ej. `497698`) y `tmdbType` (`"movie"` | `"tv"`).
- **IMDb:** `imdb_id` (cadena tipo `"tt13622970"`), presente en `catalog.json` y `sources.json`.
- **Trakt / TVmaze:** Contemplados en la arquitectura para series y películas con resolución externa.
- **IDs Internos:** Formato corto tipo `"mrmz01ubkua53"` para películas; `"catalog:<id>"` para series; y `"catalog:<id>:<season>:<episode>"` para episodios.

### 5. Automatización de Publicación (ServerHunter y Admin Panel)
- **HourTV AutoCatálogo (`automation/`):** Tarea en GitHub Actions (`hourtv-auto-catalog.yml`) que se ejecuta cada 15 min. Lee proveedores externos (`OWN_CATALOG_URL` y ServerHunter), consulta TMDB, valida URLs con `HEAD`/`GET`, deduplica por `tmdbId` y actualiza `catalog.json`.
- **Panel Administrativo (`admin/catalog-publish.js` y `catalog-sync.js`):** Interfaz web que realiza merge tripartito (`CatalogSync.merge(base, local, remote)`) y sube el archivo a GitHub mediante la API REST con personal access token.

### 6. Datos Necesarios por Pantalla
- **Inicio (`HourTvMobileHome` en `hourtv_mobile_shell.dart`):** Hero (destacados completos) y filas horizontales ("Continuar viendo", "Tendencia", "Películas", "Series", "Anime", "K-Drama"). **Solo necesita resúmenes ligeros** (ID, título, póster, backdrop, año, calificación, tipo, géneros).
- **Buscar (`HourTvMobileSearch` en `hourtv_mobile_shell.dart`):** Resultados paginados (20-30 tarjetas) filtrados por término, tipo y género chip.
- **Guía TV (En Vivo):** Canales lineales agrupados por país y categoría, con línea EPG.
- **Biblioteca (`HourTvMobileLibrary` en `hourtv_mobile_shell.dart`):** Tarjetas resumen de títulos guardados en favoritos o historial, resolviendo IDs directamente contra Drift.
- **Ficha de Detalle:** Carga completa bajo demanda por `title_id`: sinopsis, elenco, director, guionista, fecha, servidores de la película o temporadas y episodios de la serie, hidratando una instancia concreta para el reproductor.
- **Reproductor:** Servidor seleccionado (`url`, `userAgentProfile`, `refererUrl`, `originUrl`).

### 7. Rutas y Pantallas con Funcionamiento Sin Conexión
- **Inicio:** Debe cargar de inmediato mostrando las filas y el Hero desde Drift en segundo plano.
- **Buscar:** Debe permitir búsquedas locales por texto y filtros de género/tipo contra la base local sin fallar.
- **Guía TV:** Debe mostrar los canales cacheados localmente.
- **Biblioteca:** Debe mostrar favoritos e historial locales.
- **Ficha de Detalle:** Debe abrir los títulos que ya se encuentren en la caché local.

---

## Desglose de Tareas de la Fase 3

### Task 1: Esquema Relacional en Supabase, Tabla de Cambios Anti-Filtraciones, Funciones Blindadas y Pruebas pgTAP

**Archivos:**
- Crear vía CLI: `supabase/migrations/<generated_timestamp>_create_catalog_schema.sql` (mediante `npx -y supabase migration new create_catalog_schema`)
- Crear: `supabase/tests/catalog_schema_rls.test.sql`
- Modificar: `supabase/seed.sql`

**Interfaces y Estructuras en PostgreSQL:**
- Enum: `public.media_type` (`'movie'`, `'series'`, `'anime'`, `'novela'`, `'live'`).
- Enum de entidades de cambio: `public.catalog_entity_type` (`'title'`, `'season'`, `'episode'`, `'source'`, `'title_genre'`, `'genre'`, `'language'`).
- Tablas Principales:
  - `public.languages`: `id uuid PRIMARY KEY DEFAULT gen_random_uuid()`, `code text UNIQUE NOT NULL`, `name text NOT NULL`, `created_at timestamptz NOT NULL DEFAULT now()`.
  - `public.genres`: `id uuid PRIMARY KEY DEFAULT gen_random_uuid()`, `name text NOT NULL`, `slug text UNIQUE NOT NULL`, `created_at timestamptz NOT NULL DEFAULT now()`.
  - `public.titles`:
    - `id uuid PRIMARY KEY DEFAULT gen_random_uuid()`
    - `legacy_id text UNIQUE`
    - `media_type public.media_type NOT NULL`
    - `title text NOT NULL`
    - `original_title text`
    - `normalized_title text NOT NULL`
    - `plot text`
    - `year int`
    - `release_date date`
    - `duration text`
    - `rating numeric(3, 1)`
    - `poster_url text`
    - `backdrop_url text`
    - `is_featured boolean NOT NULL DEFAULT false`
    - `is_published boolean NOT NULL DEFAULT true`
    - `cast_members text`
    - `director text`
    - `writer text`
    - `country_code text`
    - `tmdb_id int`
    - `imdb_id text`
    - `trakt_id int`
    - `tvmaze_id int`
    - `created_at timestamptz NOT NULL DEFAULT now()`
    - `updated_at timestamptz NOT NULL DEFAULT now()`
    - `deleted_at timestamptz`
  - `public.title_genres`: `title_id uuid REFERENCES public.titles(id) ON DELETE CASCADE`, `genre_id uuid REFERENCES public.genres(id) ON DELETE CASCADE`, `PRIMARY KEY (title_id, genre_id)`.
  - `public.seasons`: `id uuid PRIMARY KEY DEFAULT gen_random_uuid()`, `title_id uuid NOT NULL REFERENCES public.titles(id) ON DELETE CASCADE`, `season_number int NOT NULL`, `name text`, `plot text`, `poster_url text`, `created_at timestamptz NOT NULL DEFAULT now()`, `updated_at timestamptz NOT NULL DEFAULT now()`, `deleted_at timestamptz`, `UNIQUE (title_id, season_number)`.
  - `public.episodes`: `id uuid PRIMARY KEY DEFAULT gen_random_uuid()`, `season_id uuid NOT NULL REFERENCES public.seasons(id) ON DELETE CASCADE`, `episode_number int NOT NULL`, `title text NOT NULL`, `plot text`, `duration text`, `still_url text`, `release_date date`, `created_at timestamptz NOT NULL DEFAULT now()`, `updated_at timestamptz NOT NULL DEFAULT now()`, `deleted_at timestamptz`, `UNIQUE (season_id, episode_number)`.
  - `public.sources`:
    - `id uuid PRIMARY KEY DEFAULT gen_random_uuid()`
    - `title_id uuid REFERENCES public.titles(id) ON DELETE CASCADE`
    - `episode_id uuid REFERENCES public.episodes(id) ON DELETE CASCADE`
    - `language_id uuid REFERENCES public.languages(id) ON DELETE SET NULL`
    - `name text NOT NULL`
    - `url text NOT NULL`
    - `order_index int NOT NULL DEFAULT 0`
    - `status text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'verified', 'down', 'requires_webview'))`
    - `requires_webview boolean NOT NULL DEFAULT false`
    - `referer_url text`
    - `origin_url text`
    - `user_agent_profile text CHECK (user_agent_profile IS NULL OR user_agent_profile IN ('default', 'vlc_desktop', 'exo_player', 'browser_mobile'))`
    - `verified_at timestamptz`
    - `created_at timestamptz NOT NULL DEFAULT now()`
    - `updated_at timestamptz NOT NULL DEFAULT now()`
    - `deleted_at timestamptz`
    - **Constraints Estrictas y Uniformes de Seguridad en `sources`:**
      - `CHECK ((title_id IS NOT NULL AND episode_id IS NULL) OR (title_id IS NULL AND episode_id IS NOT NULL))`
      - Validación uniforme en `url`, `referer_url` y `origin_url` (exigiendo estrictamente `^https://`, sin excepciones HTTP, sin loopback, sin IPs privadas, sin credenciales de usuario ni tokens sensibles):
        ```sql
        CHECK (
          url ~* '^https://'
          AND url !~* '^(https://)?([^/@]+@)'
          AND url !~* '^(https://)?(localhost|127\.|0\.0\.0\.0|\[::1\])'
          AND url !~* '^(https://)?(10\.|172\.(1[6-9]|2[0-9]|3[0-1])\.|192\.168\.|169\.254\.|\[fe80:)'
          AND url !~* '(\?|&|#)(token|api_key|secret|auth|cookie|jwt)='
        )
        ```
      - Validación de `referer_url`:
        ```sql
        CHECK (
          referer_url IS NULL OR (
            referer_url ~* '^https://'
            AND referer_url !~* '^(https://)?([^/@]+@)'
            AND referer_url !~* '^(https://)?(localhost|127\.|0\.0\.0\.0|\[::1\])'
            AND referer_url !~* '^(https://)?(10\.|172\.(1[6-9]|2[0-9]|3[0-1])\.|192\.168\.|169\.254\.|\[fe80:)'
            AND referer_url !~* '(\?|&|#)(token|api_key|secret|auth|cookie|jwt)='
          )
        )
        ```
      - Validación de `origin_url` (estrictamente esquema y host sin ruta, query ni fragmento):
        ```sql
        CHECK (
          origin_url IS NULL OR (
            origin_url ~* '^https://[a-zA-Z0-9.-]+(:[0-9]+)?$'
            AND origin_url !~* '^(https://)?([^/@]+@)'
            AND origin_url !~* '^(https://)?(localhost|127\.|0\.0\.0\.0|\[::1\])'
            AND origin_url !~* '^(https://)?(10\.|172\.(1[6-9]|2[0-9]|3[0-1])\.|192\.168\.|169\.254\.|\[fe80:)'
          )
        )
        ```
- Tabla Pública de Registro de Cambios (`public.catalog_changes`):
  ```sql
  CREATE TABLE public.catalog_changes (
    revision bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    entity_type public.catalog_entity_type NOT NULL,
    entity_id text NOT NULL,
    operation text NOT NULL CHECK (operation IN ('upsert', 'delete')),
    changed_at timestamptz NOT NULL DEFAULT now()
  );
  CREATE INDEX idx_catalog_changes_revision ON public.catalog_changes (revision ASC);
  ```
- Tabla de Metadatos de Sincronización y Retención (`public.catalog_sync_metadata`):
  ```sql
  CREATE TABLE public.catalog_sync_metadata (
    id int PRIMARY KEY DEFAULT 1 CHECK (id = 1),
    minimum_available_revision bigint NOT NULL DEFAULT 1,
    latest_revision bigint NOT NULL DEFAULT 0,
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT chk_revision_invariants CHECK (minimum_available_revision <= latest_revision OR latest_revision = 0)
  );
  ```
- **Blindaje Estricto de Funciones y Triggers de PostgreSQL:**

  **Principios y Directrices Obligatorias:**
  1. **Revocación inmediata tras creación:**
     Inmediatamente después de crear cada función del catálogo (administrativa, de trigger o auxiliar), se ejecuta obligatoriamente:
     ```sql
     REVOKE ALL ON FUNCTION public.<nombre_funcion>(<argumentos>) FROM PUBLIC;
     REVOKE ALL ON FUNCTION public.<nombre_funcion>(<argumentos>) FROM anon;
     REVOKE ALL ON FUNCTION public.<nombre_funcion>(<argumentos>) FROM authenticated;
     ```
     Esto incluye obligatoriamente a:
     - `public.compact_catalog_changes(bigint)`
     - `public.fn_update_catalog_sync_metadata_latest()`
     - `public.fn_catalog_changes_titles()`
     - `public.fn_catalog_changes_seasons()`
     - `public.fn_catalog_changes_episodes()`
     - `public.fn_catalog_changes_sources()`
     - `public.fn_catalog_changes_title_genres()`
     - `public.fn_catalog_changes_genres()`
     - `public.fn_catalog_changes_languages()`
     - Cualquier función auxiliar administrativa futura.
  2. **Carácter exclusivamente administrativo de `compact_catalog_changes(bigint)`:**
     - No conceder `EXECUTE` a `anon` ni `authenticated`.
     - No exponerla como RPC utilizable por la APK en PostgREST (bloqueada para clientes).
     - Ejecutarla únicamente mediante conexión administrativa local (`127.0.0.1:54322` autenticado como superusuario/propietario `postgres`) o backend confiable futuro.
  3. **Requisitos para funciones `SECURITY DEFINER` (ej. `compact_catalog_changes`):**
     - Usar obligatoriamente `SET search_path = ''`.
     - Referenciar todas las tablas y funciones con nombres totalmente calificados `public.*`.
     - Evitar terminantemente SQL dinámico (`EXECUTE format(...)`), utilizando únicamente SQL estático parametrizado.
     - Fijar propietario administrativo: `ALTER FUNCTION ... OWNER TO postgres;`.
     - Revocar `EXECUTE` de `PUBLIC`, `anon` y `authenticated` antes de cualquier `GRANT` explícito (sin otorgar ninguno a roles de cliente).
  4. **Requisitos para funciones trigger:**
     - Usar obligatoriamente `SET search_path = ''` y objetos totalmente calificados (`public.*`) para impedir ataques de secuestro por resolución de nombres.
     - Fijar propietario administrativo: `ALTER FUNCTION ... OWNER TO postgres;`.
     - Revocar todos los privilegios a `PUBLIC`, `anon` y `authenticated` tras su creación. Los triggers operan internamente en el contexto del DML administrativo sin requerir privilegios directos de ejecución para roles de cliente.

  **Definiciones SQL Completas de Funciones y Triggers:**
  ```sql
  -- 1. Función Trigger: Actualización automática de latest_revision
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

  CREATE TRIGGER trg_catalog_changes_update_latest
  AFTER INSERT ON public.catalog_changes
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_update_catalog_sync_metadata_latest();

  -- 2. Función Administrativa: Compactación transaccional de revisiones
  -- Exclusivamente administrativa: no se concede EXECUTE a anon ni authenticated
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

  -- 3. Función Trigger: catalog_changes en titles (anti-filtraciones)
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
      -- Si pasa de privado/borrador a público: emite upsert para el título y sus entidades dependientes activas
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

      -- Si permanece público y se actualiza: emite upsert
      ELSIF (OLD.is_published = true AND OLD.deleted_at IS NULL) AND (NEW.is_published = true AND NEW.deleted_at IS NULL) THEN
        INSERT INTO public.catalog_changes (entity_type, entity_id, operation, changed_at)
        VALUES ('title', NEW.id::text, 'upsert', now());

      -- Si pasa de público a privado o se marca con deleted_at: emite delete (tombstone)
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

  CREATE TRIGGER trg_catalog_changes_titles
  AFTER INSERT OR UPDATE OR DELETE ON public.titles
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_catalog_changes_titles();

  -- 4. Función Trigger: catalog_changes en seasons (condicionado a título publicado)
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

  CREATE TRIGGER trg_catalog_changes_seasons
  AFTER INSERT OR UPDATE OR DELETE ON public.seasons
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_catalog_changes_seasons();

  -- 5. Función Trigger: catalog_changes en episodes (condicionado a título y temporada públicos)
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

  CREATE TRIGGER trg_catalog_changes_episodes
  AFTER INSERT OR UPDATE OR DELETE ON public.episodes
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_catalog_changes_episodes();

  -- 6. Función Trigger: catalog_changes en sources (condicionado a título raíz público)
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

  CREATE TRIGGER trg_catalog_changes_sources
  AFTER INSERT OR UPDATE OR DELETE ON public.sources
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_catalog_changes_sources();

  -- 7. Función Trigger: catalog_changes en title_genres (identidad determinista title_id:genre_id)
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

  CREATE TRIGGER trg_catalog_changes_title_genres
  AFTER INSERT OR DELETE ON public.title_genres
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_catalog_changes_title_genres();

  -- 8. Función Trigger: catalog_changes en genres
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

  CREATE TRIGGER trg_catalog_changes_genres
  AFTER INSERT OR UPDATE OR DELETE ON public.genres
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_catalog_changes_genres();

  -- 9. Función Trigger: catalog_changes en languages
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

  CREATE TRIGGER trg_catalog_changes_languages
  AFTER INSERT OR UPDATE OR DELETE ON public.languages
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_catalog_changes_languages();
  ```
- Índices PostgreSQL:
  1. `idx_titles_media_tmdb`: `UNIQUE (media_type, tmdb_id) WHERE tmdb_id IS NOT NULL AND deleted_at IS NULL`.
  2. `idx_titles_imdb`: `UNIQUE (imdb_id) WHERE imdb_id IS NOT NULL AND deleted_at IS NULL`.
  3. `idx_titles_cursor_comp`: `(created_at DESC, id DESC) WHERE is_published = true AND deleted_at IS NULL`.
  4. `idx_titles_cursor_year`: `(year DESC, id DESC) WHERE is_published = true AND deleted_at IS NULL`.
  5. `idx_titles_type_cursor`: `(media_type, created_at DESC, id DESC) WHERE is_published = true AND deleted_at IS NULL`.
  6. `idx_titles_featured`: `(created_at DESC) WHERE is_featured = true AND is_published = true AND deleted_at IS NULL`.
  7. `idx_titles_search_trgm`: `USING gin (normalized_title gin_trgm_ops) WHERE is_published = true AND deleted_at IS NULL`.
  8. `idx_title_genres_lookup`: `(genre_id, title_id)`.
  9. `idx_episodes_lookup`: `(season_id, episode_number)`.
  10. `idx_sources_title`: `(title_id, order_index ASC)`.
  11. `idx_sources_episode`: `(episode_id, order_index ASC)`.
- Vista de Resúmenes de Tarjetas (`public.title_summaries`):
  `CREATE VIEW public.title_summaries WITH (security_invoker = true) AS ...`
  Expone `id`, `legacy_id`, `title`, `normalized_title`, `media_type`, `poster_url`, `backdrop_url`, `year`, `rating`, `is_featured`, `created_at` y géneros asociados.
- Revocación de Privilegios y Cadena de Políticas RLS:
  - Revocación explícita a `PUBLIC`:
    `REVOKE ALL ON public.titles, public.genres, public.title_genres, public.seasons, public.episodes, public.languages, public.sources, public.catalog_changes, public.catalog_sync_metadata, public.title_summaries FROM PUBLIC;`
  - Concesión exclusiva de lectura:
    `GRANT SELECT ON public.titles, public.genres, public.title_genres, public.seasons, public.episodes, public.languages, public.sources, public.catalog_changes, public.catalog_sync_metadata, public.title_summaries TO anon, authenticated;`
  - Activación de RLS en todas las tablas (`ALTER TABLE ... ENABLE ROW LEVEL SECURITY;`).
  - Políticas de lectura:
    - `titles`: `USING (is_published = true AND deleted_at IS NULL)`.
    - `seasons`: `USING (EXISTS (SELECT 1 FROM public.titles t WHERE t.id = seasons.title_id AND t.is_published = true AND t.deleted_at IS NULL))`.
    - `episodes`: `USING (EXISTS (SELECT 1 FROM public.seasons s JOIN public.titles t ON t.id = s.title_id WHERE s.id = episodes.season_id AND t.is_published = true AND t.deleted_at IS NULL))`.
    - `sources`:
      - Si `title_id IS NOT NULL`: verifica que `titles` cumpla publicado y no eliminado.
      - Si `episode_id IS NOT NULL`: verifica la cadena `source -> episode -> season -> title` publicado y no eliminado.
    - `title_genres`: `USING (EXISTS (SELECT 1 FROM public.titles t WHERE t.id = title_genres.title_id AND t.is_published = true AND t.deleted_at IS NULL))`.
    - `genres` y `languages`: `USING (true)`.
    - `catalog_changes`: `USING (true)` (seguro porque los triggers garantizan que solo contiene eventos de contenido público).
    - `catalog_sync_metadata`: `USING (true)`.

- [ ] **Paso 1: Escribir la prueba pgTAP en `supabase/tests/catalog_schema_rls.test.sql`**
  Definir pruebas estrictas para:
  - Estructura de tablas, constraints de unicidad y constraints de seguridad de URLs en `url`, `referer_url` y `origin_url` (IPv6 loopback `[::1]`, IP privada `192.168.1.1`, credenciales embebidas `user:pass@`, tokens en query y `origin_url` con path deben ser rechazados con error de constraint).
  - Reglas anti-filtración en `catalog_changes`:
    - Insertar título con `is_published = false` no inserta nada en `catalog_changes`.
    - Insertar episodios/fuentes para un título no publicado no inserta nada en `catalog_changes`.
    - Pasar el título a `is_published = true` emite `upsert` para el título y sus entidades dependientes.
    - Borrar un título público emite `delete` tombstone.
    - Borrar un título que siempre fue privado no emite nada en `catalog_changes`.
  - Actualización automática de `latest_revision` en `catalog_sync_metadata`.
  - Invariante `minimum_available_revision <= latest_revision` y ejecución de `compact_catalog_changes`.
  - **Pruebas de Seguridad en Funciones de PostgreSQL y Protección de Metadatos:**
    Implementar en `supabase/tests/catalog_schema_rls.test.sql` el bloque específico de pruebas pgTAP:
    ```sql
    -- 1. Test: anon no puede ejecutar compact_catalog_changes (42501 permission denied)
    set local role anon;
    select throws_ok(
      $$ select public.compact_catalog_changes(1000) $$,
      '42501', null,
      'anon role cannot execute compact_catalog_changes'
    );

    -- 2. Test: authenticated no puede ejecutar compact_catalog_changes (42501 permission denied)
    set local role authenticated;
    select throws_ok(
      $$ select public.compact_catalog_changes(1000) $$,
      '42501', null,
      'authenticated role cannot execute compact_catalog_changes'
    );

    -- 3. Test: PUBLIC, anon y authenticated no conservan EXECUTE en ninguna función del catálogo
    select hasnt_function_privilege('public', 'public.compact_catalog_changes(bigint)', 'execute',
      'PUBLIC does not retain EXECUTE on compact_catalog_changes');
    select hasnt_function_privilege('public', 'public.fn_update_catalog_sync_metadata_latest()', 'execute',
      'PUBLIC does not retain EXECUTE on fn_update_catalog_sync_metadata_latest');
    select hasnt_function_privilege('public', 'public.fn_catalog_changes_titles()', 'execute',
      'PUBLIC does not retain EXECUTE on fn_catalog_changes_titles');
    select hasnt_function_privilege('public', 'public.fn_catalog_changes_seasons()', 'execute',
      'PUBLIC does not retain EXECUTE on fn_catalog_changes_seasons');
    select hasnt_function_privilege('public', 'public.fn_catalog_changes_episodes()', 'execute',
      'PUBLIC does not retain EXECUTE on fn_catalog_changes_episodes');
    select hasnt_function_privilege('public', 'public.fn_catalog_changes_sources()', 'execute',
      'PUBLIC does not retain EXECUTE on fn_catalog_changes_sources');
    select hasnt_function_privilege('public', 'public.fn_catalog_changes_title_genres()', 'execute',
      'PUBLIC does not retain EXECUTE on fn_catalog_changes_title_genres');
    select hasnt_function_privilege('public', 'public.fn_catalog_changes_genres()', 'execute',
      'PUBLIC does not retain EXECUTE on fn_catalog_changes_genres');
    select hasnt_function_privilege('public', 'public.fn_catalog_changes_languages()', 'execute',
      'PUBLIC does not retain EXECUTE on fn_catalog_changes_languages');

    select hasnt_function_privilege('anon', 'public.compact_catalog_changes(bigint)', 'execute',
      'anon does not have EXECUTE on compact_catalog_changes');
    select hasnt_function_privilege('authenticated', 'public.compact_catalog_changes(bigint)', 'execute',
      'authenticated does not have EXECUTE on compact_catalog_changes');
    select hasnt_function_privilege('anon', 'public.fn_update_catalog_sync_metadata_latest()', 'execute',
      'anon does not have EXECUTE on fn_update_catalog_sync_metadata_latest');
    select hasnt_function_privilege('authenticated', 'public.fn_update_catalog_sync_metadata_latest()', 'execute',
      'authenticated does not have EXECUTE on fn_update_catalog_sync_metadata_latest');

    -- 4. Test: Los triggers continúan funcionando durante escrituras administrativas (role postgres)
    reset role; -- Superusuario / conexión administrativa local
    insert into public.titles (id, media_type, title, normalized_title, is_published)
    values ('aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee', 'movie', 'Admin Write Trigger Test', 'admin write trigger test', true);

    select is(
      (select count(*)::int from public.catalog_changes
       where entity_type = 'title' and entity_id = 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee' and operation = 'upsert'),
      1,
      'trigger fn_catalog_changes_titles fired successfully during admin write'
    );

    select is(
      (select latest_revision from public.catalog_sync_metadata where id = 1),
      (select max(revision) from public.catalog_changes),
      'trigger fn_update_catalog_sync_metadata_latest updated latest_revision during admin write'
    );

    -- 5. Test: Ningún usuario cliente puede modificar catalog_sync_metadata directa o indirectamente
    -- Intentos de modificación directa por anon:
    set local role anon;
    select throws_ok(
      $$ update public.catalog_sync_metadata set latest_revision = 999999 where id = 1 $$,
      '42501', null,
      'anon cannot directly update catalog_sync_metadata'
    );
    select throws_ok(
      $$ insert into public.catalog_sync_metadata (id, minimum_available_revision, latest_revision) values (2, 1, 1) $$,
      '42501', null,
      'anon cannot directly insert into catalog_sync_metadata'
    );
    select throws_ok(
      $$ delete from public.catalog_sync_metadata where id = 1 $$,
      '42501', null,
      'anon cannot directly delete from catalog_sync_metadata'
    );

    -- Intentos de modificación directa por authenticated:
    set local role authenticated;
    select throws_ok(
      $$ update public.catalog_sync_metadata set latest_revision = 999999 where id = 1 $$,
      '42501', null,
      'authenticated cannot directly update catalog_sync_metadata'
    );
    select throws_ok(
      $$ insert into public.catalog_sync_metadata (id, minimum_available_revision, latest_revision) values (2, 1, 1) $$,
      '42501', null,
      'authenticated cannot directly insert into catalog_sync_metadata'
    );
    select throws_ok(
      $$ delete from public.catalog_sync_metadata where id = 1 $$,
      '42501', null,
      'authenticated cannot directly delete from catalog_sync_metadata'
    );

    -- Intentos de modificación indirecta (insertar directamente en catalog_changes para manipular metadata):
    select throws_ok(
      $$ insert into public.catalog_changes (entity_type, entity_id, operation) values ('title', 'tamper', 'upsert') $$,
      '42501', null,
      'authenticated cannot insert into catalog_changes (indirect metadata tampering blocked)'
    );
    set local role anon;
    select throws_ok(
      $$ insert into public.catalog_changes (entity_type, entity_id, operation) values ('title', 'tamper', 'upsert') $$,
      '42501', null,
      'anon cannot insert into catalog_changes (indirect metadata tampering blocked)'
    );
    ```
  - Paginación determinista con múltiples registros con el mismo `created_at`.
  - Comprobar que `title_summaries` nunca entrega registros despublicados o eliminados.
  - Probar que `anon` y `authenticated` no pueden ejecutar `INSERT`, `UPDATE` o `DELETE` en ninguna tabla.

- [ ] **Paso 2: Ejecutar la prueba y verificar que falle antes de la migración**
  Comando: `npx -y supabase test db supabase/tests/catalog_schema_rls.test.sql`
  Resultado esperado: FAIL.

- [ ] **Paso 3: Generar la migración con la CLI, capturar la ruta exacta y aplicar el esquema**
  Ejecutar:
  ```powershell
  npx -y supabase migration new create_catalog_schema
  ```
  Capturar el archivo exacto generado en `supabase/migrations/` (ejemplo: `supabase/migrations/20260910123000_create_catalog_schema.sql`).
  Implementar el DDL completo, triggers anti-filtración, extensiones (`pg_trgm`, `unaccent`), vistas, constraints, funciones blindadas con `SET search_path = ''` y RLS.
  Actualizar `supabase/seed.sql` con géneros e idiomas iniciales y metadatos de sincronización (`catalog_sync_metadata`).

- [ ] **Paso 4: Ejecutar reset, pruebas de base de datos y asesores**
  Comandos:
  ```powershell
  npx -y supabase db reset
  npx -y supabase test db supabase/tests/catalog_schema_rls.test.sql
  npx -y supabase test db
  npx -y supabase db advisors
  npx -y supabase migration list --local
  ```
  Resultado esperado: Todas las pruebas (incluidas las 13 de la Fase 2 más las nuevas) pasan al 100% y los asesores reportan 0 problemas.

- [ ] **Paso 5: Commit atómico de la Tarea 1 usando la ruta exacta capturada**
  ```bash
  # Usar la ruta real capturada sin comodines:
  git add supabase/migrations/<generated_timestamp>_create_catalog_schema.sql supabase/tests/catalog_schema_rls.test.sql supabase/seed.sql
  git commit -m "feat(catalog): crear esquema normalizado, funciones blindadas, catalog_changes y rls en supabase"
  ```

---

### Task 2: Base de Datos Local Indexada en Flutter con Drift (SQLite en Background y Búsqueda FTS5 Sanitizada)

**Archivos:**
- Modificar: `pubspec.yaml`
- Modificar: `pubspec.lock`
- Crear: `lib/database/catalog_database.dart`
- Crear: `lib/database/tables/catalog_tables.dart`
- Crear: `lib/database/daos/catalog_dao.dart`
- Crear: `test/database/catalog_database_test.dart`

**Configuración y Dependencias:**
- En `pubspec.yaml`:
  - `drift: 2.35.0`
  - `drift_flutter: 0.3.1`
  - dev: `drift_dev: 2.35.0`
  - dev: `build_runner: 2.16.1`
  - (No incluir `sqlite3_flutter_libs`).
- Conexión en Isolate Dedicado:
  `NativeDatabase.createInBackground(file)` en producción para aislar I/O y consultas fuera del hilo de UI.
  `NativeDatabase.memory()` para pruebas unitarias rápidas.

**Tablas Drift y FTS5 (`lib/database/tables/catalog_tables.dart`):**
- `LocalTitles`: `id (TextColumn)`, `legacyId (TextColumn, nullable)`, `mediaType (TextColumn)`, `title (TextColumn)`, `originalTitle (TextColumn, nullable)`, `normalizedTitle (TextColumn)`, `plot (TextColumn, nullable)`, `year (IntColumn, nullable)`, `rating (RealColumn, nullable)`, `duration (TextColumn, nullable)`, `posterUrl (TextColumn, nullable)`, `backdropUrl (TextColumn, nullable)`, `isFeatured (BoolColumn)`, `castMembers (TextColumn, nullable)`, `director (TextColumn, nullable)`, `writer (TextColumn, nullable)`, `countryCode (TextColumn, nullable)`, `tmdbId (IntColumn, nullable)`, `imdbId (TextColumn, nullable)`, `createdAt (DateTimeColumn)`, `updatedAt (DateTimeColumn)`, `isDeleted (BoolColumn, default false)`.
  - Índices B-tree: `(createdAt, id)`, `(year, id)`, `(mediaType, createdAt)`.
- `LocalGenres`: `id (TextColumn)`, `name (TextColumn)`, `slug (TextColumn)`.
- `LocalLanguages`: `id (TextColumn)`, `code (TextColumn)`, `name (TextColumn)`.
- `LocalTitleGenres`: `titleId (TextColumn)`, `genreId (TextColumn)`. Clave compuesta.
- `LocalSeasons`: `id (TextColumn)`, `titleId (TextColumn)`, `seasonNumber (IntColumn)`, `name (TextColumn, nullable)`, `plot (TextColumn, nullable)`, `posterUrl (TextColumn, nullable)`.
- `LocalEpisodes`: `id (TextColumn)`, `seasonId (TextColumn)`, `episodeNumber (IntColumn)`, `title (TextColumn)`, `plot (TextColumn, nullable)`, `duration (TextColumn, nullable)`, `stillUrl (TextColumn, nullable)`.
- `LocalSources`: `id (TextColumn)`, `titleId (TextColumn, nullable)`, `episodeId (TextColumn, nullable)`, `name (TextColumn)`, `url (TextColumn)`, `language (TextColumn, nullable)`, `orderIndex (IntColumn)`, `status (TextColumn)`, `requiresWebview (BoolColumn)`, `refererUrl (TextColumn, nullable)`, `originUrl (TextColumn, nullable)`, `userAgentProfile (TextColumn, nullable)`.
- `CatalogSyncState`:
  ```dart
  class CatalogSyncStates extends Table {
    TextColumn get syncKey => text()();
    // IntColumn mapea a int de Dart (64 bits con signo) soportando revisiones > 2^31
    IntColumn get lastCatalogRevision => integer().withDefault(const Constant(0))();
    DateTimeColumn get lastSyncTimestamp => dateTime()();
    IntColumn get totalSynced => integer().withDefault(const Constant(0))();
    @override
    Set<Column> get primaryKey => {syncKey};
  }
  ```
- **Estrategia FTS5 para Búsqueda Indexada:**
  Tabla virtual FTS5 ejecutada mediante instrucción personalizada o migración Drift:
  ```sql
  CREATE VIRTUAL TABLE IF NOT EXISTS local_titles_fts USING fts5(
    title_id UNINDEXED,
    normalized_title,
    original_title,
    search_terms,
    tokenize='unicode61 remove_diacritics 2'
  );
  ```
  Triggers automáticos en SQLite para mantener sincronizado `local_titles_fts` ante inserciones, actualizaciones y borrados en `local_titles`.

- **Sanitización de Consultas FTS5 (`sanitizeFts5Query`):**
  Para evitar inyecciones de sintaxis o fallos de parser en SQLite FTS5:
  ```dart
  String sanitizeFts5Query(String rawQuery) {
    if (rawQuery.trim().isEmpty) return '';
    final normalized = HourTvGenreService.normalize(rawQuery);
    final sanitizedText = normalized
        .replaceAll(RegExp(r'["*^(){}:+\-]'), ' ')
        .replaceAll(RegExp(r'\b(AND|OR|NOT|NEAR)\b', caseSensitive: false), ' ');
    final tokens = sanitizedText
        .split(RegExp(r'\s+'))
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty && RegExp(r'^[a-z0-9]+$').hasMatch(t))
        .take(10)
        .map((t) => t.length > 50 ? t.substring(0, 50) : t)
        .toList();
    if (tokens.isEmpty) return '';
    return tokens.map((t) => '$t*').join(' ');
  }
  ```
  Búsqueda parametrizada:
  `customSelect('SELECT title_id FROM local_titles_fts WHERE local_titles_fts MATCH :matchQuery', variables: [Variable.withString(safeQuery)])`

**Operaciones del DAO (`CatalogDao`):**
- `Future<void> upsertTitles(List<LocalTitleCompanion> titles)`
- `Future<void> upsertGenres(List<LocalGenreCompanion> genres)`
- `Future<void> upsertLanguages(List<LocalLanguageCompanion> languages)`
- `Future<void> linkTitleGenres(List<LocalTitleGenreCompanion> links)`
- `Future<void> unlinkTitleGenre(String titleId, String genreId)`
- `Future<void> applyTombstone(String entityType, String entityId)`:
  - Si `entityType == 'title'`: marca `isDeleted = true` en `LocalTitles` y elimina de `local_titles_fts`.
  - Si `entityType == 'title_genre'`: descompone `entityId` en `[titleId, genreId]` y ejecuta `unlinkTitleGenre`.
  - Si `entityType == 'source'`: elimina de `LocalSources`.
  - Si `entityType == 'episode'`: elimina de `LocalEpisodes`.
  - Si `entityType == 'season'`: elimina de `LocalSeasons`.
  - Si `entityType == 'genre'`: elimina de `LocalGenres`.
  - Si `entityType == 'language'`: elimina de `LocalLanguages`.
- `Future<List<LocalTitle>> searchTitlesFts({required String rawQuery, String? mediaType, String? genreSlug, int limit = 20})`
- `Future<void> applySyncBatchAtomic({required List<SyncDeltaItem> items, required int newRevision, required DateTime timestamp})`
- `Future<int> getLastCatalogRevision(String syncKey)`
- `Future<void> replaceEntireCatalogAtomic(...)` (para el caso de Full Resync si el cliente está por debajo de `minimum_available_revision`).

- [ ] **Paso 1: Escribir pruebas unitarias en `test/database/catalog_database_test.dart`**
  Probar:
  - Almacenamiento y recuperación de `lastCatalogRevision` con valor superior a `2^31` (ej. `5000000000`) demostrando ausencia de overflow.
  - Sanitización FTS5: comillas dobles, asteriscos sueltos, operadores `OR`/`NEAR`, guiones, emojis y cadenas vacías se manejan de forma segura sin generar errores de sintaxis en SQLite.
  - Búsqueda FTS5 con acentos y mayúsculas (`MATCH 'arbol*'` encuentra `Árbol de la vida`).
  - Sincronización automática de FTS5 al actualizar o borrar títulos.
  - Paginación determinista con cursor `(createdAt, id)` con registros de idéntica fecha.
  - Aplicación de lápidas para clave compuesta `title_genre` (`entity_id = 't1:g1'`).
  - Transacción atómica de lote: simular fallo a mitad del proceso y comprobar que el checkpoint de revisión no avanza.

- [ ] **Paso 2: Ejecutar la prueba y verificar que falle**
  Comando: `flutter test test/database/catalog_database_test.dart`
  Resultado esperado: FAIL.

- [ ] **Paso 3: Añadir dependencias en `pubspec.yaml`, generar código Drift e implementar tablas, FTS5 y DAO**
  Añadir dependencias exactas en `pubspec.yaml`.
  Ejecutar:
  ```powershell
  flutter pub get
  dart run build_runner build --delete-conflicting-outputs
  ```
  Implementar `catalog_tables.dart`, `catalog_database.dart` y `catalog_dao.dart`.

- [ ] **Paso 4: Ejecutar las pruebas unitarias y análisis estático**
  Comandos:
  ```powershell
  flutter test test/database/catalog_database_test.dart
  flutter analyze
  ```
  Resultado esperado: Pruebas pasando al 100% y 0 errores de análisis.

- [ ] **Paso 5: Commit atómico de la Tarea 2**
  ```bash
  git add pubspec.yaml pubspec.lock lib/database/ test/database/
  git commit -m "feat(catalog): implementar drift con background isolate, fts5 sanitizado y revisiones de 64 bits"
  ```

---

### Task 3: Gateway Supabase con Paginación por Cursor Compuesta, DTOs y Metadatos de Sincronización

**Archivos:**
- Crear: `lib/services/catalog/supabase_catalog_gateway.dart`
- Crear: `lib/services/catalog/catalog_dtos.dart`
- Crear: `lib/services/catalog/catalog_cursor.dart`
- Crear: `test/services/catalog/supabase_catalog_gateway_test.dart`

**Interfaces y Estructuras en Dart:**
- `CatalogCursor`:
  - `final DateTime createdAt; final String id;`
  - `String encode()` -> base64url con formato `createdAt_iso|id`.
  - `static CatalogCursor? tryDecode(String? encoded)`.
- `CatalogSummaryDto`:
  - `id`, `legacyId`, `title`, `normalizedTitle`, `mediaType`, `posterUrl`, `backdropUrl`, `year`, `rating`, `isFeatured`, `createdAt`, `genres` (`List<String>`).
- `CatalogChangeDto`:
  - `final int revision; final String entityType; final String entityId; final String operation; final DateTime changedAt;`
- `CatalogSyncMetadataDto`:
  - `final int minimumAvailableRevision; final int latestRevision;`
- `SupabaseCatalogGateway`:
  - Consulta paginada con filtro compuesto:
    `.or('created_at.lt.${cursor.createdAt.toIso8601String()},and(created_at.eq.${cursor.createdAt.toIso8601String()},id.lt.${cursor.id})')`
    con `.order('created_at', ascending: false).order('id', ascending: false)`.
  - Métodos:
    - `Future<CatalogPageResult<CatalogSummaryDto>> fetchTitlesPage({CatalogCursor? cursor, int limit = 20, String? mediaType, String? genreSlug, CatalogSortOrder sort})`
    - `Future<CatalogDetailDto?> fetchTitleDetails(String titleId)`
    - `Future<List<CatalogSourceDto>> fetchTitleSources(String titleId)`
    - `Future<List<CatalogSeasonDto>> fetchSeriesEpisodes(String titleId)`
    - `Future<List<CatalogChangeDto>> fetchChanges({required int sinceRevision, int limit = 200})`
    - `Future<CatalogSyncMetadataDto> fetchSyncMetadata()`
    - `Future<List<CatalogSummaryDto>> fetchCompleteSnapshot({int offset = 0, int limit = 500})`

- [ ] **Paso 1: Escribir pruebas unitarias con mock de PostgREST en `test/services/catalog/supabase_catalog_gateway_test.dart`**
  Probar:
  - Generación de filtros de cursor compuesto en PostgREST (`or(created_at.lt...,and(created_at.eq...,id.lt...))`).
  - Mapeo de `catalog_changes` (incluyendo `genre`, `language` y claves compuestas `title_genre`).
  - Obtención de `catalog_sync_metadata` (`minimumAvailableRevision`, `latestRevision`).
  - Manejo de excepciones de red (`CatalogNetworkException`).

- [ ] **Paso 2: Ejecutar la prueba y verificar que falle**
  Comando: `flutter test test/services/catalog/supabase_catalog_gateway_test.dart`
  Resultado esperado: FAIL.

- [ ] **Paso 3: Implementar `CatalogCursor`, DTOs y `SupabaseCatalogGateway`**
  Desarrollar los archivos en `lib/services/catalog/`.

- [ ] **Paso 4: Ejecutar las pruebas del gateway y análisis estático**
  Comandos:
  ```powershell
  flutter test test/services/catalog/supabase_catalog_gateway_test.dart
  flutter analyze
  ```
  Resultado esperado: Pruebas pasando al 100%.

- [ ] **Paso 5: Commit atómico de la Tarea 3**
  ```bash
  git add lib/services/catalog/catalog_cursor.dart lib/services/catalog/catalog_dtos.dart lib/services/catalog/supabase_catalog_gateway.dart test/services/catalog/supabase_catalog_gateway_test.dart
  git commit -m "feat(catalog): implementar gateway supabase con cursor compuesto, metadatos y dtos"
  ```

---

### Task 4: Motor de Sincronización Incremental con Checkpoint Transaccional y Recuperación por Compactación

**Archivos:**
- Crear: `lib/services/catalog/catalog_sync_engine.dart`
- Crear: `lib/services/catalog/sync_models.dart`
- Crear: `test/services/catalog/catalog_sync_engine_test.dart`

**Lógica Robusta del Motor de Sincronización:**
1. **Verificación de Retención y Compactación:**
   - Consulta `fetchSyncMetadata()`.
   - Lee `lastCatalogRevision` local.
   - Si `lastCatalogRevision > 0` y `lastCatalogRevision < metadata.minimumAvailableRevision`:
     - El cliente está desfasado y sus revisiones fueron compactadas en el servidor.
     - Dispara `performFullResync()`: descarga el snapshot publicado por lotes y reemplaza atómicamente las tablas de catálogo en Drift dentro de una sola transacción, **conservando intactas las tablas de favoritos e historial**.
     - Actualiza `lastCatalogRevision = metadata.latestRevision` y culmina el ciclo.
2. **Sincronización Incremental Normal:**
   - Consulta `fetchChanges(sinceRevision: lastCatalogRevision, limit: 200)`.
   - Si no hay cambios, termina.
   - Captura el `high-water revision` del lote (el mayor `revision` presente en la lista).
   - Para cada elemento:
     - Si `operation == 'delete'`: prepara la eliminación local (`applyTombstone`).
     - Si `operation == 'upsert'`: consulta los detalles actuales de la entidad. Si la entidad ya no existe en el servidor (despublicada o eliminada concurrentemente), se trata de forma idempotente como `tombstone` local.
   - **Aplicación Atómica del Checkpoint:**
     - En una única transacción Drift:
       `dao.applySyncBatchAtomic(items: entities, newRevision: batchHighWaterRevision, timestamp: now)`
     - Si ocurre cualquier error, la transacción revierte por completo y `lastCatalogRevision` no avanza.
   - Si el lote alcanzó el límite de 200, itera inmediatamente para procesar los cambios subsiguientes.
   - Cambios generados en el servidor después de la consulta pertenecerán a `revision > batchHighWaterRevision` y quedarán para la siguiente corrida.

- [ ] **Paso 1: Escribir pruebas unitarias en `test/services/catalog/catalog_sync_engine_test.dart`**
  Probar:
  - Falla en medio de un lote: el checkpoint de revisión no se mueve.
  - Entidad con `upsert` que fue borrada concurrentemente en el backend: tratada idempotentemente como lápida sin abortar el lote.
  - Repetición de un lote previo: verificación de idempotencia sin duplicados.
  - Cliente con revisión compactada (`lastCatalogRevision < minimumAvailableRevision`): se dispara resincronización completa automática, reemplazando el catálogo y preservando favoritos/progreso.

- [ ] **Paso 2: Ejecutar la prueba y verificar que falle**
  Comando: `flutter test test/services/catalog/catalog_sync_engine_test.dart`
  Resultado esperado: FAIL.

- [ ] **Paso 3: Implementar `CatalogSyncEngine` y modelos de sincronización**
  Desarrollar `sync_models.dart` y `catalog_sync_engine.dart`.

- [ ] **Paso 4: Ejecutar pruebas del motor de sincronización y análisis estático**
  Comandos:
  ```powershell
  flutter test test/services/catalog/catalog_sync_engine_test.dart
  flutter analyze
  ```
  Resultado esperado: Pruebas unitarias pasando al 100%.

- [ ] **Paso 5: Commit atómico de la Tarea 4**
  ```bash
  git add lib/services/catalog/catalog_sync_engine.dart lib/services/catalog/sync_models.dart test/services/catalog/catalog_sync_engine_test.dart
  git commit -m "feat(catalog): implementar sincronizacion incremental con checkpoint transaccional y full resync"
  ```

---

### Task 5: Repositorio Resiliente con Caché Local, Fallback a JSON y Compatibilidad Focalizada

**Archivos:**
- Crear: `lib/services/catalog/catalog_repository.dart`
- Modificar: `lib/services/content_store.dart`
- Crear: `test/services/catalog/catalog_repository_test.dart`
- Crear: `test/content_store_catalog_test.dart`

**Definición de Compatibilidad y Responsabilidades:**
- **Consumidores con Compatibilidad Temporal en `ContentStore`:**
  - Canales de televisión en directo (listas M3U de usuario, portales Stalker, cuentas Xtream para TV en vivo) continúan administrados por `ContentStore` (`all` filtrado a `MediaType.live`, `countries`, EPG).
- **Consumidores que Migran a Consultas Paginadas Drift:**
  - Filas de Inicio y Cuadrícula de Búsqueda: consumen directamente `CatalogRepository` / `CatalogDao`.
  - "Continuar viendo" y "Favoritos": resuelven sus listas de IDs llamando a `CatalogDao.getTitlesByIds(ids)` sin forzar la carga en memoria del catálogo completo.
- **Hidratación Bajo Demanda para Detalle y Reproductor:**
  - `CatalogRepository.hydrateChannel(String titleId)` construye una instancia de `Channel` o `XtreamSeries` a partir de los datos completos cacheados en Drift, permitiendo que `HourTvMovieDetailsPage`, `HourTvSeriesDetailPage`, `HourTvPlayer` y `MobileVLCPlayer` funcionen de inmediato sin cambios en sus contratos de reproducción.

**Jerarquía de Fallback:**
1. **Drift Local:** Respuesta inmediata <10 ms tanto online como offline.
2. **Supabase Remoto:** Sincronización en segundo plano mediante `CatalogSyncEngine`.
3. **Respaldo Temporal JSON:**
   - Si Supabase no responde **Y** la base local Drift está completamente vacía:
     - Lee `catalog.json` remoto o el asset empaquetado `assets/data/sources.json`.
     - Vuelca las películas y series a Drift mediante inserción por lotes.
     - Notifica `offlineReady`, asegurando que la primera experiencia funcione indexada y sin pantallas vacías.

- [ ] **Paso 1: Escribir pruebas unitarias en `test/services/catalog/catalog_repository_test.dart` y `test/content_store_catalog_test.dart`**
  Probar:
  - Arranque offline con Drift poblado -> emite datos locales y estado `offlineReady`.
  - Arranque en frío sin red ni caché -> ejecuta fallback a `sources.json`, puebla Drift y emite `offlineReady`.
  - Supabase con error 500 y caché vacía -> activa fallback a `catalog.json` / `sources.json`.
  - Hidratación bajo demanda de `Channel` y `XtreamSeries` por ID.
  - Resolución de favoritos y continuar viendo por IDs sin cargar el catálogo completo.
  - No regresión en las pruebas existentes de `test/startup_readiness_test.dart`.

- [ ] **Paso 2: Ejecutar las pruebas y verificar que fallen**
  Comando: `flutter test test/services/catalog/catalog_repository_test.dart test/content_store_catalog_test.dart`
  Resultado esperado: FAIL.

- [ ] **Paso 3: Implementar `CatalogRepository` y actualizar `ContentStore`**
  Desarrollar `catalog_repository.dart` e integrar con `content_store.dart`.

- [ ] **Paso 4: Ejecutar pruebas de catálogo, ContentStore y análisis estático**
  Comandos:
  ```powershell
  flutter test test/services/catalog/catalog_repository_test.dart
  flutter test test/content_store_catalog_test.dart
  flutter test test/startup_readiness_test.dart
  flutter analyze
  ```
  Resultado esperado: Pruebas pasando al 100%.

- [ ] **Paso 5: Commit atómico de la Tarea 5**
  ```bash
  git add lib/services/catalog/catalog_repository.dart lib/services/content_store.dart test/services/catalog/catalog_repository_test.dart test/content_store_catalog_test.dart
  git commit -m "feat(catalog): implementar repositorio resiliente, fallback json e hidratacion bajo demanda"
  ```

---

### Task 6: Integración en `hourtv_mobile_shell.dart` y Renderizado Perezoso por Cursor

**Archivos:**
- Modificar: `lib/services/catalog_presentation_index.dart`
- Crear: `lib/services/catalog/catalog_page_source.dart`
- Modificar: `lib/mobile_ui/hourtv_mobile_shell.dart`
- Crear: `test/mobile_ui/hourtv_paginated_shell_test.dart`

**Mejoras en la Interfaz de Usuario:**
- `CatalogPageSource`:
  - Controla la paginación perezosa por cursor conectada a `CatalogDao`.
  - Notifica adiciones de páginas sin reconstruir los widgets previos.
- Modificaciones en `lib/mobile_ui/hourtv_mobile_shell.dart`:
  - `HourTvMobileHome` (Inicio, línea 275):
    - El Hero (`_HeroCarousel`, línea 561) consulta títulos destacados calificados (`is_featured = true AND backdrop_url IS NOT NULL`) mediante `CatalogDao.getFeaturedTitles()`, eliminando de raíz cualquier llamada a `movies.take(5)`.
    - Las filas de películas, series y géneros cargan sus primeros 15 elementos desde Drift y permiten desplazamiento horizontal fluido sin bloquear el render.
  - `HourTvMobileSearch` (Buscar, línea 845):
    - El `ScrollController` detecta cuando la posición está a menos de 300px del final y solicita la siguiente página determinista por cursor.
    - El campo de búsqueda aplica debounce de 250 ms y ejecuta búsquedas FTS5 contra la base local indexada usando `sanitizeFts5Query`.
  - `HourTvMobileLibrary` (Biblioteca, línea 1482):
    - Resuelve favoritos e historial consultando sus IDs mediante `CatalogDao.getTitlesByIds()`.

- [ ] **Paso 1: Escribir pruebas de widgets en `test/mobile_ui/hourtv_paginated_shell_test.dart`**
  Probar:
  - Scroll infinito en Buscar: agrega la página 2 por cursor sin perder la posición ni duplicar tarjetas.
  - Búsqueda reactiva con debounce contra el índice FTS5 de Drift con texto seguro y sanitizado.
  - El Hero muestra exclusivamente títulos destacados calificados.
  - Continuar viendo y favoritos se renderizan a partir de IDs resueltos contra Drift.

- [ ] **Paso 2: Ejecutar las pruebas y verificar que fallen**
  Comando: `flutter test test/mobile_ui/hourtv_paginated_shell_test.dart`
  Resultado esperado: FAIL.

- [ ] **Paso 3: Implementar `CatalogPageSource` y actualizar `hourtv_mobile_shell.dart`**
  Desarrollar `catalog_page_source.dart` y actualizar `HourTvMobileHome`, `HourTvMobileSearch` y `HourTvMobileLibrary` en `lib/mobile_ui/hourtv_mobile_shell.dart`.

- [ ] **Paso 4: Ejecutar pruebas de UI y análisis estático**
  Comandos:
  ```powershell
  flutter test test/mobile_ui/hourtv_paginated_shell_test.dart
  flutter test test/hourtv_mobile_search_filters_test.dart
  flutter test test/search_recent_history_ui_test.dart
  flutter analyze
  ```
  Resultado esperado: Pruebas de UI pasando al 100%.

- [ ] **Paso 5: Commit atómico de la Tarea 6**
  ```bash
  git add lib/services/catalog/catalog_page_source.dart lib/services/catalog_presentation_index.dart lib/mobile_ui/hourtv_mobile_shell.dart test/mobile_ui/hourtv_paginated_shell_test.dart
  git commit -m "perf(ui): conectar inicio, buscar y biblioteca a consultas paginadas drift"
  ```

---

### Task 7: Pruebas Deterministas de Escala (10,000 Títulos), Validador DNS Anti-Rebinding e Importador PostgreSQL Directo

**Archivos:**
- Modificar: `pubspec.yaml` (añadir `dev_dependencies: postgres: ^3.2.1`)
- Modificar: `pubspec.lock`
- Crear: `lib/services/catalog/dns_security_validator.dart`
- Crear: `tool/benchmark_synthetic_catalog.dart`
- Crear: `tool/import_catalog_to_supabase.dart`
- Crear: `test/services/catalog/dns_security_validator_test.dart`
- Crear: `test/benchmark/synthetic_catalog_scale_test.dart`

**Defensa en Profundidad y Validador DNS Anti-Rebinding (`lib/services/catalog/dns_security_validator.dart`):**
- Valida que cualquier host de stream resuelva a IPs públicas válidas:
  - Rechaza loopback (`127.0.0.0/8`, `::1`).
  - Rechaza rangos privados (`10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`, `fc00::/7`).
  - Rechaza link-local (`169.254.0.0/16`, `fe80::/10`).
  - Rechaza multicast (`224.0.0.0/4`, `ff00::/8`) y rangos reservados/documentación (`0.0.0.0/8`, `2001:db8::/32`).
- **Defensa contra DNS Rebinding:** Vuelve a validar la dirección IP resuelta al establecer la conexión de prueba del stream antes de aceptar la fuente en el catálogo.

**Importador Local Administrativo (`tool/import_catalog_to_supabase.dart`):**
- Utiliza la dependencia oficial `postgres: ^3.2.1` en `dev_dependencies`.
- Abre conexión administrativa directa:
  `Connection.open(Endpoint(host: host, port: port, database: 'postgres', username: user, password: password))`
- **Modo `--dry-run` por defecto:** Realiza parseo, validación DNS y reporte sin escribir en la base de datos a menos que se invoque con `--apply`.
- **Validación Estricta de Host/Puerto:**
  - Si el host especificado no es `127.0.0.1` o `localhost`, o el puerto difiere de `54322`, el importador aborta inmediatamente antes de intentar abrir cualquier socket.
  - Prohibición absoluta de aceptar `service_role` remota o conectarse a URLs remotas.
- **Credenciales Seguras:** Variables de entorno `LOCAL_SUPABASE_DB_HOST`, `LOCAL_SUPABASE_DB_PORT`, `LOCAL_SUPABASE_DB_USER`, `LOCAL_SUPABASE_DB_PASSWORD` (con valores por defecto locales). **Nunca se imprime la cadena de conexión ni contraseñas en consola o logs.**
- **Transaccionalidad y Cierre:**
  - Envuelto en `await connection.runTx((session) async { ... })` con `ROLLBACK` completo ante cualquier error.
  - Cierre garantizado en `finally { await connection.close(); }`.

**Separación de Criterios de Rendimiento:**
1. **Pruebas Deterministas Obligatorias (Fallo estricto en CI):**
   - Inserción de 10,000 títulos sintéticos en Drift local (en memoria).
   - Recorrido paginado completo de 50 páginas sucesivas por cursor: verificación estricta de **0 duplicados y 0 pérdidas**.
   - Verificación de que la paginación no materializa más de una página de objetos `Channel` en memoria a la vez.
   - En PostgreSQL local: `EXPLAIN` confirma el uso de `idx_titles_cursor_comp` e `idx_titles_search_trgm` sin escaneos secuenciales (`Seq Scan`).
   - El test de rechazo de host remoto del importador pasa sin abrir ningún socket de red.
2. **Benchmark Informativo:**
   - Reporta mediana y percentil 95 (p95) de tiempo de consulta por cursor y búsqueda FTS5, tamaño de base SQLite y memoria en release mode, sin fallar por variaciones absolutas en CI.

- [ ] **Paso 1: Escribir pruebas unitarias en `test/services/catalog/dns_security_validator_test.dart` y `test/benchmark/synthetic_catalog_scale_test.dart`**
  Probar:
  - Validador DNS rechaza dominios que resuelven a IPs privadas o loopback con resolver simulado.
  - Importador rechaza hosts remotos (`remote.supabase.co`, `192.168.1.10`) antes de abrir sockets.
  - Recorrido de 10,000 títulos con cero duplicados, cero pérdidas y tamaño de página constante.

- [ ] **Paso 2: Ejecutar las pruebas y verificar que fallen**
  Comando: `flutter test test/services/catalog/dns_security_validator_test.dart test/benchmark/synthetic_catalog_scale_test.dart`
  Resultado esperado: FAIL.

- [ ] **Paso 3: Añadir dependencia `postgres` en `dev_dependencies` e implementar validador, benchmark e importador**
  Añadir `postgres: ^3.2.1` en `pubspec.yaml`.
  Ejecutar `flutter pub get`.
  Implementar `dns_security_validator.dart`, `benchmark_synthetic_catalog.dart` e `import_catalog_to_supabase.dart`.

- [ ] **Paso 4: Ejecutar pruebas y benchmark**
  Comandos:
  ```powershell
  flutter test test/services/catalog/dns_security_validator_test.dart
  flutter test test/benchmark/synthetic_catalog_scale_test.dart
  dart run tool/benchmark_synthetic_catalog.dart
  flutter analyze
  ```
  Resultado esperado: Pruebas pasando al 100%; benchmark informativo imprime métricas estructuradas.

- [ ] **Paso 5: Commit atómico de la Tarea 7**
  ```bash
  git add pubspec.yaml pubspec.lock lib/services/catalog/dns_security_validator.dart tool/benchmark_synthetic_catalog.dart tool/import_catalog_to_supabase.dart test/services/catalog/dns_security_validator_test.dart test/benchmark/synthetic_catalog_scale_test.dart
  git commit -m "test(catalog): agregar validador dns anti-rebinding, benchmark 10k e importador postgres directo"
  ```

---

### Task 8: Pruebas de Aislamiento de Seguridad, Métricas Técnicas y Verificación Final

**Archivos:**
- Crear: `test/catalog_security_isolation_test.dart`
- Crear: `docs/verification/hourtv-supabase-paginated-catalog-phase-3.md`

**Verificación Integral:**
1. **Aislamiento de Seguridad:**
   - La APK y roles `anon`/`authenticated` tienen prohibido mutar el catálogo (`INSERT/UPDATE/DELETE` bloqueados en PostgreSQL).
   - Títulos no publicados o marcados con `deleted_at` son completamente inaccesibles por `SELECT`.
   - La vista `title_summaries` con `security_invoker = true` oculta estrictamente títulos no publicados o borrados.
   - Las fuentes de episodios verifican la publicación del título raíz.
   - `catalog_changes` entrega eventos de lápidas sin exponer metadatos privados.
   - Funciones administrativas (`compact_catalog_changes`, triggers) tienen `REVOKE ALL FROM PUBLIC/anon/authenticated`.
2. **Resiliencia y Modo Offline:**
   - Simulación de corte de red: la app arranca en `offlineReady` con catálogo disponible.
   - Simulación de primera instalación sin red: activa fallback a `sources.json` y puebla Drift.
3. **Métricas Técnicas Locales:**
   - Registro de métricas locales de arranque, tamaño de base local y sincronización delta, sin enviar telemetría comercial ni datos analíticos externos.
4. **Informe de Verificación:**
   - Documentar en `docs/verification/hourtv-supabase-paginated-catalog-phase-3.md` la ejecución completa de pruebas locales pgTAP, Flutter unit/widget tests, banco determinista y validación de seguridad.

- [ ] **Paso 1: Escribir la prueba de aislamiento de seguridad en `test/catalog_security_isolation_test.dart`**
  Verificar rechazo de mutaciones y restricciones de visibilidad desde el cliente Flutter.

- [ ] **Paso 2: Ejecutar la suite completa de pruebas locales**
  Comandos:
  ```powershell
  npx -y supabase test db supabase/tests/catalog_schema_rls.test.sql
  npx -y supabase test db
  flutter test
  flutter analyze
  ```
  Resultado esperado: 100% de pruebas pasando en base de datos y Flutter; 0 errores de análisis.

- [ ] **Paso 3: Redactar la documentación de verificación final**
  Crear `docs/verification/hourtv-supabase-paginated-catalog-phase-3.md`.

- [ ] **Paso 4: Commit atómico de la Tarea 8**
  ```bash
  git add test/catalog_security_isolation_test.dart docs/verification/hourtv-supabase-paginated-catalog-phase-3.md
  git commit -m "docs(catalog): documentar verificacion final y aislamiento de seguridad fase 3"
  ```

---

## Plan de Verificación y Criterios de Aceptación

### Pruebas Automatizadas
1. **Base de Datos (pgTAP):**
   - `npx -y supabase test db supabase/tests/catalog_schema_rls.test.sql` -> Valida esquema, triggers de `catalog_changes` (regla anti-filtración), actualización automática de `latest_revision`, compactación, RLS en tablas y vistas, aislamiento de borradores, revocación de privilegios de funciones a `PUBLIC/anon/authenticated` y revocación de escrituras.
2. **Base Local e Índices (Flutter / Drift):**
   - `flutter test test/database/catalog_database_test.dart` -> Operaciones CRUD locales en segundo plano, búsquedas FTS5 sanitizadas (`MATCH`), paginación por cursor compuesta, soporte de 64 bits para revisiones e invariantes de lápidas compuestas.
3. **Sincronización y Gateway:**
   - `flutter test test/services/catalog/` -> Sincronización incremental por revisiones con checkpoint atómico, recuperación por compactación (*full resync* sin tocar favoritos) y tolerancia a interrupciones.
4. **Escala Determinista y Seguridad DNS:**
   - `flutter test test/services/catalog/dns_security_validator_test.dart` -> Validación de resolución DNS y protección contra rebinding.
   - `flutter test test/benchmark/synthetic_catalog_scale_test.dart` -> Paginación de 10,000 títulos sintéticos con cero duplicados, cero pérdidas, memoria controlada y validación de rechazo de hosts remotos en el importador.
5. **Regresión Global:**
   - `flutter test` completo -> Validación de todas las suites sin regresión en autenticación, perfiles de Fase 2 ni reproducción de video.

### Verificación Manual en Dispositivo / Emulador
1. **Arranque en Frío con Modo Avión:** Instalar la app sin red -> debe mostrar el catálogo de respaldo inmediato en Drift sin pantalla en blanco ni fallo fatal.
2. **Reconexión y Sincronización:** Activar Wi-Fi -> el catálogo sincroniza revisiones en segundo plano y refleja actualizaciones sin reiniciar la app.
3. **Navegación Fluida:** Desplazarse por Inicio y realizar búsquedas de títulos en un catálogo grande verificando que la tasa de refresco se mantenga constante sin tirones (*jank*).
