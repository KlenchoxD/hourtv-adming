# HourTV — Details Shortcuts Refinement

## Objective

Refine only `Actions / Shortcuts` inside the current `Android - Detalles` frame so `Descargar` and `Compartir` feel compact, balanced, and premium instead of appearing as two isolated labels at opposite edges.

## Protected scope

Do not modify `Actions / Primary`, the Hero, Synopsis, movie information, Why Watch, Trailers, Cast, Recommendations, Editorial Review, Technical Details, other frames, or the Design System.

## Approved composition

- Keep the visible actions `Descargar` and `Compartir`.
- Add a subtle 18–20 px line icon before each label.
- Use a download icon for `Descargar` and a share icon for `Compartir`.
- Arrange each action horizontally as icon + label.
- Group both actions at the horizontal center of the available content width.
- Use a compact 28–32 px gap between the two actions.
- Use approximately 8 px between each icon and its label.
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
- Both actions are visually centered as one compact group.
- The gap between actions is 28–32 px.
- Icon-to-label spacing is approximately 8 px.
- No visible container or divider is introduced.
- Text and icons remain editable.
- Locked edited-layer count is zero.
- No other section changes.
