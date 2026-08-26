# HourTV AI Studio Native Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Sustituir por completo la presentación Android móvil de HourTV por una reproducción nativa y fiel del prototipo actual de Google AI Studio, conservando el catálogo real, reproducción, IPTV, casting, perfiles, favoritos, historial, búsqueda y ajustes ya funcionales.

**Architecture:** La migración crea un módulo `lib/studio_ui/` que contiene tokens, modelos de presentación, adaptadores, componentes y pantallas. `ContentStore`, `StorageService`, `Channel`, `XtreamSeries` y los motores actuales de reproducción/casting continúan siendo la capa funcional. El nuevo shell se activa únicamente para teléfonos Android; las ramas TV, tablet y desktop del shell existente quedan intactas. No se usa WebView ni se copia el prototipo TypeScript dentro de la app.

**Tech Stack:** Flutter 3 / Dart 3.12, Material, `cached_network_image`, `video_player`, `chewie`, `flutter_chrome_cast`, `shared_preferences`, `flutter_test`, pruebas golden nativas.

**Spec:** `docs/superpowers/specs/2026-08-26-hourtv-ai-studio-native-migration-design.md`

## Global Constraints

- Google AI Studio es la única autoridad visual para Android móvil. Figma y la UI Flutter actual no pueden introducir cambios visuales.
- Conservar sin cambios funcionales `ContentStore`, `StorageService`, `XtreamService`, parsing M3U, favoritos, recientes, reproducción, casting y red.
- No reiniciar, descartar ni sobrescribir el worktree existente. Cada commit debe incluir solamente los archivos listados en su tarea.
- No activar la nueva UI en Android TV, Google TV, tablet o desktop.
- No usar WebView, HTML embebido, capturas como pantallas ni texto rasterizado.
- Todas las pantallas deben usar `SafeArea`, scroll acotado, imágenes con fallback, controles táctiles de al menos 48 px y semántica accesible.
- Verificar 360×800, 393×852, 412×915, 428×926 y 480×960 sin overflow ni contenido inaccesible.
- Las pruebas no deben depender de internet: inyectar `ImageProvider` o usar assets locales deterministas.
- Ejecutar `dart format`, `flutter analyze` y la prueba más estrecha después de cada tarea. Ejecutar la suite completa antes del corte final.

## Route and Behavior Contract

| AI Studio source | Flutter destination | Native behavior retained |
|---|---|---|
| `ProfileGate.tsx` | `StudioProfileGate` | perfiles persistidos, creación obligatoria inicial, PIN parental |
| `AccessView.tsx` | `StudioAccessScreen` | estados de carga, sin conexión, error y reintento |
| `HomeView.tsx` | `StudioHomeScreen` | catálogo, favoritos, apertura de detalle y reproducción |
| `OriginalsView.tsx` | `StudioOriginalsScreen` | filtrado de originales y orden real |
| `LiveTvView.tsx` | `StudioLiveTvScreen` | canales M3U/Xtream, categorías, favorito, fullscreen, canal siguiente/anterior |
| `SearchView.tsx` | `StudioSearchScreen` | búsqueda real, teclado, resultados progresivos e infinite scroll |
| `LibraryView.tsx` | `StudioLibraryScreen` | Mi lista, Continuar viendo, Historial y orden |
| `DetailsView.tsx` | `StudioDetailsScreen` | detalle película/serie, temporadas, Mi lista, reproducción y compartir |
| `PlayerView.tsx` | `StudioPlayerHud` sobre `HourTvPlayerScreen` | reproducción real, casting, intro/resumen, siguiente episodio, audio/subtítulos |
| `ProfileView.tsx` | `StudioProfileScreen` | perfil activo, ajustes, control parental, cerrar sesión |
| `SystemStatesView.tsx` | `StudioSystemState` | loading, empty, offline, error y retry |

---

### Task 1: Freeze the exact AI Studio reference and parity manifest

**Files:**
- Create: `references/ai-studio/README.md`
- Create: `tool/verify_ai_studio_reference.ps1`
- Track: `references/ai-studio/hourtv-android-streaming-2026-08-26.zip`
- Test: `test/reference/ai_studio_reference_test.dart`

**Interfaces:**
- Consumes: exported AI Studio ZIP and SHA-256 `ED0D1FC439FC1CADFC0162ECFCBA0F050E973A1736CCEE0D93019AFCC84A53C0`.
- Produces: immutable reference identity and a machine-checked list of required source screens.

- [ ] **Step 1: Write the failing reference contract test**

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the approved AI Studio export is preserved', () {
    final readme = File('references/ai-studio/README.md').readAsStringSync();
    expect(
      readme,
      contains('ED0D1FC439FC1CADFC0162ECFCBA0F050E973A1736CCEE0D93019AFCC84A53C0'),
    );
    for (final screen in <String>[
      'AccessView.tsx',
      'HomeView.tsx',
      'OriginalsView.tsx',
      'LiveTvView.tsx',
      'SearchView.tsx',
      'LibraryView.tsx',
      'DetailsView.tsx',
      'PlayerView.tsx',
      'ProfileView.tsx',
      'SystemStatesView.tsx',
      'ProfileGate.tsx',
    ]) {
      expect(readme, contains(screen));
    }
  });
}
```

- [ ] **Step 2: Run the test and confirm it fails because the manifest does not exist**

Run: `flutter test test/reference/ai_studio_reference_test.dart`

Expected: FAIL with `PathNotFoundException` for `references/ai-studio/README.md`.

- [ ] **Step 3: Write the reference manifest and verifier**

`README.md` must record the export date, source URL, SHA-256, viewport baseline, exact screen inventory, visual tokens and the rule that the archive is read-only. `verify_ai_studio_reference.ps1` must calculate the archive hash with `Get-FileHash`, compare it to the approved value and exit non-zero on mismatch.

```powershell
$archive = Join-Path $PSScriptRoot '..\references\ai-studio\hourtv-android-streaming-2026-08-26.zip'
$expected = 'ED0D1FC439FC1CADFC0162ECFCBA0F050E973A1736CCEE0D93019AFCC84A53C0'
$actual = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash
if ($actual -ne $expected) {
  throw "AI Studio reference hash mismatch. Expected $expected but found $actual."
}
Write-Output "AI Studio reference verified: $actual"
```

- [ ] **Step 4: Verify the archive and passing contract**

Run: `powershell -ExecutionPolicy Bypass -File tool/verify_ai_studio_reference.ps1`

Expected: `AI Studio reference verified: ED0D1FC439FC1CADFC0162ECFCBA0F050E973A1736CCEE0D93019AFCC84A53C0`

Run: `flutter test test/reference/ai_studio_reference_test.dart`

Expected: PASS.

- [ ] **Step 5: Commit only the frozen reference files**

```text
git add references/ai-studio/README.md references/ai-studio/hourtv-android-streaming-2026-08-26.zip tool/verify_ai_studio_reference.ps1 test/reference/ai_studio_reference_test.dart
git commit -m "test: freeze approved AI Studio reference"
```

---

### Task 2: Implement Studio tokens, theme and responsive geometry

**Files:**
- Create: `lib/studio_ui/foundation/studio_tokens.dart`
- Create: `lib/studio_ui/foundation/studio_theme.dart`
- Create: `lib/studio_ui/foundation/studio_breakpoints.dart`
- Test: `test/studio_ui/foundation/studio_tokens_test.dart`
- Test: `test/studio_ui/foundation/studio_breakpoints_test.dart`

**Interfaces:**
- Consumes: approved AI Studio colors, typography, spacing, radii and mobile viewport behavior.
- Produces: `StudioColors`, `StudioSpacing`, `StudioRadii`, `StudioTypography`, `StudioTheme`, `StudioLayoutMetrics`.

- [ ] **Step 1: Write failing token tests**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamtv/studio_ui/foundation/studio_breakpoints.dart';
import 'package:streamtv/studio_ui/foundation/studio_tokens.dart';

void main() {
  test('uses the exact AI Studio palette', () {
    expect(StudioColors.background, const Color(0xFF080A09));
    expect(StudioColors.surface, const Color(0xFF101412));
    expect(StudioColors.surfaceElevated, const Color(0xFF151917));
    expect(StudioColors.accent, const Color(0xFF00C781));
    expect(StudioColors.textPrimary, const Color(0xFFF5F5F5));
    expect(StudioColors.textSecondary, const Color(0xFFC4C8C6));
    expect(StudioColors.textMuted, const Color(0xFFA8ADAB));
    expect(StudioColors.border, const Color(0xFF27302C));
  });

  test('keeps cards inside every approved phone width', () {
    for (final width in <double>[360, 393, 412, 428, 480]) {
      final metrics = StudioLayoutMetrics.forWidth(width);
      final used = metrics.pagePadding * 2 +
          metrics.posterWidth * metrics.posterColumns +
          metrics.posterGap * (metrics.posterColumns - 1);
      expect(used, lessThanOrEqualTo(width));
      expect(metrics.touchTarget, greaterThanOrEqualTo(48));
    }
  });
}
```

- [ ] **Step 2: Run both tests and confirm missing symbols**

Run: `flutter test test/studio_ui/foundation`

Expected: FAIL because the `studio_ui/foundation` files do not exist.

- [ ] **Step 3: Implement immutable tokens and geometry**

```dart
abstract final class StudioColors {
  static const background = Color(0xFF080A09);
  static const surface = Color(0xFF101412);
  static const surfaceElevated = Color(0xFF151917);
  static const accent = Color(0xFF00C781);
  static const textPrimary = Color(0xFFF5F5F5);
  static const textSecondary = Color(0xFFC4C8C6);
  static const textMuted = Color(0xFFA8ADAB);
  static const border = Color(0xFF27302C);
}

@immutable
class StudioLayoutMetrics {
  const StudioLayoutMetrics({
    required this.pagePadding,
    required this.posterWidth,
    required this.posterGap,
    required this.posterColumns,
    this.touchTarget = 48,
  });

  final double pagePadding;
  final double posterWidth;
  final double posterGap;
  final int posterColumns;
  final double touchTarget;

  factory StudioLayoutMetrics.forWidth(double width) {
    final columns = width >= 428 ? 3 : 3;
    const padding = 16.0;
    const gap = 10.0;
    return StudioLayoutMetrics(
      pagePadding: padding,
      posterWidth: (width - padding * 2 - gap * (columns - 1)) / columns,
      posterGap: gap,
      posterColumns: columns,
    );
  }
}
```

Build `ThemeData` with Inter through the existing `google_fonts` dependency, transparent splash/highlight on touch UI, exact text roles from the reference, `scaffoldBackgroundColor` and system bar colors.

- [ ] **Step 4: Format, analyze and test**

Run: `dart format lib/studio_ui/foundation test/studio_ui/foundation`

Run: `flutter analyze lib/studio_ui/foundation test/studio_ui/foundation`

Run: `flutter test test/studio_ui/foundation`

Expected: PASS with zero analyzer findings.

- [ ] **Step 5: Commit the foundation only**

```text
git add lib/studio_ui/foundation test/studio_ui/foundation
git commit -m "feat: add AI Studio visual foundation"
```

---

### Task 3: Add presentation models, catalog adapters and profile persistence

**Files:**
- Create: `lib/studio_ui/data/studio_media_item.dart`
- Create: `lib/studio_ui/data/studio_catalog_adapter.dart`
- Create: `lib/studio_ui/data/studio_profile.dart`
- Create: `lib/studio_ui/data/studio_profile_repository.dart`
- Create: `test/studio_ui/support/studio_test_fixtures.dart`
- Test: `test/studio_ui/data/studio_catalog_adapter_test.dart`
- Test: `test/studio_ui/data/studio_profile_repository_test.dart`

**Interfaces:**
- Consumes: `Channel`, `XtreamSeries`, `ContentStore`, `StorageService.saveSetting/getSetting`.
- Produces: immutable Studio view models and persisted profile gate state without changing domain classes.

- [ ] **Step 1: Write failing adapter and persistence tests**

```dart
test('maps Channel without losing playback identity', () {
  final channel = Channel(
    name: 'El último amanecer',
    url: 'https://example.test/movie.m3u8',
    logo: 'https://example.test/poster.jpg',
    category: 'Películas',
    genre: 'Drama',
  );
  final item = StudioCatalogAdapter.fromChannel(channel);
  expect(item.id, channel.url);
  expect(item.title, channel.name);
  expect(item.posterUrl, channel.logo);
  expect(item.source, same(channel));
});

test('profile repository persists first-run completion and active profile', () async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  await StorageService.init();
  final repository = StudioProfileRepository();
  const profile = StudioProfile(id: 'renata', name: 'Renata', avatarKey: 'emerald');
  await repository.saveProfiles(<StudioProfile>[profile], activeId: profile.id);
  expect(repository.loadProfiles(), <StudioProfile>[profile]);
  expect(repository.loadActiveProfile(), profile);
  expect(repository.requiresProfileCreation, isFalse);
});
```

- [ ] **Step 2: Run tests and confirm the new contracts are absent**

Run: `flutter test test/studio_ui/data`

Expected: FAIL with missing imports and types.

- [ ] **Step 3: Implement lossless adapters and repository**

```dart
@immutable
class StudioMediaItem {
  const StudioMediaItem({
    required this.id,
    required this.title,
    required this.kind,
    required this.source,
    this.posterUrl,
    this.backdropUrl,
    this.genre,
    this.year,
    this.rating,
    this.duration,
    this.description,
  });

  final String id;
  final String title;
  final StudioMediaKind kind;
  final Object source;
  final String? posterUrl;
  final String? backdropUrl;
  final String? genre;
  final String? year;
  final String? rating;
  final String? duration;
  final String? description;
}
```

The adapter must retain the original `Channel` or `XtreamSeries` in `source` so actions delegate to current services. The repository must serialize profiles under `studio_profiles_v1`, active ID under `studio_active_profile_v1`, and parental settings through the existing settings map.

`studio_test_fixtures.dart` must provide deterministic `StudioFixtures`, `FakeStudioCatalog`, `FakeStudioProfileRepository`, `FakeStudioLiveTvController`, `FakeStudioPlayerController` and `StudioTestApp`. It must use local image providers and never contact the network.

- [ ] **Step 4: Test adapters against movies, series, favorites and recent content**

Run: `dart format lib/studio_ui/data test/studio_ui/data`

Run: `flutter analyze lib/studio_ui/data test/studio_ui/data`

Run: `flutter test test/studio_ui/data`

Expected: PASS.

- [ ] **Step 5: Commit only the data bridge**

```text
git add lib/studio_ui/data test/studio_ui/data test/studio_ui/support/studio_test_fixtures.dart
git commit -m "feat: bridge existing content into Studio UI"
```

---

### Task 4: Build the shared AI Studio component kit

**Files:**
- Create: `lib/studio_ui/components/studio_logo.dart`
- Create: `lib/studio_ui/components/studio_header.dart`
- Create: `lib/studio_ui/components/studio_button.dart`
- Create: `lib/studio_ui/components/studio_media_card.dart`
- Create: `lib/studio_ui/components/studio_bottom_nav.dart`
- Create: `lib/studio_ui/components/studio_modal_sheet.dart`
- Create: `lib/studio_ui/components/studio_snackbar.dart`
- Create: `lib/studio_ui/components/studio_network_image.dart`
- Create: `test/studio_ui/components/studio_component_harness.dart`
- Test: `test/studio_ui/components/studio_components_test.dart`
- Test: `test/studio_ui/goldens/components_393.png`

**Interfaces:**
- Consumes: Studio foundation and `StudioMediaItem`.
- Produces: reusable, stateful native components matching `HourTVLogo`, `Header`, `Buttons`, `Cards`, `BottomNav`, `ModalSheet` and `Snackbar` from the export.

- [ ] **Step 1: Write failing interaction and layout tests**

```dart
testWidgets('bottom navigation exposes one selected destination without focus chrome', (tester) async {
  await tester.pumpWidget(const StudioComponentHarness(width: 393));
  expect(find.byType(StudioBottomNav), findsOneWidget);
  expect(find.byKey(const ValueKey('bottom-nav-selected-Inicio')), findsOneWidget);
  expect(find.byKey(const ValueKey('bottom-nav-focus-outline')), findsNothing);
  expect(tester.getSize(find.byKey(const ValueKey('bottom-nav-Inicio'))).height, greaterThanOrEqualTo(48));
});

testWidgets('media cards use a stable crop and never overflow at 360 px', (tester) async {
  await tester.binding.setSurfaceSize(const Size(360, 800));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(const StudioComponentHarness(width: 360));
  expect(tester.takeException(), isNull);
  expect(find.byType(StudioMediaCard), findsWidgets);
});
```

- [ ] **Step 2: Run the test and confirm missing components**

Run: `flutter test test/studio_ui/components/studio_components_test.dart`

Expected: FAIL with missing component classes.

- [ ] **Step 3: Implement components with explicit state contracts**

`StudioButton` must support primary, secondary and icon variants; loading and disabled states; 48 px minimum target; centered icon/label; no default Material focus ring on touch. `StudioMediaCard` must support poster and landscape aspect ratios, selected-in-list state, progress, badge and deterministic fallback. `StudioBottomNav` must render exactly Inicio, TV, Buscar, Mi Biblioteca and Perfil, with only the active destination colored emerald.

```dart
enum StudioButtonVariant { primary, secondary, icon }

class StudioButton extends StatelessWidget {
  const StudioButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = StudioButtonVariant.primary,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final StudioButtonVariant variant;
  final bool isLoading;
}
```

- [ ] **Step 4: Generate and review the component golden**

Run: `flutter test --update-goldens test/studio_ui/components/studio_components_test.dart`

Inspect `test/studio_ui/goldens/components_393.png` against the approved export before accepting it.

Run: `flutter test test/studio_ui/components/studio_components_test.dart`

Expected: PASS and zero overflow diagnostics.

- [ ] **Step 5: Commit the component kit**

```text
git add lib/studio_ui/components test/studio_ui/components test/studio_ui/goldens/components_393.png
git commit -m "feat: add AI Studio mobile component kit"
```

---

### Task 5: Implement the phone shell, startup states and mandatory profile gate

**Files:**
- Create: `lib/studio_ui/studio_app_shell.dart`
- Create: `lib/studio_ui/navigation/studio_destination.dart`
- Create: `lib/studio_ui/screens/studio_profile_gate.dart`
- Create: `lib/studio_ui/screens/studio_access_screen.dart`
- Modify: `lib/new_ui/hourtv_new_shell.dart`
- Test: `test/studio_ui/studio_app_shell_test.dart`
- Test: `test/studio_ui/screens/studio_profile_gate_test.dart`
- Test: `test/studio_ui/regression/non_phone_shell_test.dart`

**Interfaces:**
- Consumes: `StudioProfileRepository`, `ContentStore.ensureLoaded`, current responsive phone detection.
- Produces: first-run create-profile flow, returning profile selection flow, startup/loading/error states and five-destination phone navigation.

- [ ] **Step 1: Write failing navigation and profile-gate tests**

```dart
testWidgets('first launch requires creating a profile before Home', (tester) async {
  final repository = FakeStudioProfileRepository(profiles: const <StudioProfile>[]);
  await tester.pumpWidget(StudioAppShell(
    profileRepository: repository,
    destinationBuilder: (context, destination) => Text(destination.name),
  ));
  expect(find.byType(StudioProfileGate), findsOneWidget);
  expect(find.text('home'), findsNothing);
});

testWidgets('existing profiles open the chooser and then Home', (tester) async {
  final repository = FakeStudioProfileRepository(
    profiles: const <StudioProfile>[
      StudioProfile(id: 'renata', name: 'Renata', avatarKey: 'emerald'),
    ],
  );
  await tester.pumpWidget(StudioAppShell(
    profileRepository: repository,
    destinationBuilder: (context, destination) => Text(destination.name),
  ));
  await tester.tap(find.text('Renata'));
  await tester.pumpAndSettle();
  expect(find.text('home'), findsOneWidget);
});
```

- [ ] **Step 2: Run tests and confirm the shell does not exist**

Run: `flutter test test/studio_ui/studio_app_shell_test.dart test/studio_ui/screens/studio_profile_gate_test.dart`

Expected: FAIL.

- [ ] **Step 3: Implement shell and gate exactly from the export**

The gate must support create, choose, edit, delete with confirmation, avatar selection and parental lock. The shell must keep the header only where the export shows it, prevent the bottom navigation from drawing outside the device safe area and reset transient filter/focus state on destination changes.

```dart
enum StudioDestination { home, liveTv, search, library, profile }

class StudioAppShell extends StatefulWidget {
  const StudioAppShell({
    super.key,
    required this.profileRepository,
    required this.destinationBuilder,
  });
  final StudioProfileRepository profileRepository;
  final StudioDestinationBuilder destinationBuilder;
}
```

In `HourTvNewShell`, replace only the phone branch with `StudioAppShell`; retain the existing tablet/TV/desktop branch byte-for-byte except for the import needed by the phone branch.

- [ ] **Step 4: Verify first-run, return-user and non-phone preservation**

Run: `dart format lib/studio_ui lib/new_ui/hourtv_new_shell.dart test/studio_ui`

Run: `flutter analyze lib/studio_ui lib/new_ui/hourtv_new_shell.dart test/studio_ui`

Run: `flutter test test/studio_ui/studio_app_shell_test.dart test/studio_ui/screens/studio_profile_gate_test.dart`

Run: `flutter test test/studio_ui/regression/non_phone_shell_test.dart`

Expected: all PASS; the TV regression test remains unchanged.

- [ ] **Step 5: Commit the shell cut-in**

```text
git add lib/studio_ui/studio_app_shell.dart lib/studio_ui/navigation lib/studio_ui/screens/studio_profile_gate.dart lib/studio_ui/screens/studio_access_screen.dart lib/new_ui/hourtv_new_shell.dart test/studio_ui/studio_app_shell_test.dart test/studio_ui/screens/studio_profile_gate_test.dart test/studio_ui/regression/non_phone_shell_test.dart
git commit -m "feat: add Studio mobile shell and profile gate"
```

---

### Task 6: Port Home and Originals with real catalog actions

**Files:**
- Create: `lib/studio_ui/screens/studio_home_screen.dart`
- Create: `lib/studio_ui/screens/studio_originals_screen.dart`
- Create: `lib/studio_ui/sections/studio_hero.dart`
- Create: `lib/studio_ui/sections/studio_media_row.dart`
- Test: `test/studio_ui/screens/studio_home_screen_test.dart`
- Test: `test/studio_ui/screens/studio_originals_screen_test.dart`
- Test: `test/studio_ui/goldens/home_393.png`
- Test: `test/studio_ui/goldens/originals_393.png`

**Interfaces:**
- Consumes: `ContentStore.all/movies/series/favorites`, catalog adapter, shell navigation callbacks.
- Produces: exact Home/Originals composition with working details, play and Mi lista actions.

- [ ] **Step 1: Write failing screen behavior tests**

```dart
testWidgets('Home opens details and toggles Mi lista through the real adapter', (tester) async {
  final catalog = FakeStudioCatalog.fixture();
  StudioMediaItem? openedItem;
  await tester.pumpWidget(StudioTestApp(
    child: StudioHomeScreen(
      catalog: catalog,
      onOpenDetails: (item) => openedItem = item,
    ),
  ));
  await tester.tap(find.text('El último amanecer').first);
  expect(openedItem?.title, 'El último amanecer');
  await tester.tap(find.text('Mi Lista').first);
  expect(catalog.favoriteToggleCount, 1);
});

testWidgets('Home reaches its last row without excess bottom space', (tester) async {
  await tester.pumpWidget(StudioTestApp(child: StudioHomeScreen(catalog: FakeStudioCatalog.fixture())));
  await tester.fling(find.byType(CustomScrollView), const Offset(0, -1800), 4000);
  await tester.pumpAndSettle();
  final bottomNavTop = tester.getTopLeft(find.byType(StudioBottomNav)).dy;
  final lastCardBottom = tester.getBottomLeft(find.byKey(const ValueKey('home-last-card'))).dy;
  expect(bottomNavTop - lastCardBottom, lessThanOrEqualTo(32));
});
```

- [ ] **Step 2: Run tests and confirm missing screens**

Run: `flutter test test/studio_ui/screens/studio_home_screen_test.dart test/studio_ui/screens/studio_originals_screen_test.dart`

Expected: FAIL.

- [ ] **Step 3: Implement exact hierarchy and callbacks**

Match the export's header visibility, category order, hero copy, badges, button labels, card ratios and section spacing. Do not show live-TV promotional content on Home. `Mi Lista` must be fully visible and delegate to `ContentStore.toggleFavorite`. Lists use lazy `SliverList`/horizontal `ListView.builder`, not eagerly built columns.

- [ ] **Step 4: Verify responsive layouts and goldens**

Run: `flutter test --update-goldens test/studio_ui/screens/studio_home_screen_test.dart test/studio_ui/screens/studio_originals_screen_test.dart`

Inspect both 393 px goldens and run the same harness at every approved width.

Run: `flutter test test/studio_ui/screens/studio_home_screen_test.dart test/studio_ui/screens/studio_originals_screen_test.dart`

Expected: PASS with no overflow and working actions.

- [ ] **Step 5: Commit Home and Originals**

```text
git add lib/studio_ui/screens/studio_home_screen.dart lib/studio_ui/screens/studio_originals_screen.dart lib/studio_ui/sections test/studio_ui/screens/studio_home_screen_test.dart test/studio_ui/screens/studio_originals_screen_test.dart test/studio_ui/goldens/home_393.png test/studio_ui/goldens/originals_393.png
git commit -m "feat: port Studio Home and Originals"
```

---

### Task 7: Port Search and My Library with real filtering, order and infinite loading

**Files:**
- Create: `lib/studio_ui/screens/studio_search_screen.dart`
- Create: `lib/studio_ui/screens/studio_library_screen.dart`
- Create: `lib/studio_ui/components/studio_sort_menu.dart`
- Create: `lib/studio_ui/controllers/studio_search_controller.dart`
- Test: `test/studio_ui/controllers/studio_search_controller_test.dart`
- Test: `test/studio_ui/screens/studio_search_screen_test.dart`
- Test: `test/studio_ui/screens/studio_library_screen_test.dart`
- Test: `test/studio_ui/goldens/search_393.png`
- Test: `test/studio_ui/goldens/library_393.png`

**Interfaces:**
- Consumes: all adapted catalog items, favorites, recent items, query input and current sort semantics.
- Produces: AI Studio search keyboard/results, progressive page loading and exact library tabs/order menu.

- [ ] **Step 1: Write failing search and library tests**

```dart
test('search filters normalized title and grows pages deterministically', () {
  final controller = StudioSearchController(items: StudioFixtures.twentyItems());
  controller.query = 'alma de cristal';
  expect(controller.visibleItems.map((item) => item.title), <String>['Alma de cristal']);
  controller.query = '';
  expect(controller.visibleItems.length, controller.pageSize);
  controller.loadNextPage();
  expect(controller.visibleItems.length, greaterThan(controller.pageSize));
});

testWidgets('library sticky controls never overlap while scrolling', (tester) async {
  await tester.pumpWidget(StudioTestApp(child: StudioLibraryScreen(catalog: FakeStudioCatalog.fixture())));
  await tester.fling(find.byType(CustomScrollView), const Offset(0, -1200), 3200);
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
  expect(find.text('Mi Biblioteca'), findsOneWidget);
  expect(find.byType(StudioSortMenu), findsOneWidget);
});
```

- [ ] **Step 2: Run tests and confirm missing behavior**

Run: `flutter test test/studio_ui/controllers/studio_search_controller_test.dart test/studio_ui/screens/studio_search_screen_test.dart test/studio_ui/screens/studio_library_screen_test.dart`

Expected: FAIL.

- [ ] **Step 3: Implement search, lazy pagination and library**

The keyboard must have one transient focus state, `Borrar` clears the full query, the delete icon removes one character, and there is no redundant Volver button. Result counts derive from the filtered list. The sort menu is a custom in-app overlay using the Studio component kit, never a native blue dropdown. Library top controls use matching capsule geometry and cannot detach from their background during scroll.

- [ ] **Step 4: Verify interactions, scroll endings and goldens**

Run: `flutter test --update-goldens test/studio_ui/screens/studio_search_screen_test.dart test/studio_ui/screens/studio_library_screen_test.dart`

Run: `flutter test test/studio_ui/controllers/studio_search_controller_test.dart test/studio_ui/screens/studio_search_screen_test.dart test/studio_ui/screens/studio_library_screen_test.dart`

Expected: PASS at all approved widths; final content-to-navigation gap no larger than 32 px.

- [ ] **Step 5: Commit Search and Library**

```text
git add lib/studio_ui/screens/studio_search_screen.dart lib/studio_ui/screens/studio_library_screen.dart lib/studio_ui/components/studio_sort_menu.dart lib/studio_ui/controllers/studio_search_controller.dart test/studio_ui/controllers test/studio_ui/screens/studio_search_screen_test.dart test/studio_ui/screens/studio_library_screen_test.dart test/studio_ui/goldens/search_393.png test/studio_ui/goldens/library_393.png
git commit -m "feat: port Studio Search and Library"
```

---

### Task 8: Port movie and series details while retaining playback and favorite actions

**Files:**
- Create: `lib/studio_ui/screens/studio_details_screen.dart`
- Create: `lib/studio_ui/sections/studio_details_hero.dart`
- Create: `lib/studio_ui/sections/studio_episode_list.dart`
- Create: `lib/studio_ui/components/studio_season_menu.dart`
- Test: `test/studio_ui/screens/studio_details_screen_test.dart`
- Test: `test/studio_ui/goldens/details_movie_393.png`
- Test: `test/studio_ui/goldens/details_series_393.png`

**Interfaces:**
- Consumes: `StudioMediaItem.source`, existing player route, favorite toggle, series episode metadata.
- Produces: exact movie/series details, in-frame season selector and linked actions.

- [ ] **Step 1: Write failing movie and series tests**

```dart
testWidgets('movie details show complete metadata and no removed editorial sections', (tester) async {
  await tester.pumpWidget(StudioTestApp(child: StudioDetailsScreen(item: StudioFixtures.movie)));
  expect(find.text('Director'), findsOneWidget);
  expect(find.text('Guionista'), findsOneWidget);
  expect(find.text('Rating IMDb'), findsOneWidget);
  expect(find.text('Crítica editorial'), findsNothing);
  expect(find.text('Detalles técnicos'), findsNothing);
  expect(find.text('¿Por qué verla?'), findsNothing);
});

testWidgets('season menu stays inside the phone and labels one line', (tester) async {
  await tester.binding.setSurfaceSize(const Size(360, 800));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(StudioTestApp(child: StudioDetailsScreen(item: StudioFixtures.series)));
  await tester.tap(find.text('Temporada 1'));
  await tester.pumpAndSettle();
  expect(find.text('Temporada 1'), findsWidgets);
  expect(find.textContaining('(5 ep)'), findsNothing);
  expect(tester.takeException(), isNull);
});
```

- [ ] **Step 2: Run tests and confirm screen is absent**

Run: `flutter test test/studio_ui/screens/studio_details_screen_test.dart`

Expected: FAIL.

- [ ] **Step 3: Implement exact details variants**

Hide global category navigation and cast icon on Details. Keep the AI Studio artwork and action arrangement. Use `Mi Lista`, not `En Mi Lista`. The recommendation grid must have consistent card gaps and no trailing empty scroll area. The season menu is positioned by `CompositedTransformTarget/Follower`, constrained to the viewport, and dismissed on outside tap.

- [ ] **Step 4: Verify actions and both goldens**

Run: `flutter test --update-goldens test/studio_ui/screens/studio_details_screen_test.dart`

Run: `flutter test test/studio_ui/screens/studio_details_screen_test.dart`

Expected: PASS; play route receives the original `Channel` or episode; favorite changes persist.

- [ ] **Step 5: Commit Details**

```text
git add lib/studio_ui/screens/studio_details_screen.dart lib/studio_ui/sections/studio_details_hero.dart lib/studio_ui/sections/studio_episode_list.dart lib/studio_ui/components/studio_season_menu.dart test/studio_ui/screens/studio_details_screen_test.dart test/studio_ui/goldens/details_movie_393.png test/studio_ui/goldens/details_series_393.png
git commit -m "feat: port Studio movie and series details"
```

---

### Task 9: Port Live TV while keeping the production channel engine

**Files:**
- Create: `lib/studio_ui/screens/studio_live_tv_screen.dart`
- Create: `lib/studio_ui/components/studio_channel_row.dart`
- Create: `lib/studio_ui/controllers/studio_live_tv_controller.dart`
- Modify: `lib/new_ui/hourtv_live_page.dart`
- Test: `test/studio_ui/controllers/studio_live_tv_controller_test.dart`
- Test: `test/studio_ui/screens/studio_live_tv_screen_test.dart`
- Test: `test/new_ui/hourtv_live_page_regression_test.dart`
- Test: `test/studio_ui/goldens/live_tv_393.png`

**Interfaces:**
- Consumes: current live channel list, category/group metadata, favorites, current/next program and live playback callbacks.
- Produces: single-column AI Studio channel experience with Todos, Favoritos, Deportes, Cine o Series, Novelas, Populares, Noticias, Infantil, Religioso and parental-gated +18.

- [ ] **Step 1: Write failing category and fullscreen behavior tests**

```dart
test('adult category is hidden until parental access is enabled', () {
  final controller = StudioLiveTvController(
    channels: StudioFixtures.liveChannels,
    adultAccessEnabled: false,
  );
  expect(controller.categories, isNot(contains('+18')));
  controller.adultAccessEnabled = true;
  expect(controller.categories, contains('+18'));
});

testWidgets('fullscreen channel controls expose previous and next channel actions', (tester) async {
  final controller = FakeStudioLiveTvController();
  await tester.pumpWidget(StudioTestApp(child: StudioLiveTvScreen(controller: controller)));
  await tester.tap(find.byKey(const ValueKey('live-fullscreen')));
  await tester.tap(find.byKey(const ValueKey('live-next-channel')));
  await tester.tap(find.byKey(const ValueKey('live-previous-channel')));
  expect(controller.nextCount, 1);
  expect(controller.previousCount, 1);
});
```

- [ ] **Step 2: Run tests and confirm missing controller/screen**

Run: `flutter test test/studio_ui/controllers/studio_live_tv_controller_test.dart test/studio_ui/screens/studio_live_tv_screen_test.dart`

Expected: FAIL.

- [ ] **Step 3: Implement Studio presentation around existing live playback**

Keep the current live player lifecycle and stream URL logic in `HourTvLivePage`; expose it through callbacks/controller rather than duplicating playback. The category selector is a single horizontal row as in the current approved prototype. Channel cards omit the removed expanded description panel. Fullscreen must respond to keyboard/remote up/down as previous/next channel and expose equivalent touch targets.

- [ ] **Step 4: Verify filtering, favorites, fullscreen and golden**

Run: `flutter test --update-goldens test/studio_ui/screens/studio_live_tv_screen_test.dart`

Run: `flutter test test/studio_ui/controllers/studio_live_tv_controller_test.dart test/studio_ui/screens/studio_live_tv_screen_test.dart`

Run: `flutter test test/new_ui/hourtv_live_page_regression_test.dart`

Expected: PASS; no player recreation when only a category changes.

- [ ] **Step 5: Commit Live TV**

```text
git add lib/studio_ui/screens/studio_live_tv_screen.dart lib/studio_ui/components/studio_channel_row.dart lib/studio_ui/controllers/studio_live_tv_controller.dart lib/new_ui/hourtv_live_page.dart test/studio_ui/controllers/studio_live_tv_controller_test.dart test/studio_ui/screens/studio_live_tv_screen_test.dart test/new_ui/hourtv_live_page_regression_test.dart test/studio_ui/goldens/live_tv_393.png
git commit -m "feat: port Studio Live TV experience"
```

---

### Task 10: Replace only the player HUD and preserve the playback engine

**Files:**
- Create: `lib/studio_ui/player/studio_player_hud.dart`
- Create: `lib/studio_ui/player/studio_player_action.dart`
- Create: `lib/studio_ui/player/studio_audio_subtitles_sheet.dart`
- Create: `lib/studio_ui/player/studio_next_content.dart`
- Modify: `lib/new_ui/hourtv_player_screen.dart`
- Test: `test/studio_ui/player/studio_player_hud_test.dart`
- Test: `test/new_ui/hourtv_player_screen_regression_test.dart`
- Test: `test/studio_ui/goldens/player_controls_915x412.png`

**Interfaces:**
- Consumes: current video controller state, seek/play/pause, duration, tracks, fullscreen, casting, intro/recap markers and next episode callback.
- Produces: AI Studio HUD states without replacing video playback internals.

- [ ] **Step 1: Write failing player-state tests**

```dart
testWidgets('HUD supports visible, hidden, paused, tracks, skip and next states', (tester) async {
  final controller = FakeStudioPlayerController();
  await tester.pumpWidget(StudioPlayerHarness(controller: controller));
  expect(find.byKey(const ValueKey('player-controls-visible')), findsOneWidget);
  controller.setControlsVisible(false);
  await tester.pump();
  expect(find.byKey(const ValueKey('player-controls-visible')), findsNothing);
  controller.showSkipAction(StudioSkipKind.intro);
  await tester.pump();
  expect(find.text('Omitir intro'), findsOneWidget);
  expect(tester.getSize(find.text('Omitir intro').hitTestable()).height, greaterThanOrEqualTo(48));
});
```

- [ ] **Step 2: Run the test and confirm HUD types are absent**

Run: `flutter test test/studio_ui/player/studio_player_hud_test.dart`

Expected: FAIL.

- [ ] **Step 3: Implement HUD and adapt existing player callbacks**

Retain current initialization, buffering, controller disposal, casting session, stream headers and error recovery. Replace only the visible control tree. Implement Controls Visible, Controls Hidden, Paused, Audio & Subtitles, Skip Intro, Skip Recap and Next Content. Casting appears only inside playback. Skip actions remain above timeline/safe area and never overlap subtitles or next-content. The timeline uses the existing playback position stream and throttles visual updates without seeking on every rebuild.

- [ ] **Step 4: Verify state transitions and landscape golden**

Run: `flutter test --update-goldens test/studio_ui/player/studio_player_hud_test.dart`

Run: `flutter test test/studio_ui/player/studio_player_hud_test.dart`

Run: `flutter test test/new_ui/hourtv_player_screen_regression_test.dart`

Expected: PASS, zero leaked timers/controllers, minimum 48 px controls and no landscape overflow.

- [ ] **Step 5: Commit the player HUD**

```text
git add lib/studio_ui/player lib/new_ui/hourtv_player_screen.dart test/studio_ui/player test/new_ui/hourtv_player_screen_regression_test.dart test/studio_ui/goldens/player_controls_915x412.png
git commit -m "feat: port Studio player HUD"
```

---

### Task 11: Port Profile, settings and complete system states

**Files:**
- Create: `lib/studio_ui/screens/studio_profile_screen.dart`
- Create: `lib/studio_ui/screens/studio_settings_screen.dart`
- Create: `lib/studio_ui/components/studio_settings_tile.dart`
- Create: `lib/studio_ui/components/studio_system_state.dart`
- Modify: `lib/new_ui/hourtv_profile_page.dart`
- Test: `test/studio_ui/screens/studio_profile_screen_test.dart`
- Test: `test/studio_ui/components/studio_system_state_test.dart`
- Test: `test/studio_ui/goldens/profile_393.png`

**Interfaces:**
- Consumes: active profile repository and existing settings/parental actions.
- Produces: exact AI Studio Profile/Settings visual hierarchy plus loading, empty, offline, error, retry and snackbar states.

- [ ] **Step 1: Write failing profile and system-state tests**

```dart
testWidgets('profile settings use real icons and preserve all current actions', (tester) async {
  await tester.pumpWidget(StudioTestApp(child: StudioProfileScreen(repository: FakeStudioProfileRepository.seeded())));
  expect(find.text('Reproducción y calidad'), findsOneWidget);
  expect(find.text('Idioma y subtítulos'), findsOneWidget);
  expect(find.text('Notificaciones'), findsOneWidget);
  expect(find.text('Control parental'), findsOneWidget);
  expect(find.text('4K'), findsNothing);
  expect(find.text('CC'), findsNothing);
});

testWidgets('retry state invokes one retry without stacking overlays', (tester) async {
  var retryCount = 0;
  await tester.pumpWidget(StudioTestApp(child: StudioSystemState.error(onRetry: () => retryCount++)));
  await tester.tap(find.text('Reintentar'));
  await tester.pump();
  expect(retryCount, 1);
  expect(find.byType(StudioModalSheet), findsNothing);
});
```

- [ ] **Step 2: Run tests and confirm screens/states are absent**

Run: `flutter test test/studio_ui/screens/studio_profile_screen_test.dart test/studio_ui/components/studio_system_state_test.dart`

Expected: FAIL.

- [ ] **Step 3: Implement profile/settings and state components**

Use proper line icons for quality, subtitles, notifications and parental control. Delegate each tile to the existing setting route/action. Switching profile returns to `StudioProfileGate`. Loading uses a compositor-friendly animation with one `AnimationController`, not repeated timers or image filters. System states use Studio tokens and preserve content retry callbacks.

- [ ] **Step 4: Verify profile flows, state cleanup and golden**

Run: `flutter test --update-goldens test/studio_ui/screens/studio_profile_screen_test.dart`

Run: `flutter test test/studio_ui/screens/studio_profile_screen_test.dart test/studio_ui/components/studio_system_state_test.dart`

Expected: PASS with no pending timers after disposal.

- [ ] **Step 5: Commit Profile and states**

```text
git add lib/studio_ui/screens/studio_profile_screen.dart lib/studio_ui/screens/studio_settings_screen.dart lib/studio_ui/components/studio_settings_tile.dart lib/studio_ui/components/studio_system_state.dart lib/new_ui/hourtv_profile_page.dart test/studio_ui/screens/studio_profile_screen_test.dart test/studio_ui/components/studio_system_state_test.dart test/studio_ui/goldens/profile_393.png
git commit -m "feat: port Studio profile and system states"
```

---

### Task 12: Complete the phone cutover, remove obsolete active UI and run acceptance QA

**Files:**
- Modify: `lib/main.dart`
- Modify: `lib/new_ui/hourtv_new_shell.dart`
- Modify: `test/hourtv_mobile_ui_test.dart`
- Create: `test/studio_ui/studio_responsive_matrix_test.dart`
- Create: `test/studio_ui/studio_navigation_smoke_test.dart`
- Create: `tool/run_studio_acceptance.ps1`
- Delete only after proving zero references: obsolete active phone-only files under `lib/mobile_ui/` that are superseded by `lib/studio_ui/`
- Preserve: all TV/tablet/desktop presentation files and all domain/service files

**Interfaces:**
- Consumes: every completed Studio screen and current platform detection.
- Produces: production Android phone app using the exact Studio presentation from launch to playback, with retained non-phone experiences.

- [ ] **Step 1: Write failing full-flow and responsive matrix tests**

```dart
testWidgets('all primary Android destinations are reachable without render errors', (tester) async {
  await tester.pumpWidget(StudioTestApp(child: StudioAppShell(profileRepository: FakeStudioProfileRepository.seeded())));
  for (final label in <String>['Inicio', 'TV', 'Buscar', 'Mi Biblioteca', 'Perfil']) {
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'render error in $label');
  }
});

testWidgets('all approved phone sizes render without overflow', (tester) async {
  for (final size in <Size>[
    Size(360, 800),
    Size(393, 852),
    Size(412, 915),
    Size(428, 926),
    Size(480, 960),
  ]) {
    await tester.binding.setSurfaceSize(size);
    await tester.pumpWidget(StudioTestApp(child: StudioResponsiveGallery.fixture()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'overflow at ${size.width}x${size.height}');
  }
  await tester.binding.setSurfaceSize(null);
});
```

- [ ] **Step 2: Run the acceptance tests before cutover and confirm they fail**

Run: `flutter test test/studio_ui/studio_responsive_matrix_test.dart test/studio_ui/studio_navigation_smoke_test.dart`

Expected: FAIL until every route is wired into the production shell.

- [ ] **Step 3: Wire the final production phone route and prove obsolete files are unused**

`main.dart` continues initializing current services, then launches `HourTvNewShell`. The phone branch must resolve exclusively to `StudioAppShell`. Use code graph inbound-reference checks before deleting any superseded phone-only file. Do not delete files used by TV/tablet/desktop or current player/service layers.

The acceptance script must perform these commands in order and stop on first failure:

```powershell
$ErrorActionPreference = 'Stop'
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build apk --debug
```

- [ ] **Step 4: Run static, unit, widget and build verification**

Run: `powershell -ExecutionPolicy Bypass -File tool/run_studio_acceptance.ps1`

Expected: formatting clean, analyzer zero findings, all tests pass, debug APK created.

- [ ] **Step 5: Install on the approved Infinix and perform device QA**

Connect using the active wireless-debugging endpoint shown by the device, then:

```text
.tools\android\platform-tools\adb.exe devices
.tools\android\platform-tools\adb.exe install -r build\app\outputs\flutter-apk\app-debug.apk
.tools\android\platform-tools\adb.exe shell am force-stop com.example.mi_app
.tools\android\platform-tools\adb.exe shell monkey -p com.example.mi_app -c android.intent.category.LAUNCHER 1
```

Manually verify: first-run profile creation, returning profile chooser, Home, Originals, Details movie, Details series, Search, infinite results, Library, Live TV, fullscreen channel switching, player controls, Skip Intro/Recap, Next Content, casting, Profile, parental PIN, offline/retry and back navigation.

Capture screenshots at launch, Home, Search, Details, Live TV, Player and Profile into `artifacts/studio-acceptance/`. Compare each against the AI Studio export at the equivalent state.

- [ ] **Step 6: Inspect runtime health**

```text
.tools\android\platform-tools\adb.exe logcat -c
.tools\android\platform-tools\adb.exe logcat -d Flutter:D AndroidRuntime:E ActivityManager:E *:S
```

Expected: no fatal exception, ANR, repeated frame-time warning, render overflow or player-controller disposal error.

- [ ] **Step 7: Run final scope and placeholder audit**

Verify the changed-file list contains no unrelated TV/tablet/desktop redesign. Search the new module for unfinished-work markers, omitted-code markers, fake URLs and disabled callbacks. Every intentional empty state must use `StudioSystemState`, not temporary content.

Run: `git diff --check`

Expected: no whitespace errors.

- [ ] **Step 8: Commit the production cutover and acceptance assets**

```text
git add lib/main.dart lib/new_ui/hourtv_new_shell.dart lib/studio_ui test/hourtv_mobile_ui_test.dart test/studio_ui tool/run_studio_acceptance.ps1 artifacts/studio-acceptance
git add -u lib/mobile_ui
git commit -m "feat: replace Android phone UI with AI Studio design"
```

---

## Final Acceptance Checklist

- [ ] Exact visual source is the 2026-08-26 AI Studio export and its hash verifies.
- [ ] Android phone presentation contains no screen from the former Flutter/Figma visual system.
- [ ] Profile creation is mandatory on first run; returning users see profile selection.
- [ ] Home, Originals, Live TV, Search, Library, Details, Player, Profile and system states match the export.
- [ ] Search filters real content, reports the real count and progressively loads the full catalog.
- [ ] Favorites, history, recent playback, profiles and parental settings persist after app restart.
- [ ] Movie, series, episode and live channel playback use existing production services.
- [ ] Casting appears only where specified and still controls real playback.
- [ ] Skip Intro, Skip Recap and Next Content work through real playback callbacks.
- [ ] No touch focus boxes, stale selected states, native blue dropdowns, overflow stripes or excess terminal scroll gaps remain.
- [ ] All touch targets are at least 48 px and all interactive controls have semantics.
- [ ] 360×800, 393×852, 412×915, 428×926 and 480×960 pass without overflow.
- [ ] TV, tablet and desktop layouts and behavior remain unchanged.
- [ ] `flutter analyze`, all tests and debug APK build pass.
- [ ] Physical Infinix install passes the full navigation and playback smoke test.

## Plan Self-Review

- [ ] Every screen in the approved export maps to one Flutter destination.
- [ ] Every retained native capability has an explicit integration task.
- [ ] Every production task begins with a failing test and ends with a narrow commit.
- [ ] No task requires WebView, duplicated playback or replacement of current services.
- [ ] Deletion occurs only after inbound-reference proof and full regression tests.
- [ ] No step contains unfinished-work markers, omitted code or unspecified implementation work.
