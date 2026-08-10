# HourTV — Android Details Freeform Editability

## Objective

Convert the current `Android - Detalles` frame into a fully freeform and directly editable composition. Preserve its visible appearance at the moment of conversion while removing structural restrictions that cause layers to snap back into Auto Layout positions.

## Scope

Modify only the current `Android - Detalles` frame and its descendants.

Do not modify:

- `Android - Inicio / V2`
- `Android - Inicio / Backup`
- `🎨 HourTV Design System`
- Approved reference image
- Any other page or top-level frame

## Freeform conversion

- Unlock `Android - Detalles` and every descendant layer.
- Detach every component instance inside the frame, including nested instances.
- Convert Auto Layout containers inside the frame to freeform frames while preserving the current absolute position and dimensions of their children.
- Preserve all text layers, vector layers, images, fills, strokes, effects, and current visual hierarchy.
- Do not flatten, outline, rasterize, merge, or delete editable layers.
- Preserve clear layer names and existing layer nesting where it does not restrict movement.
- Keep every child movable and resizable through direct manipulation.
- Leave the final frame and every descendant unlocked.

## Expected trade-offs

The converted frame will no longer receive updates from Design System components. Responsive Auto Layout behavior, component overrides, and instance linkage will be removed from this frame. The Design System itself remains unchanged and available for future structured designs.

## Visual preservation

Before removing layout and instance constraints, capture the current bounds and ordering of all descendants. After conversion, restore those bounds so the frame looks visually equivalent to its pre-conversion state.

The current frame size, scrolling setup, clipping behavior, artwork crops, typography, and visible spacing must remain unchanged unless required solely to preserve the same rendered appearance.

## QA acceptance criteria

- Only `Android - Detalles` changes.
- Locked layer count inside the frame is zero.
- Component instance count inside the frame is zero.
- Auto Layout container count inside the frame is zero.
- Text remains editable and is not rasterized or outlined.
- Vectors and images remain editable and are not flattened.
- Every visible child can be moved without snapping back to a layout position.
- Current visual appearance is preserved after conversion.
- Protected frames and the Design System are unchanged.
