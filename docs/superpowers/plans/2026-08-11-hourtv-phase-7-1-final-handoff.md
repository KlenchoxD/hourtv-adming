# HourTV Phase 7.1 to Final Handoff Execution Plan

**Goal:** Complete the approved HourTV master design program in the current Figma file, preserving approved work and leaving a production-ready multi-platform design package with QA and handoff documentation.

**Working method:** Execute in Figma through the existing HourTV file. Treat every previously approved screen, backup, reference image, and the current Design System structure as protected unless a phase explicitly authorizes a targeted change. After each phase, run a scoped QA pass and correct issues before proceeding.

## Global constraints

- Do not implement application code.
- Permanently exclude download-related UI, components, settings, states, or actions.
- Keep application instances linked; target zero detached instances.
- Use HourTV variables, Inter text styles, Auto Layout, clean names, and unlocked editable layers.
- Do not delete approved backups or reference material.
- Stop only for destructive risk, permissions/quota exhaustion, or an irresolvable technical conflict.

## Execution sequence

### 1. Phase 7.1 — Global download cleanup

- Remove the Details download shortcut and rebalance the remaining approved actions.
- Replace Library / Downloads with Library / Collection and reduce Library navigation to Guardados / Historial.
- Remove download actions from overflow menus.
- Remove download-only Design System component sets without breaking reusable progress components.
- QA: zero user-facing download terminology or functionality, zero broken/detached instances, protected layouts intact.

### 2. Phase 8 — Profile, accounts, and settings

- Create six 412×917 Android profile states: Overview, Switch Profile, Edit Profile, Preferences, Parental Controls, Playback & Accessibility.
- Reuse the existing bottom navigation with Perfil selected.
- QA: linked components, no downloads, touch targets, hierarchy, Auto Layout, variables/styles.

### 3. Phase 9 — Live TV

- Create five 412×917 Android TV states: Ahora, Guía, Canal, Categorías, Sin señal.
- Keep live programming visually distinct from the VOD home experience.
- QA: live-state clarity, mobile-friendly guide, safe areas, linked components, no downloads.

### 4. Phase 10 — Access and profile selection

- Create Launch / Splash, Welcome, Sign In, Verification, and Select Profile.
- Reuse Phase 8 profile selection instead of duplicating components.
- QA: form clarity, six-digit verification focus, no unsupported pricing claims, linked components.

### 5. Phase 11 — System and resilience states

- Create Loading, Content Skeleton, Network Error, Server Error, Content Unavailable, Session Expired, Playback Error, and Empty Generic.
- Create reusable state components where useful without large illustrations.
- QA: no offline-download fallback, appropriate retry/navigation, linked styles/components.

### 6. Phase 12 — Tablet

- Create responsive 768×1024 tablet versions of Inicio, Buscar, Detalles, Mi Biblioteca, TV, Perfil, and Reproductor.
- Adapt density, Hero, margins, card visibility, and multi-column layouts; do not scale mobile screens.
- QA: responsive composition, Auto Layout, touch targets, linked tokens/components, no downloads.

### 7. Phase 13 — Desktop

- Create true 1440×900 desktop versions of Inicio, Buscar, Detalles, Mi Biblioteca, TV, Perfil, and Reproductor.
- Add appropriate desktop navigation, hover preparation, wider editorial layouts, and cinematic artwork.
- QA: pointer/hover states, responsive hierarchy, linked components/tokens, no downloads.

### 8. Phase 14 — Android TV / TV Box

- Create eight 1920×1080 10-foot states: Home, Search, Details, Live TV, Library, Profile Select, Player, Audio & Subtitles.
- Define clear D-pad focus using scale, bright border/elevation, and controlled red accents.
- QA: directional navigation clarity, readable typography, focus visibility, player controls, no downloads.

### 9. Phase 15 — Responsive and Design System hardening

- Review mobile, tablet, desktop, and TV component coverage.
- Add only missing responsive, hover, focus, pressed, disabled, touch, and TV variants.
- Remove accidental duplicate families while preserving application links.
- QA: tokens, naming, variants, responsive properties, zero detached instances.

### 10. Phase 16 — Accessibility QA

- Audit contrast, minimum 48 px mobile targets, secondary text, subtitles, TV focus, non-color state cues, hierarchy, text scaling, and controls over imagery.
- Correct clear issues without changing the HourTV identity.
- Add a concise accessibility decisions section in the Design System.

### 11. Phase 17 — Prototype preparation

- Prepare the approved mobile, search, library, live TV, and profile flows.
- Create safe Figma connections if supported; otherwise document trigger, destination, transition, and behavior.
- Document player interactions: show/hide controls, Play/Pause, seek, Skip Intro, Skip Recap, Audio/Subtitles, Next Content.

### 12. Phase 18 — Flutter handoff documentation

- Create Figma/project documentation for screen inventory, navigation, component/state mapping, responsive behavior, player markers, asset naming, and design tokens.
- Do not generate Flutter code.

### 13. Phase 19 — Final QA and organization

- Run a global Design System, application, accessibility, platform coverage, and zero-download audit.
- Arrange pages/sections for Design System, Android, Tablet, Desktop, Android TV / TV Box, and Handoff / Documentation.
- Preserve approved backups and reference material.
- Produce the required 14-item consolidated report with evidence-backed counts and remaining human-review limitations.

