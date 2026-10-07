# HourTV Admin Workspace Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implementar el diseño B aprobado del panel, con navegación centrada y todas las acciones actuales operativas, verificarlo y publicarlo.

**Architecture:** Conservar el editor, APIs, publicación y autenticación existentes. Un módulo puro modela filas, filtros, selección y cambios; un controlador DOM conecta ese modelo a los handlers actuales mediante un adaptador explícito. Una hoja de estilos dedicada define el espacio de trabajo sin rehacer la aplicación.

**Tech Stack:** HTML, CSS, JavaScript clásico/UMD, Node `node:test`, módulos actuales del admin, Vercel.

**Spec:** `docs/superpowers/specs/2026-10-07-admin-workspace-design.md`

## Global Constraints

- Catálogo · Pendientes · TV en vivo · Servidores debe estar centrado respecto al ancho del encabezado.
- Paginación de 25 filas por defecto, con tamaños 25/50/100 y un máximo de 100 filas montadas en las listas del nuevo espacio de trabajo.
- Filtrado con demora breve (150 ms).
- No rediseñar la web pública, Android ni TV; no añadir servicios externos ni cambiar credenciales, permisos o esquema de base de datos.
- No introducir blur grande fijo, animaciones por fila ni sombras costosas durante scroll. Respetar movimiento reducido.
- Preservar los cambios ajenos ya presentes en el worktree.
- No publicar un cambio meramente visual con funciones rotas.

## Review Focus

1. IDs repetidos o ausentes: no abrir ni eliminar otro título al filtrar/paginar (Task 1/3).
2. Datos importados con campos opcionales, HTML en títulos o imágenes inválidas: no romper render ni ejecutar contenido (Task 1/3).
3. Cambio de repositorio durante una operación: no atribuir el resultado ni una base anterior a la conexión nueva (Task 4).
4. Modificación local durante la publicación o restauración tardía de IndexedDB: conservar el cambio y mostrarlo pendiente (Task 4).
5. Catálogo grande, página vacía tras eliminar y ventanas pequeñas: DOM limitado, selección válida y controles accesibles (Task 1/2/5).

## File map

- `admin/workspace-model.js`: funciones puras UMD; sin DOM, red o almacenamiento.
- `admin/workspace-model.test.js`: filtros, paginación, identidad y diferencias.
- `admin/workspace-ui.js`: render de tabla/inspector, navegación y conexión mediante adaptador.
- `admin/workspace-ui.test.js`: pruebas del controlador con DOM fixture y handlers espía.
- `admin/workspace.css`: layout, colores, tabla, inspector, controles y estados responsive.
- `admin/workspace-layout.test.js`: contratos de estructura, estilos y límites.
- `admin/index.html`: shell del panel y adaptador a funciones existentes; conservar formularios y scripts.
- `admin/catalog-publish.js`: notificar cambios de base/operación sin cambiar la combinación ni el formato del catálogo.
- `admin/catalog-publish.test.js`: regresión de publicación e indicador de cambios.
- `admin/workspace-status.test.js`: estados de conexión y concurrencia.

## Task 1: Modelo paginado e identidad estable

**Files:** Create `admin/workspace-model.js`, `admin/workspace-model.test.js`.

**Interfaces:** UMD `HourTVWorkspaceModel` / CommonJS exports:
- `buildRows(catalog, baseline): Row[]`; Row = `{key, collection, index, item, missing, change}`. `collection` es movies/series/sources; `index` siempre de la colección original. `missing` conserva año/género/rating para VOD. `change` es unknown/unchanged/added/modified.
- `getView(rows, options): {rows,total,page,pageCount,pageSize}`; options = `{section,type,status,query,page,pageSize}`. section = catalog/pending/live; type = all/movies/series; status = all/complete/incomplete/changed. Sin mutaciones de datos.
- `summarizeChanges(catalog, baseline): {known,added,modified,removed,total}`; null baseline implica `known:false`.
- `resolveSelection(rows, key): Row|null`; ID con colección para claves normales; desambiguar IDs repetidos/ausentes, no asumir unicidad sin comprobarla.

- [ ] Escribir tests rojos llamados `limits_large_catalog`, `keeps_original_index_after_filter`, `duplicate_and_missing_ids`, `optional_fields`, `pending_is_metadata_not_draft`, `clamps_page_after_delete`, `unknown_baseline`, `counts_added_modified_removed`, `nested_server_and_episode_changes`. Afirmaciones mínimas:
  ```js
  assert.equal(getView(rows10000, {section:'catalog',pageSize:25,page:1}).rows.length,25);
  assert.equal(getView(rows10000, {section:'catalog',pageSize:500,page:1}).rows.length,100);
  assert.equal(getView(rows10000, {section:'catalog',pageSize:25,page:99999}).page,400);
  assert.equal(summarizeChanges(catalog,null).known,false);
  assert.equal(filtered.rows[0].index,originalIndex);
  assert.equal(new Set(duplicateRows.map(row=>row.key)).size,duplicateRows.length);
  ```
- [ ] Ejecutar `node --test workspace-model.test.js` desde admin y confirmar fallo por módulo/API faltante.
- [ ] Implementar las interfaces; usar Map para comparación por identidad y comparación estructural independiente del orden de propiedades. No crear timestamps ni campos de estado dentro del catálogo.
- [ ] Repetir el comando: todos los tests pasan; confirmar límite de 100 y entradas sin mutar.
- [ ] Commit solo de los dos archivos con mensaje `feat(admin): add paginated workspace model`.

## Task 2: Shell, menú centrado y lenguaje visual

**Files:** Modify `admin/index.html` (header/nav/main/footer); Create `admin/workspace.css`, `admin/workspace-layout.test.js`.

**Interfaces:** IDs persistentes `search`, `list`, `overlay`, `modal`, `status`, `btn-supabase-auth`; nuevos `workspace-tabs`, `workspace-title`, `workspace-actions`, `workspace-utilities`, `workspace-connection`, `workspace-filters`, `workspace-inspector`, `workspace-pagination`, `workspace-server-tabs`, `workspace-change-count`. El controlador Task 3 usa estos IDs.

- [ ] Tests rojos: cuatro secciones primarias exactas; barra de utilidades y conexión distintas; una única búsqueda; editor/overlay existentes; reglas para header con columnas laterales simétricas y menú central, breakpoints móvil/tablet, `:focus-visible`, movimiento reducido y límite de miniaturas. Verificar que logo/acciones de anchos distintos no determinan el centro de nav.
- [ ] Ejecutar `node --test workspace-layout.test.js` y comprobar que el shell antiguo falla.
- [ ] Sustituir shell y enlazar CSS dedicado. Desktop header `minmax(0,1fr) auto minmax(0,1fr)`; a ancho insuficiente mover nav a una fila centrada, sin colisión. Panel principal aproximadamente 65/35; apilar bajo 1000 px. Negro/carbón/blanco y esmeralda; sin emojis como iconografía principal ni acento rojo decorativo.
- [ ] Mantener todos los IDs/formularios necesarios; no quitar scripts de autenticación, recuperación o editor. Mantener atribución TMDB y punto de acceso URL IPTV.
- [ ] Repetir tests de layout y `node --test episode-artwork-form.test.js` sin regresiones.
- [ ] Commit de shell, CSS y test: `feat(admin): build centered workspace shell`.

## Task 3: Tabla, inspector y puente a acciones existentes

**Files:** Create `admin/workspace-ui.js`, `admin/workspace-ui.test.js`; Modify `admin/index.html` (render/renderTabs/setTab y adaptador final).

**Interfaces:** `HourTVWorkspaceUI.createWorkspace({root,model,adapter}): {render,setSection,setFilters,setPage,select,refreshConnection,destroy}`. root = document. adapter expone `getCatalog()`, `getBaseline()`, `getConfig()`, `getCounts()`, `openItem(row)`, `addItem(type)`, `runAction(name)`, `renderServerSection(id)`. Acciones nombradas: trends/export/import/load/config/auth/publish/copyRaw/copyIptv/openRepo. La importación entrega el evento original al handler `importJson(event)`.

- [ ] Tests rojos con fixtures: filtro/paginación preservan índice original, selección no abre editor, Abrir editor llama a la fila correcta, movimiento movies→series conserva selección si ID único, eliminación limpia selección, HTML de título se escapa, imagen inválida muestra fallback. Cada botón visible llama una vez al handler espía correspondiente; no se filtran passwords/URLs con credenciales en inspector.
- [ ] Ejecutar `node --test workspace-ui.test.js` y verificar fallos de comportamiento real, no solo existencia de strings.
- [ ] Implementar controlador usando Task 1. Tabla máximo 100 filas, 25 iniciales; debounce búsqueda 150 ms, cancelación en destroy/cambio de sección; Enter aplica búsqueda pendiente. Inspector de consulta con Abrir editor, details de temporadas/servidores/información; no duplicar formulario editable.
- [ ] Integrar adaptador en script final después de los módulos originales. `openItem` fija la colección real antes de `openEditor(row.index)`. Mantener estado primario separado de `activeTab` usado por editor; guardar no debe saltar el usuario fuera de su sección. `renderServerSection` delega a renderDownServers/renderBackupProviders/renderNotifications y mantiene sus controles/búsquedas. Navegación secundaria conserva badges reales.
- [ ] Proteger operación de carga ante cambios locales con confirmación; evitar doble envío de carga/tendencias/publicación; desbloquear controles incluso en error. Reusar editor y utilidades originales, sin rutas nuevas a APIs.
- [ ] Ejecutar modelo/UI/layout y regresiones `node --test episode-artwork*.test.js tmdb-api.test.js catalog-sync.test.js catalog-publish.test.js`.
- [ ] Commit: `feat(admin): wire catalog table and inspector to existing workflows`.

## Task 4: Estado real de conexión y cambios locales

**Files:** Modify `admin/catalog-publish.js`, `admin/index.html`, `admin/workspace-ui.js`, `admin/catalog-publish.test.js`; Create `admin/workspace-status.test.js`.

**Interfaces:** `getBaseline()` retorna catálogo confirmado o null (Task 1). `refreshConnection({context,state,message})` acepta context = owner/repo/branch/path, state = unconfigured/configured/checking/success/error. Sin token en context. Emitir `hourtv:catalog-base-changed` después de restaurar/persistir base y `hourtv:github-operation` al empezar/terminar carga/publicación. El adaptador escucha y llama refreshConnection/render; no lanzar fetch al abrir el panel.

- [ ] Tests rojos: guardar config solo indica Configurado, sin comprobar; 401/404/éxito usan mensajes exactos; resultado tardío de otro context no cambia estado actual; base sin asociación fiable al repo se muestra desconocida; restauración tardía no pisa base nueva; publicación seguida de edición local mantiene contador >0.
- [ ] Ejecutar `node --test workspace-status.test.js catalog-publish.test.js` y confirmar los nuevos casos fallan antes del cambio.
- [ ] Instrumentar restoreCatalogBase/persistCatalogBase y carga/publicación con eventos opcionales seguros (tests Node pueden carecer de CustomEvent/document). Preservar return true/false, throwOnError, skipReplacementFinalize y secuencia actual de sincronización.
- [ ] Asociar la base para el indicador al contexto de repo en metadatos auxiliares, no en catalog.json. Una base legacy sin asociación no justifica afirmar publicado. No cambiar el algoritmo existente de merge ni recuperación. Refrescar diff al mutar catálogo/base, no durante scroll.
- [ ] Mostrar Sin configurar / Configurado, sin comprobar / Comprobando / Última operación correcta / Error; nunca Conectado solo por cfg.owner/repo. Mostrar Base remota no cargada sin base confiable. Contar añadidos/modificados/eliminados; no usar números del mockup.
- [ ] Repetir status/publication/model tests y suites de reemplazo/publicación existentes; sin regresiones.
- [ ] Commit: `fix(admin): show verified connection and unpublished changes`.

## Task 5: Regresión, revisión y publicación

**Files:** Tests existentes y nuevos; ajustes limitados a archivos del admin anteriores si la verificación descubre defectos.

- [ ] Antes de Task 1, verificar git-dir/common-dir y trabajar en el worktree ya vinculado, branch `codex/android-live-no-pause-1.1.37`. Ejecutar suite admin como baseline. Si falta pg, instalar exactamente el lockfile con `npm ci` dentro de admin, sin actualizar dependencias. Registrar los fallos existentes de replacement-admin-actions; no ocultarlos ni arreglarlos incidentalmente.
- [ ] Ejecutar `npm test` desde admin al finalizar; comparar con baseline y exigir cero fallos nuevos. Ejecutar explícitamente pruebas TMDB/episodios/catálogo y todos `workspace-*.test.js`.
- [ ] Probar catálogo sintético de 10000 elementos: DOM de tabla <=100 filas y selección correcta tras filtro, carga, importación y eliminación. Medir render/scroll mediante navegador disponible; distinguir cantidad de DOM comprobada de fluidez medida.
- [ ] Inspeccionar 1440/1366/768/390 px: centro geométrico nav, cabecera sin colisiones, tabla e inspector, focus/teclado, texto largo, fallback de imágenes y controles. Capturas solo con datos sintéticos, sin tokens ni fuentes privadas. Si herramientas visuales fallan, informar esa limitación antes de publicación y no declarar inspección realizada.
- [ ] Revisar de extremo a extremo utilidades con red simulada: importar/exportar JSON, config/carga/publicación/tendencias, errores y cancelación, todos los tipos de fuente y secciones de servidores. No lanzar pruebas destructivas en catálogo real.
- [ ] Solicitar revisión independiente de la rama según requesting-code-review; resolver problemas importantes y repetir pruebas. Confirmar diff contiene solo archivos previstos y no los cambios ajenos de Flutter/web.
- [ ] Verificar proyecto Vercel real y rootDirectory admin con CLI antes de desplegar. Desde raíz: `vercel deploy . --project prj_HQctkaWHfrTqnobZ9D3X68fIzgev --scope team_TgwmaPWckfJpJLyigzuZOjYJ --prod --skip-domain --yes`. Usar reglas .vercelignore existentes; no crear proyecto nuevo.
- [ ] Comprobar HTML/CSS/JS del despliegue y endpoint TMDB con datos públicos, revisar errores. Si todo lo exigible está verificado, promover el URL retornado con `vercel promote <deployment-url> --scope team_TgwmaPWckfJpJLyigzuZOjYJ --yes --timeout 1m`.
- [ ] Verificar alias `https://hourtv-adming.vercel.app`, comunicar qué se publicó, pruebas reales y cualquier limitación restante. Si hay fallo no promocionar y conservar la versión actual.

## Execution handoff

Recomendación: **Native**, implementación en esta conversación y revisión independiente al final. Las tareas dependen del mismo adaptador y editor monolítico; una ejecución secuencial evita cambios simultáneos en `index.html`.

La especificación está aprobada. Este plan requiere revisión y elección de ejecución antes de modificar código del producto.
