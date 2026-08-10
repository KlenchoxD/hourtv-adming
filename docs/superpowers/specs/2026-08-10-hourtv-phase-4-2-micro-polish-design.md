# HourTV Phase 4.2 — Final Micro Polish

## Objective

Refine only `Section / Por qué verla` and `Section / Tráilers` inside `Android - Detalles`. Preserve the approved screen structure, the HourTV V2 visual language, and every other section without changes.

## Protected scope

Do not modify the Hero, Synopsis, movie information, Cast, Recommendations, Editorial Review, Technical Details, Header, Actions, safe area, or any other frame or Design System component master.

## Why watch

Replace the three gray option-like rows with an open vertical editorial list:

- Keep `Premiada`, `Dirección destacada`, and `Favorita de la audiencia`.
- Use one subtle linked icon per highlight.
- Use a stronger title style and one short supporting line.
- Keep the background transparent or visually minimal.
- Separate highlights with thin subtle rules instead of containers.
- Add one restrained HourTV red micro-accent per item.
- Avoid pills, large gray surfaces, oversized cards, and settings-menu patterns.

## Trailers

Preserve the horizontal carousel and approximately 1.3 visible items:

- Keep each card at a cinematic 16:9 ratio.
- Make artwork the dominant element.
- Place a centered linked play control over the artwork.
- Add a subtle bottom gradient for legible metadata.
- Show the `TRAILER` eyebrow, trailer title, and duration compactly.
- Preserve the 12 px carousel gap and visible next-card preview.

## Component and style strategy

- Reuse existing linked icons, play control, typography styles, color variables, spacing variables, radii, and effects.
- Modify only instance properties and screen-specific Auto Layout composition.
- Do not detach instances, create component masters, add local colors, or add unstyled text.
- Do not modify or extend the Design System.

## QA acceptance criteria

- Only the two approved sections are changed.
- All reusable elements remain linked instances.
- Detached instance count is zero.
- Local solid colors and strokes count is zero.
- Visible text without linked text styles count is zero.
- Auto Layout remains enabled for both sections and their content rows.
- Vertical scrolling and horizontal trailer overflow remain correct.
- Every protected section is unchanged.
