# HourTV AI Studio Native Migration Design

## Objective

Replace the complete Android presentation layer of the Flutter HourTV application with a native Flutter implementation that visually and behaviorally matches the current Google AI Studio prototype from start to finish.

The Google AI Studio project is the sole visual and interaction reference. The Flutter application remains the production runtime. Google AI Studio itself must not be modified.

## Frozen source of truth

- AI Studio project: `HourTV Android Streaming`
- AI Studio application ID: `c7f27888-c959-425b-a554-e27ab5885c6d`
- Export captured: 2026-08-26
- Frozen archive: `references/ai-studio/hourtv-android-streaming-2026-08-26.zip`
- Archive SHA-256: `ED0D1FC439FC1CADFC0162ECFCBA0F050E973A1736CCEE0D93019AFCC84A53C0`.
- Reference viewport family: 360×800, 393×852, 412×915, 428×926, and 480×960.

Previous downloads, the older `ai-studio-app` copy, existing Figma screens, and the currently installed Flutter interface are not visual authorities when they disagree with this frozen export.

## Scope

The native migration covers the complete Android journey:

1. Startup and system states.
2. Profile gate, profile creation, profile selection, profile editing, and parental PIN states.
3. Home.
4. HourTV Originals.
5. Live TV.
6. Search and progressive discovery.
7. My Library.
8. Movie and series details.
9. Video player, including contextual controls and playback states.
10. Profile and settings.
11. Bottom navigation, headers, cards, buttons, tabs, menus, modal sheets, snackbars, dialogs, loading, empty, offline, and error states.

Every screen, overlay, modal, and reusable control visible in the frozen AI Studio export is in scope. No existing Flutter screen may remain visible as a fallback when the migration is complete.

## Non-goals

- Do not embed the React prototype in a WebView.
- Do not convert the application from Flutter to React.
- Do not redesign, improve, reinterpret, or simplify the AI Studio visuals.
- Do not modify the AI Studio project.
- Do not rebuild working media, IPTV, catalog, persistence, casting, search, or networking services unless a narrow adapter is required by the new UI.
- Do not use the Figma file as the visual source for this migration.

## Architecture

The migration uses a native visual-port architecture.

### Reference layer

The frozen AI Studio export supplies the authoritative tokens, content hierarchy, view composition, component states, copy, assets, responsive rules, and interaction behavior. React and Tailwind implementation details are specifications, not runtime dependencies.

### Flutter presentation layer

A focused Flutter UI package will reproduce the reference with native widgets. It will contain:

- HourTV design tokens matching `#080A09`, `#101412`, `#151917`, `#00C781`, `#F5F5F5`, `#C4C8C6`, `#A8ADAB`, and `#27302C` where used by the source.
- Reusable primitives for logo, header, bottom navigation, buttons, icon buttons, category tabs, poster cards, progress cards, channel cards, modal sheets, snackbars, profile avatars, and player controls.
- One native view per AI Studio view.
- Responsive layout helpers based on available width and safe areas rather than hard-coded coordinates.
- A single navigation shell that matches the AI Studio route and overlay hierarchy.

The old Flutter presentation widgets are removed from the active widget tree once their replacement is verified. Existing files may be deleted only after the new route is proven to cover the same flow.

### Domain and service layer

Existing Flutter services remain authoritative for real application behavior:

- catalog and media models;
- IPTV channels and playback;
- video player and embed resolution;
- search;
- My List and history persistence;
- profiles and parental controls;
- casting;
- network, loading, offline, and error handling.

Small adapters map these existing models and callbacks into the new native views. Presentation widgets must not duplicate business logic or replace live data with permanent mock data.

## Visual fidelity rules

- Match the AI Studio hierarchy, geometry, spacing, corner radii, typography, icon sizing, imagery treatment, overlays, gradients, shadows, and motion.
- Match visible Spanish copy exactly unless the production data supplies a dynamic title or metadata value.
- Preserve the HourTV wordmark treatment used by the reference.
- Use the green accent only where the reference uses it.
- Keep touch targets at least 44×44 logical pixels and preferably 48×48.
- Respect Android status/navigation safe areas.
- Do not allow horizontal overflow, clipped menus, detached overlays, oversized scroll endings, or navigation elements outside the device width.
- Selected, focused, pressed, loading, disabled, and hidden states must remain distinct.
- Player and Live TV immersive states must retain native orientation and fullscreen behavior while matching the reference controls.

## Screen behavior

### Access and profiles

The first launch requires profile creation when no profile exists. Later launches show the AI Studio profile gate. Selection, creation, editing, deletion, avatar choice, and PIN-protected profiles use the same visual states as the reference and persist through the existing Flutter storage layer.

### Home and Originals

The home hierarchy, hero, category navigation, continue-watching content, Originals sections, cards, calls to action, and bottom navigation match the reference. Horizontal lists scroll naturally and vertical content ends with only the safe-area spacing defined by the reference.

### Live TV

Categories, channels, favorites, guide information, player chrome, fullscreen controls, parental restrictions, signal states, and next/previous channel behavior match the reference while using real IPTV data and playback.

### Search

The search input, recent items, trends, filters, progressive catalog loading, empty states, and result grid match the reference. Search results remain functional and open native details.

### Library

My List, Continue Watching, History, content filters, sorting, removal feedback, and empty states match the reference and use existing persisted data.

### Details

Movie and series details reproduce the reference hero, metadata, actions, episodes or related content, season menu, sharing feedback, and spacing. All overlays must remain inside the device bounds.

### Player

The player reproduces the reference HUD, hidden controls, pause, skip intro, skip recap, next content, audio/subtitles, buffering, error, retry, fullscreen, and touch behavior while preserving real Flutter playback.

### Profile and settings

The profile header, settings hierarchy, switches, dialogs, update state, parental options, and modal sheets match the reference. Snackbar and modal layering must be confined to the app viewport and never overlap incorrectly.

## State and navigation

The active route is the single source of truth for the bottom navigation selection. Screens do not retain unintended focus or selection when re-entered unless the AI Studio source explicitly persists it. Back navigation closes the topmost overlay first, then returns to the previous screen.

Global snackbars render above page content and bottom navigation but below modal sheets. Feedback triggered inside a modal remains inside that modal when the reference behaves that way.

## Migration sequence

1. Freeze and inventory the current AI Studio export.
2. Add golden-testable tokens and shared primitives.
3. Implement profile gate and application shell.
4. Port Home and Originals.
5. Port Search and Library.
6. Port Details.
7. Port Live TV.
8. Port Player.
9. Port Profile, settings, and system states.
10. Remove the old presentation routes after parity verification.
11. Run full static, unit, widget, golden, device, and interaction QA.

Each stage must remain compilable and testable. Existing production functionality must remain reachable until its replacement passes.

## Verification and acceptance

Completion requires all of the following:

- `flutter analyze` passes with zero issues.
- The full Flutter test suite passes.
- Golden comparisons exist for the principal view of every scoped screen at 393×852 and at least one additional narrow or wide viewport.
- Layout smoke tests cover 360×800, 393×852, 412×915, 428×926, and 480×960 without overflow exceptions.
- Navigation tests cover every bottom-navigation destination and details/player routes.
- Interaction tests cover profiles, filters, sorting, search, My List, season selection, Live TV categories, fullscreen, player controls, modal sheets, and snackbars.
- Existing playback, IPTV, casting, persistence, and network services continue to pass their tests.
- A debug APK builds successfully.
- The APK installs and opens on the connected Infinix X6870.
- Device logs contain no fatal exception, ANR, or Flutter rendering exception.
- Device screenshots for all primary screens visually match the frozen AI Studio reference.
- No old Flutter presentation screen remains accessible.
- Google AI Studio remains unchanged.

## Rollback and safety

The current dirty worktree contains user-owned changes and must not be reset, discarded, or overwritten wholesale. Migration edits are limited to the Flutter presentation layer, narrow adapters, tests, and required asset declarations. Each phase should be independently reviewable so a visual mismatch can be corrected without reverting unrelated application functionality.
