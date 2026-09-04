# HourTV Android Figma Sync — Implementation Plan

## Goal

Rebuild the internal structure of the existing Android Figma frames so they match the active AI Studio prototype exactly and remain reusable, editable, and robust.

## Phase A — Shared foundations and components

1. Verify existing HourTV variables and Inter styles.
2. Normalize the mobile status area, app header, bottom navigation, buttons, chips, search field, poster cards, continue-watching cards, episode cards, channel rows, settings rows, and profile tiles.
3. Add only the missing reusable component properties and variants.
4. Validate every changed master before using it in screens.

## Phase B — Entry and profile selection

1. Rebuild Access / Login.
2. Rebuild Profiles / Choose.
3. Rebuild Profiles / Manage.
4. Preserve existing top-level frame IDs and prototype entry points.

## Phase C — Primary navigation screens

1. Validate and finish Home against the live reference.
2. Rebuild Search / Discover.
3. Rebuild Live TV.
4. Rebuild Library / Populated.
5. Rebuild Profile and Profile / Update Modal.

## Phase D — Content screens

1. Rebuild Originals.
2. Rebuild Details / Movie.
3. Rebuild Details / Series.
4. Rebuild Player / Landscape.
5. Rebuild System States / QA.

## Phase E — Global QA and cleanup

1. Check instances, variable bindings, text styles, Auto Layout, scrolling, clipping, safe areas, and touch targets.
2. Compare every screen with the AI Studio reference.
3. Remove obsolete internal layers and temporary recovery content only after successful validation.
4. Leave the primary Home frame selected for final review.
