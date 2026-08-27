# HourTV XuperTV Hybrid Android Mobile Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace only the Android phone UI with a native Flutter experience that faithfully combines the XuperTV HTML visual reference and the approved AI Studio screens under HourTV branding.

**Architecture:** A new `hybrid_mobile` feature owns the phone-only shell, presentation tokens, catalog projection, navigation, and screens. Existing `ContentStore`, playback, and profile persistence remain the sources of truth; Smart TV, tablet, and desktop continue through the existing `HourTvNewShell` branches. XuperTV-derived and AI Studio-derived screens share one navigation controller and common responsive primitives without embedding either web prototype.

**Tech Stack:** Flutter/Dart, existing HourTV services and models, `shared_preferences`, Flutter widget/golden tests, Android build tooling.

**Spec:** `docs/superpowers/specs/2026-08-27-hourtv-xupertv-hybrid-mobile-design.md`

## Global Constraints

- Android mobile only; Smart TV, tablet, and desktop must remain visually and behaviorally unchanged.
- Use the HourTV name and approved HourTV logo everywhere; zero SuperTV branding.
- Do not modify the XuperTV HTML or the approved AI Studio reference.
- XuperTV controls Home, categories, Search, Filters, Details, and Settings.
- AI Studio controls Live TV, Profiles, My Library, and Player.
- Use native Flutter widgets; do not use a WebView.
- Real repository data and real actions only; no simulated primary controls.
- Inter typography throughout.
- Minimum primary touch target is 48 logical pixels.
- Validate phone widths 360, 393, 412, 428, and 480 logical pixels.
- Preserve all unrelated dirty-worktree changes and never reset user work.
- Every implementation task uses test-first development and ends with a focused commit containing only that task's files.

## Planned File Structure

```text
references/xupertv/
  index.html                         immutable visual reference copy
  REFERENCE_MANIFEST.md             source path, checksum, capture rules

lib/hybrid_mobile/
  hybrid_mobile.dart                public exports
  hybrid_mobile_shell.dart          phone navigation, route stack, safe areas
  hybrid_mobile_destination.dart    destination and route value types
  hybrid_mobile_scope.dart          shared controllers/dependencies
  theme/hybrid_mobile_tokens.dart   colors, spacing, typography, radii
  theme/hybrid_mobile_theme.dart    ThemeData and component themes
  data/hybrid_catalog_controller.dart
  data/hybrid_catalog_models.dart
  components/hybrid_brand_header.dart
  components/hybrid_bottom_navigation.dart
  components/hybrid_category_bar.dart
  components/hybrid_poster_card.dart
  components/hybrid_section.dart
  components/hybrid_overlay_menu.dart
  screens/hybrid_home_screen.dart
  screens/hybrid_search_screen.dart
  screens/hybrid_detail_screen.dart
  screens/hybrid_settings_screen.dart
  screens/hybrid_profile_flow.dart
  screens/hybrid_live_tv_screen.dart
  screens/hybrid_library_screen.dart
  screens/hybrid_player_screen.dart

test/hybrid_mobile/
  support/hybrid_test_app.dart
  reference/reference_manifest_test.dart
  theme/hybrid_mobile_theme_test.dart
  data/hybrid_catalog_controller_test.dart
  components/hybrid_components_test.dart
  screens/hybrid_home_screen_test.dart
  screens/hybrid_search_screen_test.dart
  screens/hybrid_detail_screen_test.dart
  screens/hybrid_profile_flow_test.dart
  screens/hybrid_live_tv_screen_test.dart
  screens/hybrid_library_screen_test.dart
  screens/hybrid_player_screen_test.dart
  hybrid_mobile_shell_test.dart
  regression/non_phone_shell_regression_test.dart
  responsive/hybrid_phone_widths_test.dart
  goldens/                               generated reference PNGs
```

---

### Task 1: Freeze the XuperTV Reference and Establish a Reproducible Baseline

**Files:**
- Create: `references/xupertv/index.html`
- Create: `references/xupertv/REFERENCE_MANIFEST.md`
- Create: `test/hybrid_mobile/reference/reference_manifest_test.dart`

**Interfaces:**
- Consumes: external source `C:\Users\Kleiner\Downloads\ABDM\Compressed\XuperTV\XuperTV\index.html`.
- Produces: immutable repository reference with SHA-256 and a test that detects accidental edits.

- [ ] **Step 1: Copy the source byte-for-byte and calculate SHA-256**

Use PowerShell `Copy-Item -LiteralPath` followed by `Get-FileHash -Algorithm SHA256`. Record the exact source path, byte length, checksum, capture date, and the branding exception in `REFERENCE_MANIFEST.md`.

- [ ] **Step 2: Write the failing integrity test**

```dart
test('frozen XuperTV reference matches the approved checksum', () async {
  final bytes = await File('references/xupertv/index.html').readAsBytes();
  expect(sha256.convert(bytes).toString(), approvedXuperTvSha256);
});
```

- [ ] **Step 3: Add `crypto` to `dev_dependencies` only if it is not already transitively available**

Prefer the existing dependency graph. If `crypto` is unavailable, add a pinned compatible version under `dev_dependencies` in `pubspec.yaml` and update `pubspec.lock`.

- [ ] **Step 4: Run the integrity test**

Run: `flutter test test/hybrid_mobile/reference/reference_manifest_test.dart`  
Expected: PASS and the copied file's checksum equals the manifest.

- [ ] **Step 5: Commit the baseline**

```powershell
git add references/xupertv test/hybrid_mobile/reference pubspec.yaml pubspec.lock
git commit -m "test: freeze XuperTV mobile reference"
```

---

### Task 2: Build the Hybrid Mobile Theme and Responsive Metrics

**Files:**
- Create: `lib/hybrid_mobile/theme/hybrid_mobile_tokens.dart`
- Create: `lib/hybrid_mobile/theme/hybrid_mobile_theme.dart`
- Create: `test/hybrid_mobile/theme/hybrid_mobile_theme_test.dart`
- Modify: `pubspec.yaml` only if the existing Inter declaration is incomplete.

**Interfaces:**
- Consumes: existing bundled Inter assets and the approved reference colors.
- Produces: `HybridMobileTokens`, `HybridMobileMetrics`, and `HybridMobileTheme.dark()`.

- [ ] **Step 1: Write failing token and width tests**

```dart
test('reference tokens remain exact', () {
  expect(HybridMobileTokens.background, const Color(0xFF151525));
  expect(HybridMobileTokens.header, const Color(0xFF0D0D1B));
  expect(HybridMobileTokens.accent, const Color(0xFF4305EE));
});

test('393px reference uses three poster columns', () {
  final metrics = HybridMobileMetrics.fromWidth(393);
  expect(metrics.posterColumns, 3);
  expect(metrics.horizontalPadding, greaterThanOrEqualTo(12));
});
```

- [ ] **Step 2: Verify the tests fail because the types do not exist**

Run: `flutter test test/hybrid_mobile/theme/hybrid_mobile_theme_test.dart`  
Expected: FAIL with unresolved `HybridMobileTokens` and `HybridMobileMetrics`.

- [ ] **Step 3: Implement exact tokens and responsive calculations**

```dart
abstract final class HybridMobileTokens {
  static const background = Color(0xFF151525);
  static const header = Color(0xFF0D0D1B);
  static const accent = Color(0xFF4305EE);
  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFFAAA8B7);
  static const border = Color(0xFF29283A);
  static const double minTouchTarget = 48;
}

@immutable
class HybridMobileMetrics {
  const HybridMobileMetrics({required this.width, required this.horizontalPadding,
    required this.gutter, required this.posterColumns});
  factory HybridMobileMetrics.fromWidth(double width) => HybridMobileMetrics(
    width: width,
    horizontalPadding: width <= 360 ? 12 : 16,
    gutter: width <= 360 ? 8 : 10,
    posterColumns: width >= 480 ? 4 : 3,
  );
  final double width;
  final double horizontalPadding;
  final double gutter;
  final int posterColumns;
}
```

`HybridMobileTheme.dark()` must set `fontFamily: 'Inter'`, `useMaterial3: true`, exact scaffold/header colors, transparent splash overlays where the reference has none, and accessible text colors.

- [ ] **Step 4: Run theme tests and analyzer**

Run: `flutter test test/hybrid_mobile/theme/hybrid_mobile_theme_test.dart && flutter analyze lib/hybrid_mobile/theme test/hybrid_mobile/theme`  
Expected: PASS with zero analyzer errors.

- [ ] **Step 5: Commit the foundation**

```powershell
git add lib/hybrid_mobile/theme test/hybrid_mobile/theme pubspec.yaml pubspec.lock
git commit -m "feat: add hybrid mobile visual foundation"
```

---

### Task 3: Project Existing Catalog Data into Stable Mobile View Models

**Files:**
- Create: `lib/hybrid_mobile/data/hybrid_catalog_models.dart`
- Create: `lib/hybrid_mobile/data/hybrid_catalog_controller.dart`
- Create: `test/hybrid_mobile/data/hybrid_catalog_controller_test.dart`
- Reuse: `lib/services/content_store.dart`
- Reuse: `lib/studio_ui/data/studio_catalog_adapter.dart`

**Interfaces:**
- Consumes: `ContentStore.movies`, `ContentStore.series`, `ContentStore.live`, `ContentStore.toggleFavorite(...)`, existing watch/history services.
- Produces: `HybridCatalogController`, `HybridMediaItem`, `HybridMediaKind`, `HybridMediaSection`, and real filtering/sorting APIs.

```dart
enum HybridMediaKind { movie, series, anime, novela }

enum HybridSortOrder { newest, oldest, titleAscending }

class HybridCatalogController extends ChangeNotifier {
  HybridCatalogController({required ContentStore contentStore});
  Future<void> load();
  List<HybridMediaItem> get all;
  List<HybridMediaSection> get homeSections;
  List<HybridMediaItem> search(String query, {HybridMediaKind? kind});
  List<HybridMediaItem> filter({HybridMediaKind? kind, String? genre,
    HybridSortOrder order = HybridSortOrder.newest});
  Future<void> toggleMyList(String mediaId);
  bool isInMyList(String mediaId);
}
```

- [ ] **Step 1: Write failing projection, mixed-section, filtering, and favorite tests**

Use a small fake `ContentStore` fixture containing one movie, one series, one anime, and one novela. Assert stable IDs, non-empty mixed Home sections, accent-insensitive search, correct sort order, and synchronized My List state.

- [ ] **Step 2: Run the focused test and confirm failure**

Run: `flutter test test/hybrid_mobile/data/hybrid_catalog_controller_test.dart`  
Expected: FAIL because the controller does not exist.

- [ ] **Step 3: Implement the minimal adapter without duplicating repository state**

Normalize title and genre only for comparison. Keep original display strings and source objects. Subscribe once to `ContentStore` and call `notifyListeners()` only after a meaningful dataset or favorite-state change.

- [ ] **Step 4: Run data tests and analyzer**

Run: `flutter test test/hybrid_mobile/data/hybrid_catalog_controller_test.dart && flutter analyze lib/hybrid_mobile/data test/hybrid_mobile/data`  
Expected: PASS with zero analyzer errors.

- [ ] **Step 5: Commit the data projection**

```powershell
git add lib/hybrid_mobile/data test/hybrid_mobile/data
git commit -m "feat: project HourTV catalog for hybrid mobile"
```

---

### Task 4: Create Shared XuperTV-Derived Mobile Components

**Files:**
- Create: `lib/hybrid_mobile/components/hybrid_brand_header.dart`
- Create: `lib/hybrid_mobile/components/hybrid_bottom_navigation.dart`
- Create: `lib/hybrid_mobile/components/hybrid_category_bar.dart`
- Create: `lib/hybrid_mobile/components/hybrid_poster_card.dart`
- Create: `lib/hybrid_mobile/components/hybrid_section.dart`
- Create: `lib/hybrid_mobile/components/hybrid_overlay_menu.dart`
- Create: `test/hybrid_mobile/components/hybrid_components_test.dart`
- Reuse: approved HourTV logo asset already declared in `pubspec.yaml`.

**Interfaces:**
- Consumes: `HybridMobileTokens`, `HybridMobileMetrics`, `HybridMediaItem`.
- Produces: reusable header, navigation, category, card, section, and anchored overlay widgets.

- [ ] **Step 1: Write failing component contract tests**

Test that the header contains HourTV but no SuperTV; only one category is selected; a touched bottom destination has no persistent focus border; poster cards maintain a 2:3 image ratio and equal text height; overlay menus remain inside a 360 px viewport; and every icon action has a 48 px hit target and semantic label.

- [ ] **Step 2: Run the component tests to verify failure**

Run: `flutter test test/hybrid_mobile/components/hybrid_components_test.dart`  
Expected: FAIL because the widgets do not exist.

- [ ] **Step 3: Implement components using layout constraints rather than absolute coordinates**

`HybridPosterCard` exposes only stable variants:

```dart
class HybridPosterCard extends StatelessWidget {
  const HybridPosterCard({super.key, required this.item, required this.onTap,
    this.onMyList, this.showMetadata = true});
  final HybridMediaItem item;
  final VoidCallback onTap;
  final VoidCallback? onMyList;
  final bool showMetadata;
}
```

Use `AspectRatio(aspectRatio: 2 / 3)` for artwork, two title lines maximum, one metadata line, `BoxFit.cover`, and an image fallback that does not change card size.

- [ ] **Step 4: Add a 393 px component golden and run tests**

Run: `flutter test test/hybrid_mobile/components/hybrid_components_test.dart --update-goldens` once, inspect the generated PNG, then rerun without `--update-goldens`.  
Expected: PASS and no clipped labels or off-screen content.

- [ ] **Step 5: Commit shared components**

```powershell
git add lib/hybrid_mobile/components test/hybrid_mobile/components
git commit -m "feat: add XuperTV-derived mobile components"
```

---

### Task 5: Implement the Phone-Only Shell, Profile Gate, and Navigation State

**Files:**
- Create: `lib/hybrid_mobile/hybrid_mobile_destination.dart`
- Create: `lib/hybrid_mobile/hybrid_mobile_scope.dart`
- Create: `lib/hybrid_mobile/hybrid_mobile_shell.dart`
- Create: `lib/hybrid_mobile/hybrid_mobile.dart`
- Create: `test/hybrid_mobile/support/hybrid_test_app.dart`
- Create: `test/hybrid_mobile/hybrid_mobile_shell_test.dart`
- Modify: `lib/new_ui/hourtv_new_shell.dart`
- Reuse: `lib/studio_ui/data/studio_profile_repository.dart`
- Reuse: `lib/studio_ui/screens/studio_profile_gate.dart`

**Interfaces:**
- Consumes: `HybridCatalogController`, `StudioProfileRepository`, existing playback launch callbacks.
- Produces: `HybridMobileShell` and an explicit phone-only branch from `HourTvNewShell`.

```dart
enum HybridMobileDestination { home, liveTv, search, library, profile }

class HybridMobileShell extends StatefulWidget {
  const HybridMobileShell({super.key, required this.catalog,
    required this.profileRepository});
  final HybridCatalogController catalog;
  final StudioProfileRepository profileRepository;
}
```

- [ ] **Step 1: Write failing shell tests**

Cover: no profile shows the creation gate; an existing profile shows Home; tapping each destination changes exactly one indexed child; pushed details hide bottom navigation; player hides both header and bottom navigation; system back pops player/details before leaving the app; switching destinations preserves their scroll controllers.

- [ ] **Step 2: Write a non-phone regression test before changing `HourTvNewShell`**

Pump at 800 px and 1920 px widths and assert the existing tablet/TV root keys remain present while `HybridMobileShell` is absent.

- [ ] **Step 3: Run the two focused tests and verify failure**

Run: `flutter test test/hybrid_mobile/hybrid_mobile_shell_test.dart test/hybrid_mobile/regression/non_phone_shell_regression_test.dart`  
Expected: shell test FAIL; existing non-phone behavior PASS before integration.

- [ ] **Step 4: Implement shell state with `IndexedStack` and route overlays**

Keep destination selection, pushed content, and immersive player state separate. Do not encode focus as selection. Reuse the existing profile repository rather than adding another persistence store.

- [ ] **Step 5: Connect only the phone branch in `HourTvNewShell`**

Use the existing breakpoint/`forcePhoneForTesting` seam. The non-phone branches must remain byte-for-byte unchanged except for the condition that returns `HybridMobileShell` on phones.

- [ ] **Step 6: Run shell and non-phone regression tests**

Run: `flutter test test/hybrid_mobile/hybrid_mobile_shell_test.dart test/hybrid_mobile/regression/non_phone_shell_regression_test.dart`  
Expected: PASS at phone, tablet, and TV widths.

- [ ] **Step 7: Commit shell integration**

```powershell
git add lib/hybrid_mobile/hybrid_mobile.dart lib/hybrid_mobile/hybrid_mobile_destination.dart lib/hybrid_mobile/hybrid_mobile_scope.dart lib/hybrid_mobile/hybrid_mobile_shell.dart lib/new_ui/hourtv_new_shell.dart test/hybrid_mobile/hybrid_mobile_shell_test.dart test/hybrid_mobile/regression test/hybrid_mobile/support
git commit -m "feat: route Android phones through hybrid mobile shell"
```

---

### Task 6: Reproduce the XuperTV Home and Category Discovery Experience

**Files:**
- Create: `lib/hybrid_mobile/screens/hybrid_home_screen.dart`
- Create: `test/hybrid_mobile/screens/hybrid_home_screen_test.dart`
- Modify: `lib/hybrid_mobile/hybrid_mobile_shell.dart`

**Interfaces:**
- Consumes: `HybridCatalogController.homeSections`, shared components, detail route callback.
- Produces: `HybridHomeScreen` with faithful header, category row, banner, and mixed content sections.

- [ ] **Step 1: Write failing Home behavior tests**

Assert the screen shows the HourTV logo, reference category labels, banner, movies, series, anime, and novelas; contains no Live TV promotional card; changes content when a category is selected; opens details from a poster; and preserves scroll after switching bottom destinations.

- [ ] **Step 2: Run the test and confirm failure**

Run: `flutter test test/hybrid_mobile/screens/hybrid_home_screen_test.dart`  
Expected: FAIL because `HybridHomeScreen` does not exist.

- [ ] **Step 3: Implement Home using lazy slivers**

Use `CustomScrollView`, `SliverToBoxAdapter` for the banner/category row, and lazy horizontal lists or compact grids for sections. Do not nest vertical scroll views. The final bottom padding is `bottomNavigationHeight + safeAreaBottom + 12`.

- [ ] **Step 4: Capture and inspect 393 px Home golden**

Run the Home golden at `Size(393, 852)`. Compare header height, banner ratio, three-column card rhythm, section spacing, and bottom clearance to the HTML reference.

- [ ] **Step 5: Run Home tests and commit**

Run: `flutter test test/hybrid_mobile/screens/hybrid_home_screen_test.dart`  
Expected: PASS.

```powershell
git add lib/hybrid_mobile/screens/hybrid_home_screen.dart lib/hybrid_mobile/hybrid_mobile_shell.dart test/hybrid_mobile/screens/hybrid_home_screen_test.dart test/hybrid_mobile/goldens
git commit -m "feat: reproduce XuperTV Home for HourTV"
```

---

### Task 7: Implement Functional Search, Infinite Reveal, and Anchored Filters

**Files:**
- Create: `lib/hybrid_mobile/screens/hybrid_search_screen.dart`
- Create: `test/hybrid_mobile/screens/hybrid_search_screen_test.dart`
- Modify: `lib/hybrid_mobile/hybrid_mobile_shell.dart`

**Interfaces:**
- Consumes: `HybridCatalogController.search`, `HybridCatalogController.filter`, `HybridOverlayMenu`.
- Produces: XuperTV-derived Search states with real result counts and progressive rendering.

- [ ] **Step 1: Write failing search state tests**

Cover empty query, history, popular searches, accent-insensitive live filtering, actual result count, no-result state, history removal, clear-all, category filter, sort order, and progressive result reveal after scrolling near the end.

- [ ] **Step 2: Run tests to verify failure**

Run: `flutter test test/hybrid_mobile/screens/hybrid_search_screen_test.dart`  
Expected: FAIL because the screen does not exist.

- [ ] **Step 3: Implement a debounced query controller and progressive grid**

Start with 18 visible matches. Reveal 12 more when `extentAfter < 600`. Reset visible count on query/filter change. Persist only completed non-empty queries in search history. Use one scrollable and keep menus anchored inside the phone viewport.

- [ ] **Step 4: Run behavior and 360/393 px layout tests**

Run: `flutter test test/hybrid_mobile/screens/hybrid_search_screen_test.dart`  
Expected: PASS with actual counts and no overflow exceptions.

- [ ] **Step 5: Commit Search**

```powershell
git add lib/hybrid_mobile/screens/hybrid_search_screen.dart lib/hybrid_mobile/hybrid_mobile_shell.dart test/hybrid_mobile/screens/hybrid_search_screen_test.dart
git commit -m "feat: add functional XuperTV-style search"
```

---

### Task 8: Implement Compact Content Details and Episodic Selection

**Files:**
- Create: `lib/hybrid_mobile/screens/hybrid_detail_screen.dart`
- Create: `test/hybrid_mobile/screens/hybrid_detail_screen_test.dart`
- Modify: `lib/hybrid_mobile/hybrid_mobile_shell.dart`

**Interfaces:**
- Consumes: `HybridMediaItem`, My List state, playback callback, related catalog query.
- Produces: `HybridDetailScreen` for movies and episodic content.

- [ ] **Step 1: Write failing movie and series detail tests**

Assert title, discreet rating, country/year/categories, description, director, cast, My List toggle, playback, recommendation spacing, and absence of removed sections. For series, assert the season menu opens below its trigger, remains inside 360 px, labels only `Temporada N`, switches episode data, and never renders an external detached overlay.

- [ ] **Step 2: Run details tests to verify failure**

Run: `flutter test test/hybrid_mobile/screens/hybrid_detail_screen_test.dart`  
Expected: FAIL because the screen does not exist.

- [ ] **Step 3: Implement XuperTV composition with native media and metadata**

Use constrained artwork/media at the top, compact content sections, `AnimatedSize` for description/credits expansion, and shared poster cards for recommendations. Do not add Crítica editorial, Detalles técnicos, or Por qué verla.

- [ ] **Step 4: Run details tests and inspect 393 px golden**

Run: `flutter test test/hybrid_mobile/screens/hybrid_detail_screen_test.dart`  
Expected: PASS with no clipped action labels or season menus outside the frame.

- [ ] **Step 5: Commit Details**

```powershell
git add lib/hybrid_mobile/screens/hybrid_detail_screen.dart lib/hybrid_mobile/hybrid_mobile_shell.dart test/hybrid_mobile/screens/hybrid_detail_screen_test.dart test/hybrid_mobile/goldens
git commit -m "feat: add XuperTV-style content details"
```

---

### Task 9: Complete AI Studio Profile Creation, Selection, and Management

**Files:**
- Create: `lib/hybrid_mobile/screens/hybrid_profile_flow.dart`
- Create: `test/hybrid_mobile/screens/hybrid_profile_flow_test.dart`
- Modify: `lib/studio_ui/data/studio_profile_repository.dart` only for missing persistence behavior.
- Modify: `lib/hybrid_mobile/hybrid_mobile_shell.dart`

**Interfaces:**
- Consumes: `StudioProfileRepository`, `StudioProfile`, approved AI Studio avatar definitions.
- Produces: first-launch creation, launch-time selection, and profile edit flows connected to the hybrid shell.

- [ ] **Step 1: Write failing lifecycle tests**

Cover forced creation when empty, validation of trimmed names, avatar selection, successful persistence, launch selection with multiple profiles, edit, delete with at least one remaining profile, and separate active-profile selection.

- [ ] **Step 2: Run tests to verify failure**

Run: `flutter test test/hybrid_mobile/screens/hybrid_profile_flow_test.dart test/studio_ui/data/studio_profile_repository_test.dart`  
Expected: new UI tests FAIL while repository regression tests remain PASS.

- [ ] **Step 3: Implement the approved AI Studio profile views natively**

Reuse the existing repository and models. Do not create a second `SharedPreferences` key namespace. The shell must not construct catalog destinations until an active profile exists.

- [ ] **Step 4: Run profile and shell tests**

Run: `flutter test test/hybrid_mobile/screens/hybrid_profile_flow_test.dart test/hybrid_mobile/hybrid_mobile_shell_test.dart test/studio_ui/data/studio_profile_repository_test.dart`  
Expected: PASS.

- [ ] **Step 5: Commit profiles**

```powershell
git add lib/hybrid_mobile/screens/hybrid_profile_flow.dart lib/hybrid_mobile/hybrid_mobile_shell.dart lib/studio_ui/data/studio_profile_repository.dart test/hybrid_mobile/screens/hybrid_profile_flow_test.dart
git commit -m "feat: connect AI Studio profile flow"
```

---

### Task 10: Implement AI Studio My Library with Stable Sticky Controls

**Files:**
- Create: `lib/hybrid_mobile/screens/hybrid_library_screen.dart`
- Create: `test/hybrid_mobile/screens/hybrid_library_screen_test.dart`
- Modify: `lib/hybrid_mobile/hybrid_mobile_shell.dart`

**Interfaces:**
- Consumes: active-profile My List, progress/history data, `HybridSortOrder`.
- Produces: `HybridLibraryScreen` with `Mi Lista`, `Continuar viendo`, and `Historial`.

- [ ] **Step 1: Write failing library tests**

Assert tab changes produce distinct datasets, sorting updates order, My List removal updates immediately, progress is shown only where applicable, sticky controls remain non-overlapping after a long scroll, and final scroll padding equals the shared navigation clearance.

- [ ] **Step 2: Run tests to verify failure**

Run: `flutter test test/hybrid_mobile/screens/hybrid_library_screen_test.dart`  
Expected: FAIL because the screen does not exist.

- [ ] **Step 3: Implement the approved AI Studio library using slivers**

Use one pinned header delegate whose measured height includes title, primary tabs, and filters. Do not use `Positioned` for scrolling controls. Reuse `HybridPosterCard` where its visual shape matches; use an explicit continue-watching variant only for progress.

- [ ] **Step 4: Run tests at 360 and 393 px**

Run: `flutter test test/hybrid_mobile/screens/hybrid_library_screen_test.dart`  
Expected: PASS without overflow or excessive end spacing.

- [ ] **Step 5: Commit Library**

```powershell
git add lib/hybrid_mobile/screens/hybrid_library_screen.dart lib/hybrid_mobile/hybrid_mobile_shell.dart test/hybrid_mobile/screens/hybrid_library_screen_test.dart
git commit -m "feat: connect AI Studio mobile library"
```

---

### Task 11: Implement AI Studio Live TV and Real Channel Actions

**Files:**
- Create: `lib/hybrid_mobile/screens/hybrid_live_tv_screen.dart`
- Create: `test/hybrid_mobile/screens/hybrid_live_tv_screen_test.dart`
- Modify: `lib/hybrid_mobile/hybrid_mobile_shell.dart`
- Reuse: `lib/services/content_store.dart`
- Reuse: existing Live TV player/resolver services.

**Interfaces:**
- Consumes: real live channels, favorites, parental preference, playback launcher.
- Produces: `HybridLiveTvScreen` titled `TV` with the approved category model.

- [ ] **Step 1: Write failing Live TV tests**

Assert the exact category set and order, Favorites filtering, Novelas availability, `+18` hidden by default and visible only when parental settings allow it, channel favorite toggle, correct channel logo/metadata, real playback launch, and no Home live-TV promo dependency.

- [ ] **Step 2: Run tests to verify failure**

Run: `flutter test test/hybrid_mobile/screens/hybrid_live_tv_screen_test.dart`  
Expected: FAIL because the screen does not exist.

- [ ] **Step 3: Implement the AI Studio layout over existing live data**

Keep categories in one horizontal row. Use one selected category and a distinct transient pressed state. Pass channel-up/down callbacks into full-screen live playback for remote/keyboard operation without adding phone-only arrow controls.

- [ ] **Step 4: Run Live TV tests**

Run: `flutter test test/hybrid_mobile/screens/hybrid_live_tv_screen_test.dart`  
Expected: PASS.

- [ ] **Step 5: Commit Live TV**

```powershell
git add lib/hybrid_mobile/screens/hybrid_live_tv_screen.dart lib/hybrid_mobile/hybrid_mobile_shell.dart test/hybrid_mobile/screens/hybrid_live_tv_screen_test.dart
git commit -m "feat: connect AI Studio mobile Live TV"
```

---

### Task 12: Implement AI Studio Player States and Contextual Playback Actions

**Files:**
- Create: `lib/hybrid_mobile/screens/hybrid_player_screen.dart`
- Create: `test/hybrid_mobile/screens/hybrid_player_screen_test.dart`
- Modify: `lib/hybrid_mobile/hybrid_mobile_shell.dart`
- Reuse: `lib/new_ui/hourtv_player_screen.dart` playback controller/service integration where compatible.

**Interfaces:**
- Consumes: current media item, playback controller, episode sequence, intro/recap markers.
- Produces: immersive `HybridPlayerScreen` with approved AI Studio HUD states.

- [ ] **Step 1: Write failing player state tests**

Cover visible/hidden/paused controls, auto-hide timing, seek backward/forward, progress/duration, audio/subtitle sheet, quality, full screen, skip intro, skip recap, next content, system back, 48 px controls, and channel-up/down callbacks for live playback.

- [ ] **Step 2: Run tests to verify failure**

Run: `flutter test test/hybrid_mobile/screens/hybrid_player_screen_test.dart`  
Expected: FAIL because the screen does not exist.

- [ ] **Step 3: Implement the AI Studio Cinema HUD over real playback state**

Central controls use a symmetric row. The timeline remains thin. Skip actions appear above the timeline and can coexist with hidden controls. Next Content remains compact and does not obscure the video. Cancel timers and listeners in `dispose()`.

- [ ] **Step 4: Run player tests and targeted existing player regressions**

Run: `flutter test test/hybrid_mobile/screens/hybrid_player_screen_test.dart test/cast_service_test.dart`  
Expected: PASS for the new player behavior and the existing casting service regression suite.

- [ ] **Step 5: Commit Player**

```powershell
git add lib/hybrid_mobile/screens/hybrid_player_screen.dart lib/hybrid_mobile/hybrid_mobile_shell.dart test/hybrid_mobile/screens/hybrid_player_screen_test.dart
git commit -m "feat: connect AI Studio mobile player"
```

---

### Task 13: Implement Functional HourTV Settings in the XuperTV Visual Language

**Files:**
- Create: `lib/hybrid_mobile/screens/hybrid_settings_screen.dart`
- Create: `test/hybrid_mobile/screens/hybrid_settings_screen_test.dart`
- Modify: `lib/hybrid_mobile/hybrid_mobile_shell.dart`
- Reuse: existing settings and parental-control persistence.

**Interfaces:**
- Consumes: active profile, playback preferences, subtitle/audio preferences, parental-control settings.
- Produces: functional settings screen with no SuperTV social placeholders.

- [ ] **Step 1: Write failing settings tests**

Assert HourTV branding, real settings rows, persistence after reopening, parental control affects Live TV `+18`, and absence of Facebook/Instagram/Web placeholder actions.

- [ ] **Step 2: Run tests to verify failure**

Run: `flutter test test/hybrid_mobile/screens/hybrid_settings_screen_test.dart`  
Expected: FAIL because the screen does not exist.

- [ ] **Step 3: Implement settings using the HTML reference density and surfaces**

Use compact list rows and native dialogs/sheets styled with `HybridMobileTheme`. Each setting writes through the existing service and immediately updates dependent screens.

- [ ] **Step 4: Run settings and cross-screen tests**

Run: `flutter test test/hybrid_mobile/screens/hybrid_settings_screen_test.dart test/hybrid_mobile/screens/hybrid_live_tv_screen_test.dart`  
Expected: PASS.

- [ ] **Step 5: Commit Settings**

```powershell
git add lib/hybrid_mobile/screens/hybrid_settings_screen.dart lib/hybrid_mobile/hybrid_mobile_shell.dart test/hybrid_mobile/screens/hybrid_settings_screen_test.dart
git commit -m "feat: add functional hybrid mobile settings"
```

---

### Task 14: Responsive, Performance, and Visual Parity QA

**Files:**
- Create: `test/hybrid_mobile/responsive/hybrid_phone_widths_test.dart`
- Create: `test/hybrid_mobile/regression/non_phone_shell_regression_test.dart` if not already created in Task 5.
- Add: `test/hybrid_mobile/goldens/*.png`
- Modify: hybrid mobile files only for defects discovered by these tests.

**Interfaces:**
- Consumes: complete hybrid shell and all screens.
- Produces: acceptance evidence across phone sizes and non-phone regression protection.

- [ ] **Step 1: Add a matrix test for 360, 393, 412, 428, and 480 px widths**

For each width, pump Home, Search, Details, Live TV, Library, Profile, Settings, and representative Player states. Fail on Flutter overflow exceptions, missing semantics, off-screen bottom navigation, or touch targets below 48 px.

- [ ] **Step 2: Add golden baselines at 393 × 852**

Create goldens for Home, Search empty/results, movie details, series details with menu open, Live TV, Library, Profile selection, Settings, and Player controls visible. Inspect each generated PNG before accepting it.

- [ ] **Step 3: Add rebuild and scroll-performance assertions**

Use widget counters around destination roots to verify changing one destination does not rebuild all destination subtrees. Exercise long grids with `scrollUntilVisible` and assert no uncaught exceptions or nested-scroll layout failures.

- [ ] **Step 4: Run all hybrid tests and full analyzer**

Run: `flutter test test/hybrid_mobile && flutter analyze`  
Expected: all tests PASS and zero analyzer errors introduced by this migration.

- [ ] **Step 5: Run existing project tests**

Run: `flutter test`  
Expected: PASS. If an unrelated pre-existing failure occurs, capture its exact existing behavior and verify the hybrid changes did not touch its files before proceeding.

- [ ] **Step 6: Commit QA fixes and baselines**

```powershell
git add lib/hybrid_mobile test/hybrid_mobile
git commit -m "test: verify hybrid mobile visual parity"
```

---

### Task 15: Android Build, Physical Device Smoke Test, and Safe Legacy Retirement

**Files:**
- Modify: `lib/main.dart` only if the final phone entry is not already routed through `HourTvNewShell`.
- Modify/Delete: obsolete phone-only files only after graph and test proof that no code references them.
- Create: `docs/superpowers/reports/2026-08-27-hourtv-hybrid-mobile-qa.md`

**Interfaces:**
- Consumes: complete, tested hybrid mobile implementation.
- Produces: installable Android build, device evidence, and a minimal safe cleanup.

- [ ] **Step 1: Trace phone entry and old mobile references**

Use codebase-memory `trace_path` from `main`, `HourTvNewShell`, and `HybridMobileShell`. Delete only obsolete phone presentation files with zero inbound references outside tests. Never delete shared services, models, TV, tablet, or desktop widgets.

- [ ] **Step 2: Build the Android app**

Run: `flutter build apk --debug`  
Expected: successful debug APK.

- [ ] **Step 3: Install on the connected Android device**

Use the configured ADB connection, install the debug APK, and launch HourTV. Do not alter device data unless the profile-first-launch flow must be tested; if cleared, record that fact in the QA report.

- [ ] **Step 4: Execute physical-device smoke scenarios**

Verify profile creation/selection, every bottom destination, Home/category scroll, Search/filter/results, movie and series details, My List synchronization, Live TV category/playback, Library tabs/sort, player controls/skip/next, back behavior, and rotation/full-screen transitions. Record device model, resolution, Android version, and observed frame stability.

- [ ] **Step 5: Re-run final verification after cleanup**

Run: `flutter test && flutter analyze && flutter build apk --debug`  
Expected: PASS, zero analyzer errors, and a successful APK.

- [ ] **Step 6: Commit final integration and QA report**

```powershell
git add lib/main.dart lib/new_ui/hourtv_new_shell.dart lib/hybrid_mobile test/hybrid_mobile docs/superpowers/reports/2026-08-27-hourtv-hybrid-mobile-qa.md
git commit -m "feat: complete HourTV hybrid Android mobile migration"
```

## Execution Order and Checkpoints

Execute Tasks 1–5 first to establish the protected phone-only architecture. Then execute XuperTV-derived screens (Tasks 6–8), AI Studio-derived screens (Tasks 9–12), settings (Task 13), and final QA (Tasks 14–15). After every task, inspect the focused diff and run its tests before committing. Never stage the whole dirty worktree.
