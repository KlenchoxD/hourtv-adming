# HourTV Phase 5 — Android Player

## Objective

Create a new landscape playback experience named `Android - Reproductor` using the approved HourTV Cinema HUD direction. The video remains the dominant visual layer; controls appear only as a restrained, premium overlay.

## Protected scope

Do not modify:

- `Android - Inicio / V2`
- `Android - Inicio / Backup`
- `Android - Detalles`
- Approved reference image
- Existing Design System component masters unless a player requirement cannot be satisfied by an existing component

All new frames, components, and layers remain unlocked.

## Frame organization

Create a top-level Figma section named `Android - Reproductor` on the application page. Inside it, create five 917 × 412 px landscape frames:

1. `Player / Controls Visible`
2. `Player / Controls Hidden`
3. `Player / Paused`
4. `Player / Audio & Subtitles`
5. `Player / Next Content`

Use the same cinematic 16:9 video artwork and playback position across states so the state transitions are easy to compare.

## Visual direction

- Use the HourTV dark palette, white text, subtle gray surfaces, and Brand/Primary red.
- Reserve red for played progress, active selections, countdown progress, and primary next-content action.
- Keep the video visible beneath controls and avoid persistent opaque chrome.
- Use top and bottom black gradients only when controls or contextual panels are visible.
- Maintain strong contrast and readability over both light and dark scenes.

## Controls Visible

### Top bar

- Back Icon Button with a 48 px touch target.
- Movie title and optional lightweight context aligned left.
- Compact controls for subtitles, audio, quality/playback, and fullscreen aligned right.
- Use 24 px horizontal safe padding and balanced spacing.

### Central controls

- Symmetrical three-control cluster centered in the viewport.
- `Retroceder 10` and `Adelantar 10` use 56 px touch targets.
- Play/Pause is visually dominant with a 64 px touch target.
- Use dark translucent circular surfaces with subtle borders rather than solid red controls.
- Preserve equal optical spacing around the central control.

### Timeline

- Use a 4 px visual track and a red played segment.
- Use a 12 px scrubber thumb and an invisible touch target of at least 32 px high.
- Place elapsed time on the left and total duration on the right.
- Keep the timeline precise, fine, and visually quiet.

## Controls Hidden

- Show the video only.
- No gradients, title, progress, or controls remain visible.
- Do not add a persistent watermark or decorative overlay.

## Paused

- Use the same structure as Controls Visible.
- Show the Play action in the central dominant position.
- Slightly strengthen the lower gradient and title readability.
- Keep the pause state cinematic rather than modal.

## Audio & Subtitles

- Keep the video visible.
- Use a compact right-side elevated panel approximately 320–340 px wide.
- Organize content into `Audio`, `Subtítulos`, and `Calidad` groups.
- Use label rows with radio/check indicators and thin separators.
- Use red only for the active language or quality selection.
- Include a clear close action and preserve at least 48 px touch targets.
- Avoid a full-screen settings page or oversized bottom sheet.

## Next Content

- Place a compact recommendation panel in the lower-right safe area.
- Include cinematic thumbnail, eyebrow, title, short metadata, `Reproducir ahora`, and a discreet dismiss action.
- Use a thin red countdown/progress indicator.
- Keep the panel small enough that the final scene remains visible.
- Do not use a full-screen takeover.

## Component strategy

First reuse existing HourTV components and foundations:

- Icon Button
- Primary Button
- Secondary or Ghost Button
- Existing line icons where available
- HourTV color, spacing, radius, and typography variables/styles
- Existing shadow and subtle-border effects

If no reusable player component exists, create new component sets in `🎨 HourTV Design System`:

- `Player / Central Control`
- `Player / Timeline`
- `Player / Settings Row`
- `Player / Audio & Subtitles Panel`
- `Player / Next Content`

Use Auto Layout, variants, component properties, clear layer names, and existing HourTV variables. Do not duplicate existing components.

## Interaction and touch targets

- Primary touch targets: 48 px minimum.
- Central Play/Pause: 64 px.
- Skip controls: 56 px.
- Timeline interaction target: at least 32 px high.
- Maintain safe padding around device edges and avoid control collisions in landscape.

## QA acceptance criteria

- Five required states exist inside `Android - Reproductor`.
- Landscape frame size is 917 × 412 px for every state.
- Detached instance count is zero.
- Local solid colors and strokes count is zero.
- Visible text without linked text styles count is zero.
- Every visible text layer uses Inter.
- New components use HourTV variables, Auto Layout, useful variants, and clear names.
- All application-state instances remain linked to the Design System.
- Touch targets meet the defined minimums.
- Controls Hidden contains no visible control overlay.
- Gradients appear only in states where controls or panels are visible.
- Approved screens and reference image remain unchanged.
- Every new frame and layer is unlocked.
