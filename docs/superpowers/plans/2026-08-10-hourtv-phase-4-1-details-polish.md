# HourTV Phase 4.1 Details Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Polish only the lower half of `Android - Detalles` so it matches the approved Hero's premium cinematic and editorial quality.

**Architecture:** Preserve the existing 412 × 917 vertically scrolling frame, the Hero, and all protected HourTV frames. Recompose only the existing lower sections with screen-specific Auto Layout frames, existing variables and text styles, and linked Design System instances; do not create component masters or modify the Design System page.

**Tech Stack:** Figma Design, Figma Plugin API through `use_figma`, HourTV variables, HourTV text/effect styles, existing local component instances.

## Global Constraints

- Modify only `Android - Detalles` (`54724:395`).
- Do not modify `Android - Inicio / V2` (`54661:184`), `Android - Inicio / Backup` (`1:2058`), `🎨 HourTV Design System` (`54618:79`), or reference image `3:4`.
- Preserve the existing Hero artwork and dominant Hero composition.
- Do not detach instances, flatten vectors, rasterize text, or create component masters inside the screen.
- Use Inter, existing text styles, existing variables, existing effects, and Auto Layout.
- Keep the frame 412 × 917, vertical scrolling, and at least 64 px bottom safe-area padding.

---

### Task 1: Capture the protected baseline

**Figma nodes:**
- Inspect: `54724:395`, `54724:396`, `54724:398`
- Protect: `54661:184`, `1:2058`, `54618:79`, `3:4`

**Interfaces:**
- Consumes: the current Phase 4 screen and local Design System library.
- Produces: baseline geometry, image hashes, instance counts, and protected-node signatures used by Task 6.

- [ ] **Step 1: Inspect the current frame and sections**

Record the frame size, scroll settings, bottom padding, section order, Hero image hash, all top-level instance master IDs, and protected-node geometry/hash values.

- [ ] **Step 2: Verify scope before mutation**

Confirm that the screen is `412 × 917`, scroll content uses vertical Auto Layout, Hero is `54724:398`, and the protected nodes match their recorded signatures.

- [ ] **Step 3: Capture a visual baseline**

Render the top viewport and a temporarily expanded full-flow screenshot. Restore the viewport to `412 × 917` and clipping immediately afterward.

### Task 2: Refine synopsis and editorial movie information

**Figma nodes:**
- Modify: `54724:400` (`Section / Sinopsis`)
- Modify: `54724:401` (`Section / Información de la película`)

**Interfaces:**
- Consumes: existing text styles, text color variables, border variables, and spacing variables.
- Produces: a 3–4-line synopsis and a single unboxed editorial information composition.

- [ ] **Step 1: Refine the synopsis**

Keep `SINOPSIS`, the current synopsis copy, and the linked `Leer más` action. Set the body to approximately four visible lines, use the existing Body style, increase section breathing room, and keep the background transparent.

- [ ] **Step 2: Remove the rigid information-card treatment**

Replace the two existing card frames with one transparent vertical information layout. Preserve linked Section Header usage.

- [ ] **Step 3: Build priority metadata groups**

Create three Auto Layout rows with two label/value groups per row: `Dirección / Lina Torres`, `Reparto / Irene Solano · Damián Cruz`, `Estudio / Aurora Pictures`, `Año / 2026`, `Duración / 2 h 18 min`, and `Idioma / Español`. Use existing Caption or Label styles for labels, Body or Label styles for values, and subtle variable-bound separators.

- [ ] **Step 4: Verify the section**

Confirm no large solid container remains, every visible text layer has an existing text style, all solid fills/strokes are variable-bound, and the section uses Auto Layout.

### Task 3: Convert Why Watch into compact editorial highlights

**Figma nodes:**
- Modify: `54724:402` (`Section / Por qué verla`)

**Interfaces:**
- Consumes: linked Search Button or Icon Button instances and existing line-icon variants.
- Produces: three compact horizontal editorial highlight rows.

- [ ] **Step 1: Preserve the linked section header**

Keep `¿Por qué verla?` and its existing linked Section Header instance.

- [ ] **Step 2: Replace oversized cards**

Create a transparent vertical highlight list with three compact horizontal rows. Each row contains one linked icon instance, a text group, and a subtle divider except the last row.

- [ ] **Step 3: Set editorial copy**

Use `Premiada / Reconocida por su narrativa y fotografía.`, `Dirección destacada / Una puesta en escena precisa y humana.`, and `Favorita de la audiencia / Entre las historias más guardadas de HourTV.`

- [ ] **Step 4: Verify compactness**

Confirm the rows use accessible touch-height spacing without reading as three separate cards, and all component instances remain linked.

### Task 4: Strengthen trailers, cast, and poster carousel

**Figma nodes:**
- Modify: `54724:403` (`Section / Tráilers`)
- Modify: `54724:404` (`Section / Reparto`)
- Modify: `54724:405` (`Section / También te puede gustar`)

**Interfaces:**
- Consumes: existing Editorial Banner, Avatar, Poster Card, play-icon, image-fill, and Section Header instances.
- Produces: visual horizontal carousels with approximately 1.3 trailers, 4 cast members, and 3.2 posters visible.

- [ ] **Step 1: Recompose trailer items at 16:9**

Use linked instances or linked nested play controls inside 16:9 Auto Layout items. Each item shows thumbnail, play control, title, and duration. Set item width so the viewport reveals approximately 1.3 items and keep image crop mode `FILL`.

- [ ] **Step 2: Refine cast density**

Keep linked Avatar instances, actor names, and character names. Set item widths and gaps so approximately four actors are visible at 412 px without cramped labels.

- [ ] **Step 3: Refine the poster carousel**

Keep linked Poster Card instances, hide progress/play overlays, use consistent 2:3 crops, and size items so approximately 3.2 posters are visible.

- [ ] **Step 4: Verify horizontal overflow**

Render each section with off-viewport content temporarily visible. Confirm the next item is partially visible, artwork is not distorted, and the screen viewport clips only at the 412 px boundary.

### Task 5: Refine editorial review and collapse technical details

**Figma nodes:**
- Modify: `54724:406` (`Section / Crítica editorial`)
- Modify: `54724:407` (`Section / Detalles técnicos`)

**Interfaces:**
- Consumes: linked Section Header and chevron/icon instances, surface/text/brand variables, and existing text styles.
- Produces: one premium editorial recommendation and one collapsed technical row.

- [ ] **Step 1: Build the editorial recommendation surface**

Keep the linked `Crítica editorial` header. Replace the heavy review banner with a lightweight Auto Layout surface using `Surface / Primary` or `Background / Secondary`, no heavy shadow, and one short variable-bound red accent rule.

- [ ] **Step 2: Set the editorial content**

Use the quote `“Una historia visualmente hipnótica que convierte el fin del mundo en un relato profundamente humano.”` limited to 2–3 lines. Add `Marina Vega · Plano Secuencia` and a discreet `9.2 / 10` value using secondary or muted text hierarchy.

- [ ] **Step 3: Collapse technical information**

Keep the linked `Detalles técnicos` header if it supports the hierarchy. Replace the exposed six-value grid with one compact surface row labeled `Detalles técnicos` and a linked ChevronRight icon. Do not show codec, HDR, Dolby, audio, or resolution values.

- [ ] **Step 4: Verify editorial tone**

Confirm the section contains no large stars, user comments, store-review motifs, or heavy card styling.

### Task 6: Polish rhythm and run final QA

**Figma nodes:**
- Verify: `54724:395`, `54724:396`, and all descendants
- Compare: protected nodes recorded in Task 1

**Interfaces:**
- Consumes: the completed Phase 4.1 composition and Task 1 baseline.
- Produces: final visual screenshots and a structured QA report.

- [ ] **Step 1: Normalize major-section rhythm**

Use variable-backed spacing to increase separation between major sections while keeping internal rows compact. Preserve the section order: Hero, Actions, Synopsis, Movie Information, Why Watch, Trailers, Cast, More Like This, Editorial Review, Technical Details.

- [ ] **Step 2: Restore viewport and safe area**

Set `Android - Detalles` and scroll content to `412 × 917`, enable clipping, keep vertical scrolling, and preserve at least 64 px bottom padding.

- [ ] **Step 3: Run structural QA**

Report total linked instances, detached instances, component masters inside the screen, visible texts without styles, non-Inter fonts, unbound solid fills/strokes, non-Auto-Layout major sections, generic layer names, and image fills not using `FILL`.

- [ ] **Step 4: Verify protected nodes**

Compare `Android - Inicio / V2`, Backup, Design System, and reference-image signatures with Task 1. Any mismatch fails QA and must be reverted without touching unrelated user changes.

- [ ] **Step 5: Run visual QA**

Render the top viewport, lower-half sections, and temporarily expanded full flow. Check hierarchy, density alternation, typography readability, carousel peeking, absence of clipping, and Hero dominance. Restore the mobile viewport immediately.

- [ ] **Step 6: Present the final result**

Return: visual improvements, components reused, components modified or extended, linked-instance count, detached-instance count, and QA outcome.
