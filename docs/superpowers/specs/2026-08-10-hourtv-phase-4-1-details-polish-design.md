# HourTV Phase 4.1 — Android Details Visual Polish

## Objective

Refine only `Android - Detalles` so the lower half feels as premium, cinematic, and editorial as the approved Hero. Preserve the approved screen structure and HourTV V2 visual language while reducing the impression of a database or technical information sheet.

## Protected scope

The following must remain unchanged:

- `Android - Inicio / V2`
- `Android - Inicio / Backup`
- `🎨 HourTV Design System`
- Approved reference image
- Existing Hero artwork and dominant Hero composition

No instance may be detached. No component may be flattened. Existing variables, styles, and linked Design System components remain the source of truth.

## Chosen visual direction

Use an editorial-minimal treatment: fewer rigid containers, clearer typography hierarchy, subtle separators, compact linked components, and stronger visual content. Major sections receive more vertical separation while their internal elements remain compact.

The density rhythm is:

1. Hero
2. Actions
3. Editorial text
4. Visual highlights and trailers
5. People
6. Posters
7. Editorial recommendation
8. Collapsed technical row

## Section design

### Synopsis

- Keep the `SINOPSIS` eyebrow and `Leer más` action.
- Limit the visible synopsis to approximately 3–4 lines.
- Improve line height, hierarchy, and vertical breathing room.
- Keep the section directly on the page background without a large container.

### Movie information

- Replace the two rigid information cards with one editorial information composition.
- Prioritize `Dirección`, `Reparto`, `Estudio`, `Año`, `Duración`, and `Idioma`.
- Use compact label/value groups with subtle separators rather than boxed cards.
- Move codec, HDR, audio, subtitles, resolution, and similar data to the collapsed technical section.

### Why watch

- Present three compact horizontal editorial highlights:
  - `Premiada`
  - `Dirección destacada`
  - `Favorita de la audiencia`
- Each highlight uses a small linked icon, a short title, and concise supporting text.
- Avoid oversized cards; use subtle surface contrast or separators only where needed.

### Trailers

- Use cinematic 16:9 thumbnails.
- Show approximately 1.3 items in the viewport to communicate horizontal scrolling.
- Each item includes artwork, linked play control, title, and duration.
- Keep artwork crop mode consistent and preserve linked typography.

### Cast

- Use a compact horizontal row with approximately four visible actors.
- Keep circular or softly rounded portraits.
- Show actor name and character name with clear primary/secondary hierarchy.

### More like this

- Use a poster carousel with approximately 3.2 visible posters.
- Preserve the `Poster Card` component linkage.
- Do not use progress bars or Continue Watching styling.

### Editorial review

- Keep `Crítica editorial` between `También te puede gustar` and `Detalles técnicos`.
- Treat it as a premium editorial recommendation, not a user review.
- Use a subtly differentiated surface without a heavy card boundary.
- Include a short quote limited to 2–3 lines.
- Include critic or publication name and a discreet score.
- Add one restrained red HourTV accent, such as a short rule or narrow side marker.
- Do not use large stars, comments, or app-store review patterns.

### Technical information

- Place technical information near the bottom.
- Collapse it into one compact row labeled `Detalles técnicos` with a chevron.
- Do not expose codec, HDR, Dolby, audio, or resolution values by default.
- Preserve adequate bottom safe-area padding.

## Component strategy

Reuse existing linked components wherever possible:

- Section Header
- Icon Button and line icons
- Avatar
- Poster Card
- Editorial Banner only where its native structure supports the intended result
- Existing typography styles, color variables, spacing variables, radii, borders, and effects

Modify only instance properties and screen-specific Auto Layout composition. Do not add or extend variants because the Design System must remain unchanged.

## Layout and scrolling

- Keep the frame at 412 × 917.
- Preserve vertical scrolling.
- Use Auto Layout for all major sections and content rows.
- Keep horizontal carousel overflow visible within the scroll content so the next item is partially shown.
- Use the existing 8-point spacing system and spacing variables.
- Maintain the existing bottom safe area.

## QA acceptance criteria

- Only `Android - Detalles` is modified.
- Hero artwork and approved Hero dominance are preserved.
- `Android - Inicio / V2`, Backup, Design System, and reference image are unchanged.
- All reusable elements remain linked instances.
- Detached instance count is zero.
- No component masters are created inside the screen.
- No local solid colors or strokes are introduced.
- Every visible text layer uses an existing text style and Inter.
- All major sections use Auto Layout.
- Vertical scrolling remains enabled.
- Horizontal carousels are not incorrectly clipped.
- Technical information is collapsed by default.
- Bottom safe-area padding remains correct.
- Layer names are clear and professional.
