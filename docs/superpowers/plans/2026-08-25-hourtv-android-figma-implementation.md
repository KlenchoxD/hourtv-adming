# HourTV Android Figma Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the production phone UI with the approved HourTV Android Figma design without changing the AI Studio prototype or non-phone experiences.

**Architecture:** Add an isolated Flutter mobile UI layer selected only for phones. Reuse `ContentStore`, `StorageService`, existing detail/player/live/settings routes, and centralize Figma tokens and reusable widgets so every mobile screen stays visually consistent.

**Tech Stack:** Flutter, Dart, Material, CachedNetworkImage, Google Fonts, flutter_test.

**Spec:** `docs/superpowers/specs/2026-08-25-hourtv-android-figma-implementation-design.md`

## Global Constraints

- Figma file `IaWx1xwIbGXjxE979aRmC0`, approved Android frames, is the visual source of truth.
- Keep `ai-studio-app/` untouched.
- Preserve tablet, desktop, Android TV, and TV Box layouts.
- Preserve catalog, playback, favorites, profiles, and persistence behavior.
- Use Inter, `#050505`, `#151917`, `#27302C`, `#00C781`, `#F5F5F5`, `#C4C8C6`, and `#A8ADAB`.

---

### Task 1: Mobile design foundation

**Files:**
- Create: `lib/mobile_ui/hourtv_mobile_theme.dart`
- Create: `lib/mobile_ui/hourtv_mobile_components.dart`
- Test: `test/hourtv_mobile_ui_test.dart`

**Interfaces:**
- Produces: `HourTvMobileTokens`, `HourTvMobileScaffold`, `HourTvBottomNav`, `HourTvButton`, `HourTvChip`, `HourTvPosterCard`, `HourTvSectionHeader`.

- [ ] Write widget tests for the five destinations, token colors, safe-area navigation, and 48 px controls.
- [ ] Run the test and verify it fails against the current four-item/red mobile navigation.
- [ ] Implement the tokens and reusable primitives.
- [ ] Run the focused test and verify it passes.

### Task 2: Phone shell and Home

**Files:**
- Create: `lib/mobile_ui/hourtv_mobile_shell.dart`
- Modify: `lib/main.dart`
- Modify: `pubspec.yaml`
- Test: `test/hourtv_mobile_ui_test.dart`

**Interfaces:**
- Consumes: shared primitives from Task 1, `ContentStore.instance`, `StorageService`.
- Produces: `HourTvMobileShell`, five primary destinations, Figma-faithful Home.

- [ ] Add failing tests for the phone-only shell, fixed bottom navigation, Home hero actions, and category strip.
- [ ] Verify the focused tests fail for the expected missing behavior.
- [ ] Implement phone routing and the Home composition using real catalog data plus fallback artwork.
- [ ] Verify focused tests pass and non-phone `HourTvNewShell` remains selected.

### Task 3: Search, Library, Live TV, and Profile

**Files:**
- Create: `lib/mobile_ui/screens/hourtv_mobile_search.dart`
- Create: `lib/mobile_ui/screens/hourtv_mobile_library.dart`
- Create: `lib/mobile_ui/screens/hourtv_mobile_live.dart`
- Create: `lib/mobile_ui/screens/hourtv_mobile_profile.dart`
- Test: `test/hourtv_mobile_ui_test.dart`

**Interfaces:**
- Consumes: mobile components, catalog/store services, existing live/profile/settings routes.
- Produces: searchable catalog, persistent library, live channel list, profile/settings entry points.

- [ ] Add failing interaction tests for search filtering, tab selection, library empty/populated states, and navigation state.
- [ ] Verify failures.
- [ ] Implement the four destinations following their approved Figma frames.
- [ ] Verify focused tests pass.

### Task 4: Details, series, player, access, and profiles

**Files:**
- Create: `lib/mobile_ui/screens/hourtv_mobile_details.dart`
- Create: `lib/mobile_ui/screens/hourtv_mobile_profiles.dart`
- Modify: `lib/mobile_ui/hourtv_mobile_shell.dart`
- Test: `test/hourtv_mobile_ui_test.dart`

**Interfaces:**
- Consumes: `Channel`, `ContentStore`, existing player route and storage settings.
- Produces: Figma-faithful movie/series detail and profile-selection flows with functional actions.

- [ ] Add failing tests for details metadata/actions, season selection, profile selection, and player launch wiring.
- [ ] Verify failures.
- [ ] Implement screens and route transitions while preserving current services.
- [ ] Verify focused tests pass.

### Task 5: Visual and regression QA

**Files:**
- Modify only files identified by analyzer/test failures in this plan's scope.

**Interfaces:**
- Produces: analyzed and tested production Flutter app.

- [ ] Format modified Dart files.
- [ ] Run `flutter analyze` and resolve only regressions introduced by this implementation.
- [ ] Run the full `flutter test` suite.
- [ ] Run phone-size widget rendering checks for overflow and safe-area errors.
- [ ] Confirm `git diff -- ai-studio-app` is empty.
