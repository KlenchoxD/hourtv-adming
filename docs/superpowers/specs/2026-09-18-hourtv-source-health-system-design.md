# Sistema de Salud de Servidores (HourTV)

## 1. Contexto y Diagnóstico
La aplicación HourTV consume fuentes de video (películas, series, canales) de diversos proveedores mediante scrapers. Muchos de estos proveedores pueden reportar falsos positivos (como Barmonrey, que retorna HTTP 200 en su página pero HTTP 404 en el M3U8 subyacente), o bien cambiar dominios de proxys (como VOE). El catálogo tiene fuentes registradas en `public.sources` con la propiedad editorial `status` (se observaron 776 fuentes en la base local del dispositivo auditado, sin afirmar obligatoriamente que Supabase contenga exactamente la misma cifra sin previa consulta), pero carece de un historial auditable automatizado (uptime). Además, el administrador y el reproductor necesitan información fidedigna de qué enlaces están caídos, sin confundir el estado editorial (visible/oculto) de la salud técnica del enlace.

## 2. Objetivos y No Objetivos

### Objetivos
- Dotar al repositorio y a Supabase de un sistema de historial auditable con retención de 30 días de salud.
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
Se evita modificar la definición del `status` actual. Se extiende `public.sources` con estado técnico y se centraliza el auditor en `private.source_health_checks`. No se debe afirmar que RLS sustituye los GRANT/REVOKE explícitos.

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
Ante error, ejecuta `ROLLBACK`. La conexión se realiza directamente a PostgreSQL con Connection Pooler, nunca a través de la REST API desde GitHub. La limpieza de 30 días se ejecuta en el mismo bloque y no depende de pg_cron externo de forma ciega.

## 8. Health Checker
- **Mecánica**: Extracción de Embed conservando Cookies, Referer, Origin y User-Agent.
- **Media streams (MP4/MKV)**: Enviar solicitud `GET` con `Range: bytes=0-2048`. Aceptar `200 OK` o `206 Partial Content` únicamente después de validar firmas mágicas (magic bytes) y estructura multimedia en el Content-Type. Leer unos pocos KB y cancelar el cuerpo restante para abortar la descarga completa.
- **Media streams (HLS/M3U8)**: Realizar `GET` al manifiesto. Si es master playlist, resolver una variante. Realizar `GET` parcial (`Range: bytes=0-2048`) de un segmento audiovisual auténtico (`.ts` o `.m4s`). Aceptar `200 OK` o `206 Partial Content` únicamente después de validar magic bytes/estructura multimedia. Se debe limitar la lectura y abortar el cuerpo restante. Conservar explícitamente cookies, Referer, Origin y User-Agent necesarios en todas las peticiones y resolver URLs relativas. No admitir bajo ninguna circunstancia `.aac`, `.vtt`, HTML, anuncios ni páginas de redirección como prueba de video reproducible.

## 9. Estados y Transiciones
- **Fallo Concluyente (404, 410, DNS_NXDOMAIN de stream base):** Suma fallos. Asigna `firstFailureAt`.
- **Fallo No Concluyente (403, 405, 429, Timeout, Cloudflare):** Una fuente `down` permanece `down`. Una fuente sana pasa visualmente a `degraded` en el panel pero **no aumenta contadores**, ni borra el `firstFailureAt` anterior. Solo un éxito concluyente la mueve a `recovered`.
- **Definitivo Down:** Se asigna solo si la fuente tiene 3 fallos concluyentes en **run IDs distintos** y habiendo transcurrido `>= 12 horas` desde el `firstFailureAt`.
- **Recuperado**: Un éxito concluyente sobre un stream en `down` cambia estado a `recovered` e interrumpe los contadores. Éxitos subsiguientes la estabilizan en `active`.

## 10. Circuit Breaker
Protección contra baneos e inestabilidad temporal.
- Tanto el umbral global (>15%) como el umbral por host (>30%) requieren al menos 20 fuentes evaluables en su muestra correspondiente para aplicar.
- Las respuestas inconclusas (403, 405, 429, timeout o Cloudflare) no deben contabilizarse como fallos concluyentes para disparar estos porcentajes.
- Si no se alcanza la muestra mínima (menos de 20 fuentes), se generará una advertencia en los logs, pero no se activará el circuit breaker.
- Si se activa: finalizará con exit status 3 y se generará un reporte/artifact, pero no realizará ninguna escritura de `catalog.json`, ningún commit, push ni sincronización a PostgreSQL.
- Modo Dry-run: nunca realiza escrituras; devolverá exit status 2 solamente cuando detecte cambios aplicables y siempre que no se haya activado el circuit breaker.

## 11. Panel "Caídos"
- Filtro mediante iteración de películas/series/episodios en JSON usando `health.status === 'down'`.
- "Revalidar": Añade `recheckRequestedAt` al JSON del panel. El bot al detectarlo le dará prioridad en el próximo cron y borrará este campo. Esto **no modifica estado de salud original** ni contadores. Una fuente `down` sigue excluida.
- "Reemplazar": El JSON recibe una fuente nueva con un ID nuevo y un apuntador `replacementForId` y salud `pending`. La anterior no se elimina automáticamente. La nueva se prueba y, si es válida, la vieja recibe la propiedad `replacedById`. Nunca almacenar secretos de Supabase en el panel. La eliminación definitiva es siempre fuera de la automatización y requiere confirmación explícita. El AutoCatálogo debe estar protegido y nunca destruir `id`, `health` y variables de reemplazo en operaciones concurrentes.

## 12. Drift/Flutter
- Incremento de schemaVersion, migración addColumn y regeneración de catalog_database.g.dart.
  ```dart
  TextColumn get healthStatus => text().withDefault(const Constant('pending'))();
  TextColumn get healthLastError => text().nullable()();
  IntColumn get healthHttpCode => integer().nullable()();
  IntColumn get healthConsecutiveFailures => integer().withDefault(const Constant(0))();
  DateTimeColumn get healthFirstFailureAt => dateTime().nullable()();
  DateTimeColumn get healthLastSuccessAt => dateTime().nullable()();
  DateTimeColumn get healthLastCheck => dateTime().nullable()();
  TextColumn get healthLastCheckRunId => text().nullable()();
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
Si una URL (incluyendo la `channel.url` o `preferredUrl`) coincide de forma unívoca con un `PlaybackCandidate` con estado `down`, prevalece el estado `down` y la excluye totalmente. No puede reentrar.
La API `PlaybackSourcePlan` jamás lanzará error (RangeError) en accesos vacíos. Devolverá estado tipado (ej. `bool get isEmpty`) sin excepción al acceder a `current`. Las fuentes desconocidas o legacy entran como `unknown`. No se permiten indexaciones directas sin control.

## 14. Seguridad/RLS
- Revocación estricta al esquema `private`.
- Nada del PAT de GitHub ni Service Keys/Connection String de Supabase estará presente en el frontend (Flutter/Vercel) ni en logs.

## 15. Compatibilidad
- Las versiones anteriores del APK ignorarán en `fromJson` las nuevas propiedades `health`, preservando operaciones previas sin fallos (`status` editorial sigue intacto). Los SELECT de Supabase son explícitos, protegiendo las retrocompatibilidad.

## 16. TDD por Fases
- Fase 0: Parche urgente VOE. Fixture real anonimizado, extracción estricta, alias `katherineschoolphone.com` sin aceptar `evilkatherineschoolphone.com`.
- Fase 1: Identidad y reconciliación dry-run.
- Fase 2: Modelo JSON, SQL y Drift (Columnas completas).
- Fase 3: Health checker y validación profunda (HLS/MP4).
- Fase 4: Circuit breaker/workflow.
- Fase 5: Sincronización PostgreSQL y seguridad.
- Fase 6: Panel Caídos.
- Fase 7: PlaybackCandidate/fallback (Aseguramiento contra RangeError).
- Fase 8: Auditoría física de película/episodio y release separada.

## 17. Criterios de Aceptación
- VOE reproduce película y episodio reales (dispositivo físico).
- Los logs iniciales de extracción no muestran `playback_error` durante inicialización.
- No hay fallback visual al WebView cuando la extracción nativa es exitosa.
- Un test rechaza `evilkatherineschoolphone.com`.
- Un test HLS demuestra que se envía el parámetro `Range` al segmento `.ts`/`.m4s` resolviendo correctamente relativas.
- Un test rechaza expresamente `.aac`, `.vtt` y páginas HTML como validación de video.
- Tests del circuit breaker cubren exhaustivamente: muestra global < 20, muestra por host < 20, respuestas inconclusas y activación real sin mutaciones en el sistema.
- Los tests de seguridad de Supabase RLS verifican explícitamente operaciones `SELECT`, `INSERT`, `UPDATE` y `DELETE` comprobando que `anon` y `authenticated` obtienen acceso denegado total, no solo en lectura.
- El dry-run no modifica archivos.
- Circuit breaker activado no hace commit, push ni sincroniza a PostgreSQL.
- Una fuente confirmada como `down` jamás logra reentrar al plan de reproducción a través de `channel.url` o `preferredUrl`.
- Un plan vacío (`isEmpty`) provee un `current` nulo manejado con elegancia, evitando emitir RangeError bajo ninguna circunstancia.
- AutoCatálogo conserva `id`, `health` y campos de reemplazo inmutables durante concurrencia.

## 18. Rollback
No se afirmará que un simple *re-run* restaura un estado previo ni que `git revert` lo hace aisladamente. Un rollback verdadero implica:
a) Revertir el commit que modificó `catalog.json` (ej: `git checkout HEAD^ -- catalog.json && git commit -m "Rollback catalog"`).
b) Ejecutar una sincronización idempotente PostgreSQL a partir de ese commit seguro.
c) No borrar ni alterar el historial de auditoría de la tabla privada.
d) Generar un nuevo número/identidad de revisión hacia adelante en el pipeline de Supabase. El sistema ofrecerá herramienta dry-run para evaluar el impacto antes del rollback.
