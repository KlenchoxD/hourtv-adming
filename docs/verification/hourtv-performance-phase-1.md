# Verificación Fase 1: Rendimiento, Carga y Fluidez (HourTV)

**Fecha:** 2026-09-09
**Versión de la app:** 1.1.14+16 (sin cambios de versión pública)
**Plan de ejecución:** `docs/superpowers/plans/2026-09-09-hourtv-performance-loading-phase-1.md`
**Especificación:** `docs/superpowers/specs/2026-09-09-hourtv-supabase-catalog-sync-performance-design.md`

---

## 1. Resumen Ejecutivo

La Fase 1 implementa estrictamente las optimizaciones de rendimiento, fluidez y carga inicial en HourTV sin introducir Supabase todavía. Se resuelven los cuellos de botella de renderizado, cálculo repetitivo, construcción anticipada de destinos, hero erróneo y falta de consistencia visual en tarjetas e historial de búsqueda.

Todos los cambios fueron desarrollados y verificados mediante TDD (Test-Driven Development), con un resultado final de **225 pruebas unitarias y de widgets aprobadas (100%)**, **0 advertencias en `flutter analyze`** y **`git diff --check` limpio (código de salida 0)**.

---

## 2. Evidencia Determinista

### A. Normalizaciones en `CatalogPresentationIndex`
- **Problema previo:** Búsquedas, filtros de tipo y género ejecutaban normalizaciones de texto, eliminación de tildes y mapeos regex repetidamente dentro de cada ciclo de `build()`.
- **Solución implementada:** `CatalogPresentationIndex.build()` precalcula y almacena registros inmutables `_IndexedChannel` con título normalizado, términos de búsqueda concatenados, géneros normalizados, año parseado y flags de tipo.
- **Medición determinista (`test/catalog_presentation_index_test.dart`):**
  - Conteo de normalizaciones al construir el índice sobre el catálogo: exactamente igual a los campos requeridos por título.
  - Conteo de normalizaciones durante búsquedas subsecuentes: **0 incrementos**.
  - Reutilización de términos mediante caché estática `_queryTermsCache` y `_genreTermsCache`.

### B. Construcción Perezosa de Destinos en Shell Móvil
- **Problema previo:** `IndexedStack` construía las 5 pestañas completas (`HourTvMobileHome`, `HourTvMobileTvGuide`, `HourTvMobileSearch`, `HourTvMobileLibrary`, `HourTvProfilePage`) inmediatamente al arrancar, aunque el usuario solo estuviese viendo Inicio.
- **Solución implementada:** `HourTvMobileShell` utiliza `Stack` + `Offstage` + `TickerMode` con un mapa perezoso `_builtDestinations`.
- **Medición determinista (`test/lazy_mobile_destinations_test.dart`):**
  - Al abrir la app en Inicio: **1 destino construido** (`builtCount == 1`). Las otras 4 pestañas no existen en el árbol (`builtCount` de TV, Buscar, Biblioteca y Perfil permanece en 0).
  - Al cambiar de pestaña (ej. a TV): solo se construye la pestaña visitada (`builtCount == 2`).
  - Al volver a Inicio: no se reconstruye el estado del destino existente.
  - El destino inactivo desactiva animaciones y temporizadores mediante `TickerMode(enabled: false)`.

### C. Máquina de Estados de Preparación Inicial (`CatalogReadiness`)
- **Problema previo:** `ContentStore.load()` marcaba la carga como terminada inmediatamente al encontrar cualquier caché local, permitiendo que la interfaz parpadeara o mostrase contenido incompleto antes de tener el catálogo sincronizado.
- **Solución implementada:** `CatalogReadiness` y `HourTvStartupCover` coordinan fases reales en español:
  1. `restoringSession`
  2. `openingCache`
  3. `syncingCatalog`
  4. `buildingHome`
  5. `ready` / `offlineReady` / `failed`
- **Medición determinista (`test/startup_readiness_test.dart`):**
  - Con caché válida: `syncingCatalog` se mantiene activo y `initialReady` no se completa hasta que finaliza el intento remoto principal.
  - Con fallo/timeout de red y caché previa: transiciona a `offlineReady` con `canEnterApp = true` sin bloquear al usuario.
  - Primera instalación sin caché ni red: transiciona a `failed` accionable con opción de `Reintentar` (`canRetry = true`).
  - `HourTvStartupCover` se retira únicamente cuando `canEnterApp` es verdadero (`ready` u `offlineReady`).

### D. Destacados Reales en el Hero Carousel
- **Problema previo:** El carrusel principal seleccionaba arbitrariamente `movies.take(5)` sin verificar si el título estaba destacado o tenía servidor funcional.
- **Solución implementada:** `CatalogPresentationIndex.featured(limit: 5)` filtra títulos con `isFeatured == true`, imagen de fondo válida (`backdrop`) y fuente reproducible. Si no hay suficientes, recurre a títulos completos con portada válida deterministamente ordenados, nunca al orden accidental de entrada.
- **Medición determinista (`test/home_featured_hero_test.dart`):**
  - El carrusel contiene exclusivamente entradas válidas y destacadas.
  - `_HeroCarouselState` clampea el índice de página al refrescarse el catálogo para evitar desbordamientos o páginas en blanco.

### E. Unificación de Tarjetas y Búsquedas Recientes
- **Problema previo:** "Continuar viendo" utilizaba tarjetas horizontales sobredimensionadas (`_ContinueCard`) que rompían la rejilla visual; las búsquedas recientes eran `ActionChip` horizontales rígidos.
- **Solución implementada:**
  - `HourTvPosterCard` unificada con `progress` (0.0 a 1.0) y `secondaryProgressLabel` para tiempo restante.
  - Reemplazo de chips por filas compactas con icono de reloj, texto y botón de borrado explícito (`Borrar`) en `HourTvMobileSearch`.
- **Medición determinista (`test/continue_watching_test.dart` y `test/search_recent_history_ui_test.dart`):**
  - Tarjetas de continuar viendo respetan el contrato de ancho (135 px) y proporción vertical de póster.
  - Barra de progreso delgada de 3 px renderizada únicamente cuando existe progreso real (> 2% y < 95%).
  - Historial de búsqueda se oculta inmediatamente cuando el usuario ingresa texto en el buscador.

---

## 3. Verificación Automatizada

Comandos ejecutados:

```powershell
flutter pub get
flutter test
flutter analyze
git diff --check
```

### Resultados:
- **`flutter test`:** 225 de 225 pruebas aprobadas (0 fallos).
- **`flutter analyze`:** `No issues found! (0 warnings, 0 errors, 0 infos)`.
- **`git diff --check`:** Código de salida 0 (sin espacios en blanco anómalos ni marcadores de conflicto).

---

## 4. Artefacto Interno Generado

- **Tipo:** APK de depuración interna (no publicada, no añadida al repositorio Git).
- **Ruta:** `artifacts/internal/HourTV-performance-phase-1-debug.apk`
- **Tamaño:** 196,016,561 bytes (~186.9 MB)
- **SHA-256:** `73A52A56D0F45FB2B57C012784C7566CD54522F7383B8FF06C430100605B04CC`
- **Comprobación ADB:** `adb devices` reportó que no hay dispositivos autorizados conectados en este entorno; la prueba en hardware se difiere a la sesión con dispositivo físico disponible.

---

## 5. Estado de Git y Conclusión de Fase 1

Commits de la Fase 1:
- `8aef772`: `perf(catalog): crear índice de presentación reutilizable` (Task 1)
- `89f0bcb`: `fix(startup): mantener la carga hasta que el catálogo esté listo` (Task 2)
- `5518b5a`: `perf(mobile): crear destinos únicamente al visitarlos` (Task 3)
- `60699a6`: `perf(search): reutilizar el índice del catálogo` (Task 4)
- `59abd01`: `fix(home): mostrar destacados reales en el hero` (Task 5)
- `622be22`: `refactor(mobile): unificar tarjetas y búsquedas recientes` (Task 6)
- Task 7 (actual): verificación completa, documentación de evidencias y artefacto interno de depuración.

Límite de fase respetado: **No se ha iniciado la fase de integración con Supabase**.
