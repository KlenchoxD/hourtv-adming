# HourTV Phase 5 Android Player Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the complete HourTV Cinema HUD Android landscape player with five linked, reusable, QA-verified states.

**Architecture:** Create player-specific component sets only where the existing HourTV Design System has no equivalent, then compose five 917 × 412 application-state frames from linked instances. Place the states in a new `Android - Reproductor` section while preserving every approved frame and reference asset.

**Tech Stack:** Figma variables, styles, components, variants, Auto Layout, Figma Agent inspection and mutation.

## Global Constraints

- Do not modify `Android - Inicio / V2`, `Android - Inicio / Backup`, `Android - Detalles`, or the approved reference image.
- Keep every new frame and layer unlocked.
- Use Inter, HourTV variables, linked text styles, Auto Layout, and clear names.
- Detached instance count must be zero.
- Local solid color and stroke count must be zero.
- Place the five states left-to-right: Controls Visible, Controls Hidden, Paused, Audio & Subtitles, Next Content.
- Leave `Player / Controls Visible` selected when work stops.

---

### Task 1: Inventory and protected baseline

**Figma scope:** Read-only inspection of `🎨 HourTV Design System`, application page top-level frames, and approved assets.

**Produces:** Existing component inventory, protected-node signatures, and a list of genuinely missing player components.

- [ ] **Step 1:** Record names and node identifiers for the four protected application assets.
- [ ] **Step 2:** Inspect existing Button, Icon Button, line icon, typography, color, spacing, radius, border, and effect resources.
- [ ] **Step 3:** Confirm whether player timeline, central controls, settings rows, settings panel, or next-content components already exist.
- [ ] **Step 4:** Record the pre-implementation top-level structure of the Design System so duplicate or accidental changes can be detected.

### Task 2: Player component sets

**Figma scope:** Modify only `🎨 HourTV Design System` and only for missing player primitives.

**Consumes:** Existing-component inventory from Task 1.

**Produces:** Linked player components using HourTV variables, styles, and Auto Layout.

- [ ] **Step 1:** Reuse existing Icon Button and Button components without duplicating them.
- [ ] **Step 2:** Create only missing component sets from `Player / Central Control`, `Player / Timeline`, `Player / Settings Row`, `Player / Audio & Subtitles Panel`, and `Player / Next Content`.
- [ ] **Step 3:** Add state and content properties required by the five application states.
- [ ] **Step 4:** Verify 48 px minimum touch targets, 56 px skip targets, 64 px Play/Pause, and a 32 px timeline interaction area.
- [ ] **Step 5:** Verify all new masters use Auto Layout, HourTV variables, linked text styles, clean names, and remain unlocked.

### Task 3: Controls Visible and Hidden

**Figma scope:** New `Android - Reproductor` section only.

**Consumes:** Player components from Task 2.

**Produces:** `Player / Controls Visible` and `Player / Controls Hidden` at 917 × 412 px.

- [ ] **Step 1:** Create the top-level `Android - Reproductor` section away from approved screens.
- [ ] **Step 2:** Compose Controls Visible with one cinematic video fill, conditional top/bottom gradients, top controls, symmetrical central cluster, title, timeline, elapsed time, and duration.
- [ ] **Step 3:** Compose Controls Hidden from the same video state with no visible gradients, title, timeline, or controls.
- [ ] **Step 4:** Verify both frames are unlocked and contain no detached instances or local styles.

### Task 4: Paused and Audio & Subtitles

**Figma scope:** New `Android - Reproductor` section only.

**Consumes:** Controls Visible composition and settings components.

**Produces:** `Player / Paused` and `Player / Audio & Subtitles` at 917 × 412 px.

- [ ] **Step 1:** Compose Paused from the visible-control system with Play active and a slightly stronger lower gradient.
- [ ] **Step 2:** Compose Audio & Subtitles with the video visible and a compact 320–340 px right-side panel.
- [ ] **Step 3:** Include Audio, Subtítulos, and Calidad groups with active states shown only by restrained red accents.
- [ ] **Step 4:** Verify settings rows and close action meet 48 px touch targets and all layers remain linked and unlocked.

### Task 5: Next Content and comparison layout

**Figma scope:** New `Android - Reproductor` section only.

**Consumes:** Existing Buttons and Player / Next Content.

**Produces:** `Player / Next Content` and final left-to-right state arrangement.

- [ ] **Step 1:** Compose a discreet lower-right next-content recommendation with thumbnail, eyebrow, title, metadata, primary action, dismiss action, and thin countdown progress.
- [ ] **Step 2:** Preserve the final scene outside the compact panel and avoid a full-screen takeover.
- [ ] **Step 3:** Arrange all five frames in the exact required order with 80 px horizontal spacing for comparison.
- [ ] **Step 4:** Confirm every state remains at 917 × 412 px and is unlocked.

### Task 6: Full QA and handoff

**Figma scope:** Read-only verification after implementation, except final selection.

**Produces:** Exact QA report and `Player / Controls Visible` selected.

- [ ] **Step 1:** Count linked instances, detached instances, component masters, local fills/strokes, unstyled text, non-Inter text, locked new layers, and major frames without Auto Layout where applicable.
- [ ] **Step 2:** Validate every touch target and the timeline interaction area against the specified minimums.
- [ ] **Step 3:** Compare protected-node signatures and confirm no approved screen or reference changed.
- [ ] **Step 4:** Visually inspect all five states for order, spacing, landscape dimensions, legibility, content dominance, and overlay behavior.
- [ ] **Step 5:** Select `Player / Controls Visible`, leave Figma open, and stop for visual approval.
