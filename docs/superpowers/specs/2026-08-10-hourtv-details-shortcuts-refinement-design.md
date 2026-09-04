# HourTV — Details Shortcuts Refinement

> **Status: superseded for implementation.** The current HourTV Figma file and
> its `Doc / No-Download Rule` are the source of truth. HourTV does not provide
> downloadable or offline media. This document is retained only to preserve the
> approved visual rationale for the remaining share shortcut.

## Objective

Refine only `Actions / Shortcuts` inside the current `Android - Detalles` frame
so the remaining `Compartir` action feels compact, balanced, and premium.

## Protected scope

Do not modify `Actions / Primary`, the Hero, Synopsis, movie information, Why Watch, Trailers, Cast, Recommendations, Editorial Review, Technical Details, other frames, or the Design System.

## Approved composition

- Keep the visible action `Compartir`.
- Add a subtle 18–20 px share line icon before the label.
- Arrange the action horizontally as icon + label.
- Center the action within the available content width.
- Use approximately 8 px between the icon and its label.
- Preserve an accessible minimum touch height without adding a visible container.
- Keep the background transparent.
- Do not use pills, cards, heavy borders, dividers, or filled button backgrounds.

## Styling

- Use existing HourTV text styles and color variables.
- Keep labels in primary or secondary white with clear readability.
- Keep icon stroke weight consistent with the existing interface.
- Preserve the visual hierarchy below the primary CTA row.

## Editability

- Leave `Android - Detalles`, `Actions / Shortcuts`, and every edited descendant unlocked.
- Keep text and vectors directly editable.
- Do not flatten, rasterize, outline, or merge the icons and labels.

## QA acceptance criteria

- Only `Actions / Shortcuts` changes.
- The share action is visually centered as one compact group.
- Icon-to-label spacing is approximately 8 px.
- No downloadable-media or offline-media action is introduced.
- No visible container or divider is introduced.
- Text and icons remain editable.
- Locked edited-layer count is zero.
- No other section changes.
