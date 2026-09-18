# Sistema de Salud de Servidores (HourTV)

## 1. Contexto y Diagnóstico
La aplicación HourTV consume fuentes de video (películas, series, canales) de diversos proveedores mediante scrapers. Muchos de estos proveedores pueden reportar falsos positivos (como Barmonrey, que retorna HTTP 200 en su página pero HTTP 404 en el M3U8 subyacente), o bien cambiar dominios de proxys (como VOE). El catálogo tiene más de 776 fuentes registradas en `public.sources` con la propiedad editorial `status`, pero carece de telemetría de salud automatizada (uptime). Además, el administrador y el reproductor necesitan información fidedigna de qué enlaces están caídos, sin confundir el estado editorial (visible/oculto) de la salud técnica del enlace.

## 2. Objetivos y No Objetivos

### Objetivos
- Dotar al repositorio y a Supabase de un sistema de telemetría inmutable de salud.
- Separar estrictamente el estado editorial del estado de salud de red de una fuente.
- Detectar con precisión extrema la funcionalidad de un stream HLS o MP4 directo, validando bytes de medios reales.
- Prevenir la visualización de servidores definitivamente inactivos en el reproductor.
- Facilitar al panel de administración una visualización detallada de enlaces problemáticos.

### No Objetivos
- Reestructurar el backend completo a API viva; `catalog.json` sigue siendo la fuente de la verdad.
- Sustituir el flujo eventual de sync; la actualización de la DB se hace vía workflow idempotente.
- Generar reemplazos automáticos de dominio; el script solo emite alertas para corrección humana.

## 3. Arquitectura
La arquitectura sigue un pipeline de tres pasos:
1. **Verificación en CI/CD**: Un Health Checker (Node.js) se ejecuta vía GitHub Actions cada 6 horas en la rama `master` y analiza las fuentes de `catalog.json`.
2. **Propagación**: Modifica `catalog.json` y hace commit/push sobre la rama `master`.
3. **Persistencia Privada**: Inmediatamente después, sincroniza los cambios de manera idempotente usando conexión PostgreSQL directa al backend de Supabase mediante un Connection Pooler. La aplicación (Flutter) recibe la salud sincronizada como metadatos para omitir fuentes caídas.

## 4. Identidad y Reconciliación
Nunca se asumirá que el ID alfanumérico primitivo del JSON es el UUID de la tabla Supabase, ya que la fuente de identidad reside en la base de datos de destino.
1. **Migración Inicial**: Consultar fuentes en Supabase y emparejarlas con `catalog.json`.
   - **Películas/Series**: Emparejamiento usando `legacy_id` y como apoyo el `tmdb_id`.
   - **Episodios**: Emparejamiento mediante título estable de serie + temporada + número de episodio.
2. Si coincide: se guarda el UUID original en `catalog.json`.
3. Si no hay contraparte: se genera un UUIDv4 una única vez y se preserva.
4. Si existe ambigüedad, el reporte marca `ambiguous` y detiene el paso a producción. No publicar.
Una vez asignado, la identidad nunca depende de la URL. Si un panelista cambia la URL, se crea un servidor alternativo recibiendo un UUID nuevo y conservando `replacementForId`.

## 5. Modelo JSON
Las fuentes preservarán el campo inmutable `id` (UUIDv4) y la salud de manera opcional. El campo `lastCheck` es opcional para fuentes nuevas `pending`. No existirán secretos de base de datos o GitHub en este archivo ni en logs.

```typescript
export interface CatalogServerHealth {
  status: "pending" | "active" | "degraded" | "down" | "recovered";
  lastError?: string;
  httpCode?: number;
  consecutiveFailures: number;
  firstFailureAt?: string;
  lastSuccessAt?: string;
  lastCheck?: string;
  lastCheckRunId?: string;
  recheckRequestedAt?: string;
}

export interface CatalogServer {
  id: string; // UUID inmutable persistente
  name: string;
  url: string;
  language?: string;
  health?: CatalogServerHealth;
  replacementForId?: string;
  replacedById?: string; 
}
```

## 6. SQL Conceptual
Se evita modificar la definición del `status` actual. Se extiende `public.sources` con estado técnico y se centraliza el auditor en `private.source_health_checks`.

```sql
ALTER TABLE public.sources
  ADD COLUMN health_status text NOT NULL DEFAULT 'pending' 
      CHECK (health_status IN ('pending', 'active', 'degraded', 'down', 'recovered')),
  ADD COLUMN health_last_error text,
  ADD COLUMN health_http_code int CHECK (health_http_code >= 100 AND health_http_code <= 599),
  ADD COLUMN health_consecutive_failures int NOT NULL DEFAULT 0 CHECK (health_consecutive_failures >= 0),
  ADD COLUMN health_first_failure_at timestamptz,
  ADD COLUMN health_last_success_at timestamptz,
  ADD COLUMN health_last_check timestamptz,
  ADD COLUMN health_last_check_run_id text,
  ADD COLUMN replaced_by_id uuid REFERENCES public.sources(id) ON DELETE SET NULL;

CREATE SCHEMA IF NOT EXISTS private;
REVOKE ALL ON SCHEMA private FROM PUBLIC, anon, authenticated;
REVOKE ALL ON ALL TABLES IN SCHEMA private FROM PUBLIC, anon, authenticated;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA private FROM PUBLIC, anon, authenticated;

CREATE TABLE private.source_health_checks (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  source_id uuid NOT NULL REFERENCES public.sources(id) ON DELETE CASCADE,
  run_id text NOT NULL,
  status_checked text NOT NULL,
  error_msg text,
  http_code int,
  checked_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE private.source_health_checks ENABLE ROW LEVEL SECURITY;
```

## 7. Sincronización GitHub → PostgreSQL
El pipeline GitHub y Supabase mantienen una consistencia eventual, pero las operaciones hacia la BD son estrictamente atómicas dentro de PostgreSQL.
```sql
BEGIN;
-- Upserts hacia public.sources (health fields).
-- Inserts hacia private.source_health_checks.
-- DELETE FROM private.source_health_checks WHERE checked_at < NOW() - INTERVAL '30 days'.
COMMIT;
```
Ante error, ejecuta `ROLLBACK`. La conexión se realiza directamente a PostgreSQL con Connection Pooler, nunca a través de la REST API desde GitHub.

## 8. Health Checker
- **Mecánica**: Extracción de Embed conservando Cookies, Referer, User-Agent.
- **Media streams (MP4/MKV)**: Enviar solicitud `GET` con `Range: bytes=0-2048`. Aceptar `206 Partial Content` y `200 OK`. Leer unos pocos KB para comprobar firmas mágicas y Content-Type, y cancelar la lectura del cuerpo restante para abortar la descarga completa.
- **Media streams (HLS/M3U8)**: Realizar `GET` al manifiesto. Si es master, resolver una variante. Parsear el Media Playlist, e intentar `GET` con `Range: bytes=0-2048` a un segmento audiovisual auténtico (`.ts`, `.aac`, `.m4s`). Archivos `.vtt` de subtítulos no valen. Resolver URLs relativas. Se acepta `200` y `206` verificando contenido coherente de vídeo. Redirecciones o páginas HTML no valen.

## 9. Estados y Transiciones
- **Fallo Concluyente (404, 410, DNS_NXDOMAIN de stream base):** Suma fallos. Asigna `firstFailureAt`.
- **Fallo No Concluyente (403, 405, 429, Timeout, Cloudflare):** Una fuente `down` permanece `down`. Una fuente sana pasa visualmente a `degraded` en el panel pero **no aumenta contadores**, ni borra el `firstFailureAt`. Solo un éxito concluyente la mueve a `recovered`.
- **Definitivo Down:** Se asigna solo si la fuente tiene 3 fallos concluyentes en **run IDs distintos** y habiendo transcurrido `>= 12 horas` desde el `firstFailureAt`.
- **Recuperado**: Un éxito concluyente sobre un stream en `down` cambia estado a `recovered` e interrumpe los contadores. Éxitos subsiguientes la estabilizan en `active`.

## 10. Circuit Breaker
Protección contra baneos. El Circuit Breaker cancela actualizaciones (Dry-run o Silent Alarm con Exit Status 3) si en una corrida fallan por igual >15% global o >30% de un dominio en particular. Esta regla requiere una **muestra mínima de 20 fuentes** para el dominio.

## 11. Panel "Caídos"
- Filtro mediante iteración de películas/series/episodios en JSON usando `health.status === 'down'`.
- "Revalidar": Añade `recheckRequestedAt` al JSON del panel. El bot al detectarlo le dará prioridad en el próximo cron y borrará este campo. Esto **no modifica estado de salud original** ni contadores.
- "Reemplazar": El JSON recibe una fuente nueva con un ID nuevo y un apuntador `replacementForId`. El panel *nunca* elimina automáticamente servidores antiguos reemplazados. La eliminación es de acción humana deliberada. Nunca almacenar secretos de Supabase en el panel.

## 12. Drift/Flutter
- Migración SQLite incrementando `schemaVersion`:
  ```dart
  TextColumn get healthStatus => text().withDefault(const Constant('pending'))();
  // [...] incluir todos los campos de salud, actualizar DAOs y métodos copyWith/hydrate.
  ```

## 13. PlaybackCandidate y Fallback
Deduplicar la prioridad de `Channel.servers` y `Channel.url`.
```dart
class PlaybackCandidate {
  final String id;
  final String url;
  final String healthStatus;
}
```
Si una URL (incluyendo la `channel.url` o `preferredUrl`) coincide de forma unívoca con un `PlaybackCandidate` con estado `down`, prevalece el estado `down` y la excluye.
La API `PlaybackSourcePlan` jamás lanzará error en accesos nulos. Devolverá estado tipado (ej. `bool get isEmpty`) sin excepción al acceder a `current`. Las fuentes desconocidas o legacy entran como `unknown`. No eliminar fuentes de forma silenciosa.

## 14. Seguridad/RLS
- Revocación estricta al esquema `private`.
- Nada del PAT de GitHub ni Service Keys/Connection String de Supabase estará presente en el frontend (Flutter/Vercel) ni en logs.

## 15. Compatibilidad
- Las versiones anteriores del APK en el campo ignorarán en `fromJson` las nuevas propiedades `health`, preservando operaciones previas sin fallos (`status` editorial sigue intacto).

## 16. TDD por Fases
- Fase 1: Identidades estables en el bot, emparejamiento seguro, mock HLS validator (RED -> GREEN). Unit test circuit breaker.
- Fase 2: SQL y Transacción directa PostgreSQL. Comprobación RLS (`anon` == denied).
- Fase 3: Deduplicación Flutter `PlaybackCandidate`, testing de plan vacío sin excepciones.
- Fase 4: Panel Revalidar y reemplazos sin eliminación automática.

## 17. Criterios de Aceptación
- Extracción de un segmento HLS válido (`.ts`/`.m4s`) abortando descargas completas.
- Reconciliación de IDs limpia (`ambiguous = 0`) para las 776 fuentes.
- La aplicación descarta la provisión si el `PlaybackCandidate` deduce una URL prioritaria como `down`.
- Ausencia total de credenciales de backend en binarios o el DOM.

## 18. Rollback
Restaurar `catalog.json` copiando desde el commit anterior y commiteando un nuevo cambio: `git checkout HEAD^ -- catalog.json && git commit -m "Rollback catalog"`. Esto asegura una nueva revisión para que el script sincronizador PostgreSQL la propague hacia adelante, manteniendo la inmutabilidad de la historia. No se debe afirmar que `git revert` simple puede limitarse a un solo archivo sin conflicto.
