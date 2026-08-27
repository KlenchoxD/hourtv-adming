# HourTV Android Mobile — XuperTV + AI Studio Hybrid Design Specification

**Date:** 2026-08-27  
**Status:** Approved visual direction; implementation pending final specification review  
**Platform scope:** Android mobile only  
**Product:** HourTV

## 1. Objective

Replace the current Android mobile presentation layer with a faithful native Flutter implementation built from two approved visual references:

1. `C:\Users\Kleiner\Downloads\ABDM\Compressed\XuperTV\XuperTV\index.html`
2. The approved HourTV Google AI Studio prototype.

The result must look and behave like one coherent HourTV application. The XuperTV HTML controls the visual treatment and information architecture for the main discovery experience. Google AI Studio controls only the four product areas that do not exist in the HTML reference.

This is a visual and interaction replacement for Android mobile. It is not a WebView integration and it must not change Smart TV, tablet, or desktop layouts.

## 2. Non-negotiable source hierarchy

When references conflict, use this order:

1. The explicit decisions in this specification.
2. The XuperTV HTML reference for Home, categories, search, filters, details, and settings.
3. The approved Google AI Studio prototype for Live TV, Profiles, My Library, and Player.
4. Existing HourTV behavior and data contracts.
5. Existing Android mobile implementation only when none of the approved references defines the behavior.

The SuperTV name and logo are never copied. Every visible brand reference must be HourTV and must use the existing approved HourTV logo asset.

## 3. Protected scope

The following are outside this migration and must remain unchanged:

- Smart TV / Android TV UI and navigation.
- Tablet UI and breakpoints.
- Desktop UI and breakpoints.
- Existing backend, repositories, catalog sources, playback services, authentication, and persistence contracts unless a minimal adapter is required.
- The original XuperTV HTML file.
- The approved Google AI Studio reference.
- Existing user-owned changes unrelated to this Android mobile replacement.

Platform routing must continue to select the current non-phone shells outside the Android phone breakpoint.

## 4. Implementation approach

Reproduce the approved references as native Flutter widgets.

Do not embed the HTML in a WebView. A WebView would create a second navigation stack, inconsistent accessibility, unreliable system back behavior, duplicated state, and visual differences between the prototype and the native product.

The new Android mobile UI will:

- use one Flutter navigation/state model;
- reuse the existing HourTV catalog and playback data;
- use responsive constraints instead of device-specific coordinates;
- preserve native scrolling, focus, semantics, back behavior, safe areas, and keyboard handling;
- use shared tokens and components so visually identical elements cannot drift between screens;
- keep all user actions real, not simulated.

## 5. Route and reference matrix

| Android mobile destination | Visual authority | Required behavior |
| --- | --- | --- |
| Profile gate / profile creation | Google AI Studio | First launch requires profile creation; later launches require profile selection |
| Home | XuperTV HTML | Mixed real catalog: movies, series, anime, and novelas |
| Category browsing | XuperTV HTML | Horizontal category selector and filtered content |
| Search | XuperTV HTML | Search history, popular searches, live filtering, result counts, result grid |
| Filter overlay | XuperTV HTML | Native overlay matching the reference hierarchy and styling |
| Movie/series/content detail | XuperTV HTML | Player preview/artwork, metadata, favorite state, description, credits, recommendations |
| TV | Google AI Studio | Existing approved channel categories, live content, favorite channels, parental restrictions |
| My Library | Google AI Studio | My List, Continue Watching, History, filtering and sorting |
| Player | Google AI Studio | Playback HUD, skip intro/recap, next content, audio/subtitles and player states |
| Profile and profile management | Google AI Studio | Create, select, edit and persist profiles and avatars |
| Settings | XuperTV visual language adapted to functional HourTV settings | Real HourTV settings only; no SuperTV social links or placeholder entries |

## 6. Brand substitution

All branding must be HourTV:

- Replace the SuperTV image and wordmark with the existing HourTV logo.
- Preserve the compact visual footprint and alignment of the HTML header.
- Do not recolor or redraw the approved HourTV logo.
- Do not show a global header on loading, profile gate, detail, player, or any screen where the approved reference omits it.
- Do not show casting outside the approved live-TV/player contexts.

## 7. Visual foundation

### 7.1 XuperTV-derived mobile foundation

Use the reference values faithfully for the HTML-controlled screens:

- Primary background: `#151525`.
- Header / deepest surface: `#0D0D1B`.
- Primary accent: `#4305EE`.
- Primary text: white.
- Secondary text: the muted cool-gray treatment visible in the reference.
- Typography: Inter throughout the native app.
- Cards: dark, image-led, compact, and border-light.
- Grids: three visible poster columns at the 393 px reference width.
- Header: compact HourTV logo on the left and reference-matching actions on the right.
- Category navigation: horizontally scrollable, with one selected state and no persistent focus residue.

The purple reference accent controls the XuperTV-derived screens. Do not introduce the previous emerald TV accent or the old red Android accent into those screens unless it is part of the approved HourTV logo artwork.

### 7.2 AI Studio-derived foundation

Live TV, Profiles, My Library, and Player retain their approved Google AI Studio visual direction. They must still share:

- Inter typography;
- the HourTV logo and name;
- global spacing and safe-area rules;
- consistent system navigation;
- shared Android phone breakpoints;
- the same persisted profile, library, catalog, and playback state.

Where AI Studio and XuperTV meet, screen-local colors can differ according to the approved references, but shared controls must not change shape, size, or behavior unexpectedly between destinations.

## 8. Android mobile shell

The shell owns navigation, safe areas, route state, and bottom navigation visibility.

### 8.1 Bottom navigation

Use one compact mobile bottom navigation with these destinations:

1. Inicio
2. TV
3. Buscar
4. Mi Biblioteca
5. Perfil

Requirements:

- Never render outside the phone frame or safe area.
- Never show a keyboard-style focus outline after a pointer/touch selection.
- Use one selected destination only.
- Selected and pressed states must be distinct.
- Hide on profile gate, full-screen player, loading, and other immersive routes.
- On details, follow the approved target reference; avoid duplicating navigation when the content is presented as a pushed route.
- Back returns to the previous route and preserves its scroll position.

### 8.2 Header visibility

The compact HourTV header appears only where the reference requires it. It must not become a global overlay. Header and category rows must not collide with content during scroll.

## 9. Home and discovery

Home follows the XuperTV reference composition rather than the previous Android layout.

Required content:

- Hero/banner area matching the reference proportions.
- Horizontal category row.
- Multiple compact poster sections.
- Mixed catalog of movies, series, anime, and novelas.
- Real HourTV titles and artwork from the existing repository whenever available.
- No Live TV promotional card inside Home.
- No fake metadata or static counters when repository data is available.

The initial section set follows the reference rhythm while using HourTV labels and real content. Poster cards use a shared aspect ratio, text height, spacing, and metadata treatment across every section.

## 10. Search and filters

Search follows the XuperTV reference visually but uses the existing HourTV catalog.

Required states:

- Empty query with search history and popular searches.
- Active query with live-filtered results.
- No results.
- Search history item removal and clear-all.
- Filter overlay.
- Result count derived from the actual filtered list.

Search must cover movies, series, anime, and novelas. Results continue as the user scrolls using lazy pagination or incremental rendering. It must not fabricate network pagination when the current repository is local; in that case, progressively reveal the real local result set.

## 11. Details

Details follow the XuperTV reference structure and compact density:

- top media/artwork region;
- title and discreet rating;
- favorite action;
- country, year, and content categories;
- description;
- director and cast;
- expand/collapse for long credits or descriptions;
- recommendations based on the actual catalog.

Do not restore sections the user previously removed, including heavy editorial review blocks, technical details cards, or “Por qué verla” sections. Keep information readable, correctly spaced, and free of clipped labels.

For episodic content, include a native season selector and episode list. The season menu must remain within the device viewport, use one-line season labels, and avoid detached or external overlays.

## 12. Live TV

Use the approved AI Studio Live TV design and existing real behavior.

Required categories:

- Todos
- Favoritos
- Deportes
- Cine / Series
- Populares
- Noticias
- Infantil
- Religioso
- Novelas
- `+18` only when parental controls permit it

The header label is `TV`, not `TV en vivo`. Channel categories remain a single horizontal row. Full-screen channel playback supports remote/keyboard up and down channel changes where applicable, while phone touch interaction remains explicit and accessible.

## 13. Profiles

Use the approved AI Studio profile experience.

Requirements:

- First launch with no profiles forces profile creation.
- Later launches present profile selection before entering the catalog.
- Create, edit, select and persist profiles.
- Avatar selection uses the approved profile artwork choices.
- Each profile owns its own list, progress/history, preferences, and maturity settings where supported.
- A profile selection is a real state change, not a decorative screen.

## 14. My Library

Use the approved AI Studio library design and existing repository data.

Required tabs:

- Mi Lista
- Continuar viendo
- Historial

Filtering and sorting must be functional. Sticky controls must not overlap or detach during scroll. Final scroll padding must be consistent with Home and Search and limited to the bottom-navigation safe clearance.

## 15. Player

Use the approved AI Studio player direction and existing playback services.

Required behavior and states:

- controls visible;
- controls hidden;
- paused;
- audio and subtitles;
- next content;
- skip intro;
- skip recap;
- progress, duration, seek, play/pause, back, quality and full screen where appropriate.

The video remains visually dominant. Skip actions are contextual and do not summon the full HUD. Player controls must use adequate touch targets and disappear according to the approved interaction timing.

## 16. Components and consistency rules

Create or consolidate shared mobile components for:

- HourTV compact header;
- bottom navigation;
- category item;
- poster card;
- horizontal content row;
- section heading;
- primary and secondary actions;
- icon action;
- search field;
- filter and sort menu;
- empty/loading/error states;
- profile tile;
- library segmented control;
- player control and overlays.

No screen may duplicate a component solely to change hardcoded dimensions. Differences must be expressed through explicit variants or parameters. Persistent selection, keyboard focus, hover, pressed, and disabled states must be independently modeled.

## 17. Responsive rules

Validate the Android mobile UI at these logical widths:

- 360 px
- 393 px (primary visual reference)
- 412 px
- 428 px
- 480 px

Rules:

- Use `SafeArea` or equivalent measured insets.
- Never place navigation or menus outside the viewport.
- Avoid fixed absolute positions for scrolling content and overlays.
- Poster grids adapt column width and gutter while preserving card ratio.
- Text must not overflow; use defined line limits and predictable card heights.
- Dropdowns and season menus use constrained overlays anchored to their trigger.
- Bottom padding is exactly content clearance plus safe-area inset, not arbitrary spacer content.

## 18. State and data integration

Maintain one source of truth for:

- active profile;
- selected bottom destination;
- selected category;
- search query and result set;
- favorites / My List;
- watch progress and history;
- Live TV favorites and category;
- parental restrictions;
- current playback item and episode sequence.

Do not keep selected/filter state globally when it belongs to a route unless persistence is intentional. Returning to a screen may restore scroll position, but entering a category screen fresh must not accidentally inherit stale focus or pressed state.

## 19. Migration strategy

Implementation proceeds behind the existing phone-only routing boundary:

1. Freeze and checksum the XuperTV HTML reference without editing it.
2. Freeze the current approved AI Studio reference already stored in the repository.
3. Define the shared mobile theme, tokens, responsive metrics, and shell.
4. Implement the XuperTV-derived Home, Search, Filters, Details, and Settings.
5. Connect the AI Studio-derived Profile, Live TV, My Library, and Player screens.
6. Connect real repositories and actions.
7. Replace only the Android phone entry path.
8. Remove obsolete phone UI only after parity and regression checks prove it is no longer referenced.

Old mobile code must not be deleted early. Removal happens only after the new shell is complete and verified, so no working behavior is lost during migration.

## 20. Performance requirements

- Avoid rebuilding entire destination trees on every navigation or keypress.
- Preserve destination state with indexed/lazy stacks where appropriate.
- Cache decoded artwork and request size-appropriate images.
- Use lazy builders for long grids and search results.
- Do not animate large blur, glow, or full-screen opacity layers continuously.
- Keep loading animations lightweight and frame-stable.
- Avoid nested unconstrained scroll views.
- Navigation transitions must remain fluid on a physical Android device.

## 21. Accessibility and interaction

- Minimum touch target: 48 logical pixels for primary interactive controls.
- Provide semantic labels for icon-only actions.
- Preserve Android back behavior.
- Use readable contrast over imagery.
- Respect text scaling without clipping critical actions.
- Touch selection must not leave desktop-style focus rings.
- Keyboard/remote focus remains available where the same Flutter code runs with keyboard input, but must not look permanently selected on touch devices.

## 22. Acceptance QA

### Visual

- Compare every XuperTV-derived phone screen against the HTML reference at 393 px.
- Compare Live TV, Profiles, My Library, and Player against the AI Studio reference.
- Confirm HourTV branding everywhere and zero SuperTV branding.
- Confirm consistent poster ratios, card widths, gutters, typography, and control alignment.
- Confirm no overlaps, clipped labels, off-screen menus, unexplained lines, or excessive end-of-scroll gaps.

### Functional

- Profile creation and selection persist.
- Bottom navigation changes exactly one destination.
- Search count and filtering match actual results.
- Categories and sorting change the displayed dataset.
- Favorites/My List stay synchronized across details and library.
- Player actions, skip actions, next content, and resume progress work.
- Live TV categories and parental visibility behave correctly.
- Back navigation and scroll restoration work.

### Regression

- Existing Smart TV interface unchanged.
- Existing tablet interface unchanged.
- Existing desktop interface unchanged.
- Existing data/services continue to work.
- No new analyzer errors.
- Targeted widget and golden tests pass.
- Android build succeeds.
- Physical-device smoke test passes at the end.

## 23. Definition of done

The migration is complete only when:

- Android mobile uses the new hybrid shell from entry to exit.
- All HTML-authority screens match the XuperTV reference with HourTV branding.
- Live TV, Profiles, My Library, and Player match the approved AI Studio designs.
- Real catalog and actions are connected.
- No placeholder or simulated control remains in a primary flow.
- No protected non-phone platform changed visually or behaviorally.
- All required responsive, functional, regression, and physical-device checks pass.

