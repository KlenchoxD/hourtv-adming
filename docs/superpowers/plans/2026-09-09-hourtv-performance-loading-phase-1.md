# HourTV Performance and Loading Phase 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make HourTV open into a consistent catalog, remove avoidable search and navigation lag, select real featured titles, and align recent-search and continue-watching UI before introducing Supabase.

**Architecture:** Keep `ContentStore` compatible while adding explicit initial readiness, an immutable presentation index, and lazy page construction. UI reads precomputed selectors instead of scanning the catalog inside `build()`. This local/JSON-compatible phase establishes the performance baseline for the later Supabase repository.

**Tech Stack:** Flutter/Dart 3.12, `ChangeNotifier`, existing `ContentStore`, Flutter widget tests, deterministic instrumentation.

**Spec:** `docs/superpowers/specs/2026-09-09-hourtv-supabase-catalog-sync-performance-design.md`

## Global Constraints

- Do not change `1.1.14+16` or replace public release `v1.1.14`.
- Do not add Supabase dependencies in this phase.
- Preserve JSON/cache fallback, Guest mode, current playback and profile behavior.
- Do not block startup on TMDB enrichment, IPTV VOD, EPG, trending or recommendations.
- Do not transmit search history or performance telemetry.
- Use TDD and explicit per-task staging; never use `git add .` or `git add -A`.

---

### Task 1: Catalog presentation index

**Files:**
- Create: `lib/services/catalog_presentation_index.dart`
- Create: `test/catalog_presentation_index_test.dart`
- Modify: `lib/mobile_ui/hourtv_genre_service.dart`

**Interfaces:**
- Consumes: `Channel`, `MediaType`, `HourTvGenreService.extractItemGenres(Channel)`.
- Produces: `CatalogPresentationIndex.build`, `search`, `featured`, `genresFor`.

- [ ] **Step 1: Write failing tests**

```dart
test('search combines text type genre and sort', () {
  final index = CatalogPresentationIndex.build(sampleCatalog);
  final result = index.search(const CatalogQuery(
    text: 'misterio',
    type: ContentTypeFilter.series,
    genre: 'Drama',
    sort: CatalogSort.titleAscending,
  ));
  expect(result.map((e) => e.name), orderedEquals(['Caso Alfa']));
});

test('featured requires flag artwork and playable source', () {
  final result = CatalogPresentationIndex.build(sampleCatalog).featured();
  expect(result.every((item) => item.isFeatured &&
      (item.backdrop ?? '').trim().isNotEmpty && item.url.trim().isNotEmpty),
      isTrue);
});
```

Generate 10,000 entries, run 20 searches, and assert `normalizationCountForTest` does not increase after index construction. Do not assert device-specific milliseconds.

- [ ] **Step 2: Run RED test**

```powershell
flutter test test/catalog_presentation_index_test.dart
```

Expected: missing `CatalogPresentationIndex` and `CatalogQuery`.

- [ ] **Step 3: Implement immutable index**

```dart
enum ContentTypeFilter { all, movies, series, anime, novels }
enum CatalogSort { newest, oldest, titleAscending }

class CatalogQuery {
  const CatalogQuery({
    this.text = '',
    this.type = ContentTypeFilter.all,
    this.genre,
    this.sort = CatalogSort.newest,
  });
  final String text;
  final ContentTypeFilter type;
  final String? genre;
  final CatalogSort sort;
}

class CatalogPresentationIndex {
  static CatalogPresentationIndex build(List<Channel> channels);
  List<Channel> search(CatalogQuery query);
  List<Channel> featured({int limit = 5});
  List<String> genresFor(ContentTypeFilter type);
}
```

Each private record stores the original channel, normalized searchable text, normalized genres/title, parsed year, type flags, valid-artwork flag and playable-source flag. Normalize once. `featured()` uses valid editorial flags and deterministic ordering; if none qualify, use deterministic complete-content fallback, never input order.

- [ ] **Step 4: Verify GREEN**

```powershell
flutter test test/catalog_presentation_index_test.dart test/hourtv_genre_service_test.dart
```

- [ ] **Step 5: Commit**

```powershell
git add lib/services/catalog_presentation_index.dart lib/mobile_ui/hourtv_genre_service.dart test/catalog_presentation_index_test.dart
git commit -m "perf(catalog): crear índice de presentación reutilizable"
```

### Task 2: Explicit initial readiness and startup cover

**Files:**
- Modify: `lib/services/content_store.dart`
- Create: `lib/new_ui/hourtv_startup_cover.dart`
- Modify: `lib/main.dart`
- Modify: `test/home_loading_state_test.dart`
- Create: `test/startup_readiness_test.dart`

**Interfaces:**
- Consumes: cache restore, `_loadAssetSources`, `_refreshContent`.
- Produces: `CatalogLoadPhase`, `CatalogReadiness`, `ContentStore.readiness`, `ContentStore.initialReady`, `HourTvStartupCover`.

- [ ] **Step 1: Write failing readiness tests**

Use injected cache and remote loaders. Cover first install, valid cache, remote success, remote timeout with cache, timeout without cache, retry, and actionable failure. Assert cached data does not finish initial readiness while a first remote attempt is pending.

```dart
cache.complete(cachedCatalog);
expect(store.readiness.phase, CatalogLoadPhase.syncingCatalog);
expect(store.initialReady, doesNotComplete);
remote.complete(remoteCatalog);
await expectLater(store.initialReady, completes);
expect(store.readiness.phase, CatalogLoadPhase.ready);
```

- [ ] **Step 2: Run RED test**

```powershell
flutter test test/startup_readiness_test.dart test/home_loading_state_test.dart
```

- [ ] **Step 3: Add readiness types**

```dart
enum CatalogLoadPhase {
  restoringSession,
  openingCache,
  syncingCatalog,
  buildingHome,
  ready,
  offlineReady,
  failed,
}

class CatalogReadiness {
  const CatalogReadiness(this.phase, {this.message, this.canRetry = false});
  final CatalogLoadPhase phase;
  final String? message;
  final bool canRetry;
  bool get canEnterApp =>
      phase == CatalogLoadPhase.ready || phase == CatalogLoadPhase.offlineReady;
}
```

Complete `initialReady` exactly once after remote primary catalog success, or after remote failure/timeout with valid cache/fallback, or actionable failure with neither. Derive legacy `loading` from readiness. Do not wait for trending, EPG, VOD, TMDB enrichment or recommendations.

- [ ] **Step 4: Mount startup cover**

`HourTvStartupCover` listens only to readiness and shows the approved Spanish stages. It has no timer-based completion. Failed state exposes `Reintentar`. Remove the cover after scheduling the first consistent Home frame. Keep profile-gate behavior intact.

- [ ] **Step 5: Verify GREEN and commit**

```powershell
flutter test test/startup_readiness_test.dart test/home_loading_state_test.dart test/hourtv_mobile_ui_test.dart
git add lib/services/content_store.dart lib/new_ui/hourtv_startup_cover.dart lib/main.dart test/home_loading_state_test.dart test/startup_readiness_test.dart
git commit -m "fix(startup): mantener la carga hasta que el catálogo esté listo"
```

### Task 3: Lazy mobile destinations

**Files:**
- Modify: `lib/mobile_ui/hourtv_mobile_shell.dart`
- Create: `test/mobile_lazy_pages_test.dart`

**Interfaces:**
- Consumes: `HourTvMobileDestination` and existing destination widgets.
- Produces: cached lazy destination construction.

- [ ] **Step 1: Write failing lazy tests**

Inject builders or test counters. Initially only Home builds. Visiting Search builds it once; leaving and returning preserves its state and does not rebuild its root. TV, Library and Profile remain unbuilt until visited.

- [ ] **Step 2: Run RED test**

```powershell
flutter test test/mobile_lazy_pages_test.dart
```

- [ ] **Step 3: Implement lazy cached pages**

Maintain a map keyed by `HourTvMobileDestination`. Insert each page on first navigation. Render created pages using `Offstage` plus `TickerMode`, or a focused lazy-index helper. Progress changes must not recreate Search or TV.

- [ ] **Step 4: Verify and commit**

```powershell
flutter test test/mobile_lazy_pages_test.dart test/hourtv_mobile_ui_test.dart test/continue_watching_test.dart
git add lib/mobile_ui/hourtv_mobile_shell.dart test/mobile_lazy_pages_test.dart
git commit -m "perf(mobile): crear destinos únicamente al visitarlos"
```

### Task 4: Indexed mobile search

**Files:**
- Modify: `lib/mobile_ui/hourtv_mobile_shell.dart`
- Modify: `lib/services/catalog_presentation_index.dart`
- Modify: `test/hourtv_mobile_search_filters_test.dart`
- Create: `test/mobile_search_performance_test.dart`

**Interfaces:**
- Consumes: Task 1 index/query types.
- Produces: one index per catalog snapshot and stale-query suppression.

- [ ] **Step 1: Write failing performance tests**

Verify a five-character typing sequence commits one debounced query; filter/sort and scroll reuse the index; replacing the catalog builds one new index. Assert normalization/build counters, not wall-clock timing.

- [ ] **Step 2: Run RED test**

```powershell
flutter test test/mobile_search_performance_test.dart test/hourtv_mobile_search_filters_test.dart
```

- [ ] **Step 3: Replace `_results()` rescans**

Build in `initState`, rebuild in `didUpdateWidget` only for a new snapshot, and retain the current result list. `_onScroll` reads its length without filtering again. Use a monotonically increasing query generation so delayed work cannot publish stale results. Preserve compact `TIPO` and `GÉNERO` selectors.

- [ ] **Step 4: Verify and commit**

```powershell
flutter test test/mobile_search_performance_test.dart test/hourtv_mobile_search_filters_test.dart test/search_genre_tabs_no_scroll_test.dart
git add lib/mobile_ui/hourtv_mobile_shell.dart lib/services/catalog_presentation_index.dart test/hourtv_mobile_search_filters_test.dart test/mobile_search_performance_test.dart
git commit -m "perf(search): reutilizar el índice del catálogo"
```

### Task 5: Correct featured hero

**Files:**
- Modify: `lib/mobile_ui/hourtv_mobile_shell.dart`
- Modify: `test/home_ver_mas_test.dart`
- Create: `test/home_featured_hero_test.dart`

**Interfaces:**
- Consumes: `CatalogPresentationIndex.featured(limit: 5)`.
- Produces: editorial hero selection and safe carousel refresh.

- [ ] **Step 1: Write failing tests**

Put non-featured entries first and featured entries later. Assert the hero contains only valid featured entries. Cover missing backdrop, empty source, deterministic fallback, and a catalog refresh that shortens the carousel while it is on a later page.

- [ ] **Step 2: Run RED test**

```powershell
flutter test test/home_featured_hero_test.dart
```

- [ ] **Step 3: Implement selection**

Remove `widget.movies.take(5)`. Pass the indexed featured list to Home. In `_HeroCarousel.didUpdateWidget`, clamp/reset the page and restart its timer only when channel identities change.

- [ ] **Step 4: Verify and commit**

```powershell
flutter test test/home_featured_hero_test.dart test/home_ver_mas_test.dart test/home_loading_state_test.dart
git add lib/mobile_ui/hourtv_mobile_shell.dart test/home_featured_hero_test.dart test/home_ver_mas_test.dart
git commit -m "fix(home): mostrar destacados reales en el hero"
```

### Task 6: Consistent cards and recent searches

**Files:**
- Modify: `lib/mobile_ui/hourtv_mobile_shell.dart`
- Modify: `lib/mobile_ui/hourtv_mobile_components.dart`
- Modify: `test/continue_watching_test.dart`
- Create: `test/search_recent_history_ui_test.dart`

**Interfaces:**
- Consumes: `HourTvPosterCard`, progress fraction, remaining time, `HourTvSearchHistoryStore`.
- Produces: poster-sized progress cards and compact recent-search rows.

- [ ] **Step 1: Write failing Continue Watching tests**

Assert the same width/aspect contract as home poster cards, a thin progress bar, real remaining time only when calculable, and direct `onOpenContinue` behavior.

- [ ] **Step 2: Write failing history tests**

Assert compact icon/text rows plus `Borrar`, no `ActionChip`, hidden history after typing, confirmed clearing only when non-empty, and persistence of an empty history.

- [ ] **Step 3: Run RED tests**

```powershell
flutter test test/continue_watching_test.dart test/search_recent_history_ui_test.dart
```

- [ ] **Step 4: Extend the shared card compatibly**

```dart
final double? progress;
final String? secondaryProgressLabel;
```

Render a thin overlay only when progress exists. Replace `_ContinueCard` with the shared poster-card contract. Replace horizontal history chips with compact rows and one clear action. Keep history local.

- [ ] **Step 5: Verify and commit**

```powershell
flutter test test/continue_watching_test.dart test/search_recent_history_ui_test.dart test/hourtv_mobile_ui_test.dart test/hourtv_mobile_search_filters_test.dart
git add lib/mobile_ui/hourtv_mobile_shell.dart lib/mobile_ui/hourtv_mobile_components.dart test/continue_watching_test.dart test/search_recent_history_ui_test.dart
git commit -m "refactor(mobile): unificar tarjetas y búsquedas recientes"
```

### Task 7: Phase verification and internal artifact

**Files:**
- Create: `docs/verification/hourtv-performance-phase-1.md`
- Do not modify: `pubspec.yaml`

**Interfaces:**
- Consumes: Tasks 1–6.
- Produces: reproducible evidence and a non-public debug APK.

- [ ] **Step 1: Run complete verification**

```powershell
flutter pub get
flutter test
flutter analyze
git diff --check
```

Expected: tests pass, analyzer has no errors/warnings, diff check exits 0.

- [ ] **Step 2: Record deterministic evidence**

Document normalization counts, destination-construction counts and readiness transitions. Do not claim frame-rate numbers from widget tests.

- [ ] **Step 3: Build internal APK without version change**

```powershell
flutter build apk --debug
```

Copy to ignored `artifacts/internal/HourTV-performance-phase-1-debug.apk`. Do not upload it to a public release.

- [ ] **Step 4: Device smoke test when one ADB device is authorized**

Install with `adb install -r`, preserving data. Test startup cover, cached/offline opening, Home scroll, Search typing, hero, recent history and Continue Watching. Record device model and observations without personal data.

- [ ] **Step 5: Commit evidence**

```powershell
git add docs/verification/hourtv-performance-phase-1.md
git commit -m "test(performance): documentar verificación de carga y fluidez"
```

## Phase Boundary

Stop after Task 7 for review. Do not start Supabase in the same working session. Subsequent independently reviewed plans will cover:

1. Supabase schema, RLS, email authentication and five-profile enforcement.
2. Paginated catalog repository, indexed local database and JSON fallback.
3. Favorites/progress sync, Guest import and personalized recommendations.
4. Admin/ServerHunter dual-write pipeline and catalog migration.
