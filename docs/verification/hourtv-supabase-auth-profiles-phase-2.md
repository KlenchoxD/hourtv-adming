# Informe de Verificación: Fase 2 - Autenticación y Perfiles Supabase en HourTV

**Fecha:** 10 de Septiembre de 2026
**Versión de la aplicación:** `1.1.14+16` (invariable, no modificada)
**Estado:** Fase 2 completada exitosamente bajo metodología estricta TDD.

---

## 1. Resumen Ejecutivo

Se implementó la Fase 2 del plan de arquitectura de HourTV según las especificaciones de diseño:
- Integración segura del cliente `supabase_flutter: 2.17.2`.
- Modo Invitado preservado 100% aislado y funcional sin depender de Supabase.
- Esquema relacional `public.account_profiles` con Row Level Security (RLS) estricto y límite concurrente de 5 perfiles mediante trigger con lock transaccional advisory.
- Pantallas de autenticación (Inicio de sesión, Registro con verificación de correo, Recuperación de contraseña y Acceso directo como Invitado).
- Selector de perfiles en la nube (`HourTvCloudProfileGate`) con wizard de creación (Adulto / Infantil con protección por PIN) y límite visual de 5 perfiles.
- Preparación segura de la intención de importación del invitado (`GuestMigrationService` y `HourTvGuestImportPrompt`) sin exponer ni transmitir ninguna carga privada de datos fuera del dispositivo.
- Cero claves sensibles, secretos `service_role` ni contraseñas expuestas.

---

## 2. Historial de Commits Atómicos (Fase 2)

| Tarea | Hash | Mensaje | Descripción |
| :--- | :--- | :--- | :--- |
| **Task 1** | `5cd81b3` | `build(auth): configurar cliente Supabase de forma segura` | Dependencia `supabase_flutter: 2.17.2`, `SupabaseConfig`, parsing seguro de variables. |
| **Task 2** | `79e031c` | `feat(auth): aislar sesiones Supabase del modo invitado` | `AuthGateway`, `SupabaseAuthGateway`, `SupabaseBootstrap`, preservación del arranque invitado. |
| **Task 3** | `7c79127` | `feat(database): proteger perfiles de cuenta con RLS` | Migración SQL, RLS, grants mínimos, límite concurrente de 5 perfiles y suite pgTAP. |
| **Fix Task 1** | `c75a973` | `build(auth): registrar plugins Supabase en escritorio` | Registro legítimo de plugins generados para Linux, macOS y Windows. |
| **Task 4** | `12245b1` | `feat(auth): añadir acceso por correo y modo invitado` | `HourTvAuthGate`, `HourTvAuthPage`, `HourTvVerifyEmailPage`, deep link Android. |
| **Task 5** | `19b6f25` | `feat(profiles): añadir repositorios local y Supabase` | Modelo `HourTvAccountProfile`, `SupabaseProfileRepository`, `LocalGuestProfileRepository`. |
| **Task 6** | `9c1afa3` | `feat(profiles): integrar hasta cinco perfiles por cuenta` | `HourTvCloudProfileGate`, selector, creación con PIN infantil, namespaces aislados. |
| **Task 7** | `1005f63` | `feat(migration): preparar importación segura del invitado` | `GuestMigrationService`, `HourTvGuestImportPrompt`, decisión local para Fase 3. |
| **Task 8** | *(Actual)* | `test(auth): documentar seguridad y perfiles Supabase` | Validación end-to-end, pruebas exhaustivas y documentación de cierre. |

---

## 3. Verificación de la Base de Datos Local (Docker Desktop)

- **Supabase CLI:** `2.117.0`
- **Migración aplicada:** `supabase/migrations/20260910032210_create_account_profiles.sql`
- **Resultados de `supabase test db` (pgTAP):**
  ```text
  Connecting to local database...
  /Users/Kleiner/proyectos/HourTV/supabase/tests/account_profiles_rls.test.sql .. ok
  All tests successful.
  Files=1, Tests=13,  0 wallclock secs
  Result: PASS
  ```
- **Matriz de Políticas RLS y Permisos verificados (13 pruebas):**
  1. Denegación total de acceso a rol `anon`.
  2. Inserción permitida solo para el propio `auth.uid()`.
  3. Rechazo de inserción asignando un `owner_id` ajeno (SQLSTATE `42501`).
  4. Consulta (`SELECT`) restringida exclusivamente a filas donde `owner_id = auth.uid()`.
  5. Aislamiento estricto: un usuario no puede visualizar los perfiles de otro.
  6. Actualización (`UPDATE`) restringida al propietario.
  7. Rechazo de cambio de `owner_id` en `UPDATE`.
  8. Eliminación (`DELETE`) restringida al propietario.
  9. Límite estricto de 5 perfiles por cuenta: las primeras 5 inserciones pasan.
  10. Rechazo de la 6ta inserción por trigger invoker (SQLSTATE `23514`, `profile_limit_exceeded`).
- **Resultados de `supabase db advisors`:**
  ```text
  Connecting to local database...
  No issues found
  {"results":[],"message":"db advisors"}
  ```
- **Resultados de `supabase migration list --local`:**
  ```json
  {"migrations":[{"local":"20260910032210","remote":"20260910032210","time":"2026-09-10 03:22:10"}],"message":"Migrations listed"}
  ```

---

## 4. Verificación de la Aplicación Flutter

- **Ejecución completa de `flutter test`:**
  - **Total de pruebas ejecutadas:** 260 pruebas.
  - **Resultado:** 260 pasadas, 0 fallidas (100% PASS).
- **Análisis estático (`flutter analyze`):**
  - **Resultado:** `No issues found!` (0 errores, 0 advertencias, 0 lints).
- **Integridad de Diff (`git diff --check`):**
  - **Resultado:** Código de salida 0 (sin espacios en blanco residuales ni conflictos de merge).

---

## 5. Garantías de Privacidad y Límites de la Fase

1. **Sin versión pública ni release:**
   - La versión en `pubspec.yaml` se mantiene exactamente en `1.1.14+16`.
   - No se generó APK release, no se crearon tags y no se publicó ningún release.
2. **Privacidad del Modo Invitado:**
   - Ningún dato de favoritos, historial de reproducción, progreso, canales recientes ni búsquedas locales fue subido o transmitido a servidores remotos o a Supabase.
   - El servicio `GuestMigrationService` únicamente inspecciona recuentos a nivel de almacenamiento local para informar al usuario de manera transparente, y almacena una decisión local (`pending`, `declined`, `acceptedForPhase3`).
3. **Seguridad de Secretos:**
   - No se almacenó ningún secret `service_role`, `sb_secret_`, contraseñas ni tokens en el repositorio Git, assets ni logs.
4. **Fase 3 Próxima:**
   - No se ha iniciado la fase de catálogo, sincronización de contenidos ni recomendaciones.
   - La Fase 3 implementará la paginación de catálogo en Supabase, caché local indexado y refresco diferencial antes de proceder a la ingesta masiva de catálogo.
