# HourTV Android — Figma Implementation Design

## Source of truth

The approved Figma file `HourTV Android – UI UX` is the visual source of truth. The production target is the Flutter application under `lib/`; `ai-studio-app/` remains an untouched prototype/reference.

## Scope

- Replace the phone UI with the approved 412 × 915 Android composition while preserving the existing catalog, playback, favorites, profiles, settings, live-TV, and persistence behavior.
- Keep tablet, desktop, Android TV, and TV Box layouts on the existing responsive shell.
- Implement the approved deep-black, emerald, white, and muted-gray visual language with Inter typography.
- Use one reusable mobile component layer for navigation, buttons, chips, cards, headers, loading states, and screen scaffolds.
- Keep the bottom navigation fixed and safe-area aware. Content scrolls independently and ends without artificial empty space.
- Use live `ContentStore` and `StorageService` data, with existing preview content only as an empty-catalog fallback.

## Architecture

`HourTVApp` selects a phone-only `HourTvMobileShell` through `DeviceProfile`; non-phone devices continue using `HourTvNewShell`. The mobile shell owns the five primary destinations (Inicio, TV, Buscar, Mi Biblioteca, Perfil) and opens existing functional detail/player/settings flows through the navigator. Shared visual primitives live in `lib/mobile_ui/` and consume centralized HourTV mobile tokens.

## Acceptance criteria

- Phone UI visually follows the approved Figma frames and uses the five-item bottom navigation.
- No AI Studio files are modified.
- Existing non-phone layouts and playback/catalog services remain functional.
- Search filters real content, favorites remain persistent, and live-TV/detail/player actions remain wired.
- `flutter analyze` and the full Flutter test suite pass.
