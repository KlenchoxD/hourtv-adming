# HourTV Android Figma Sync — Design Specification

## Objective

Make every Android screen in the Figma file `IaWx1xwIbGXjxE979aRmC0` visually match the active Google AI Studio prototype while leaving AI Studio unchanged.

## Source of truth

- Visual and content truth: active HourTV AI Studio preview.
- Design-system truth: local HourTV variables and Inter text styles in Figma.
- Existing top-level screen frame IDs, names, placement, and prototype links are preserved.

## Structural model

- Portrait viewport: 412 × 915.
- Landscape player: 915 × 412.
- Every portrait screen is split into status/safe area, optional screen header, clipped vertical scroll viewport, and fixed bottom navigation when the prototype shows it.
- Related children use Auto Layout. Absolute positioning is limited to artwork overlays and player HUD elements.
- Horizontal media rails clip at the viewport edge and remain structurally scrollable.
- Bottom navigation never participates in the scrolling body.

## Reuse model

- Reuse existing HourTV variables, text styles, and compatible local components.
- Normalize repeated controls into HourTV components only when the existing component API cannot represent the prototype.
- Material 3 library assets are not used for visual components because their token and visual model conflicts with HourTV; editable SVG icons may be used only when consistent with the prototype.

## Screen scope

1. Access / Login
2. Profiles / Choose
3. Profiles / Manage
4. Home
5. Search / Discover
6. Originals
7. Library / Populated
8. Details / Movie
9. Details / Series
10. Live TV
11. Player / Landscape
12. Profile
13. Profile / Update Modal
14. System States / QA

## Quality rules

- No detached instances.
- No local solid colors where an HourTV variable exists.
- No unstyled text.
- Inter only.
- No clipped labels, accidental overlaps, or off-screen controls.
- Touch targets are at least 44 px, preferably 48 px for primary actions.
- No hidden duplicate screens or recovery layers remain after final QA.
- AI Studio is never edited by this work.

## Validation

Each screen is validated structurally and visually before continuing. Final QA checks the 412 px frame plus responsive behavior represented at 360, 393, 428, and 480 px widths.
