# HourTV Global Figma Cleanup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove only unambiguous duplicate, obsolete, empty, test, reference, and download-related Figma content while preserving every canonical HourTV platform, feature, state, component link, and handoff artifact.

**Architecture:** Perform a read-only global inventory first, classify every deletion candidate as canonical, clear duplicate/obsolete, or ambiguous, and mutate only the clear category. Re-audit after each cleanup class, normalize canonical names only after duplicates are gone, and finish with an independent recursive QA of screens, components, instances, downloads, naming, and editability.

**Tech Stack:** Current HourTV Figma file, Figma variables/styles/components, Auto Layout, prototype flows, browser-controlled Figma Agent.

## Global Constraints

- Cleanup only; create no product screens or replacement components.
- Cross-platform equivalents and distinct functional states are never duplicates.
- Never delete a component master while active instances still depend on it.
- Preserve repeated UI instances in grids, carousels, menus, guides, cast rows, and results.
- Delete only category B items; preserve category C items and report them.
- HourTV has no download/offline user experience.
- Preserve all canonical Android, Tablet, Desktop, Smart TV / TV Box, Design System, and Handoff content.
- Finish with zero broken or newly detached instances.

---

### Task 1: Global read-only inventory and classification

**Files:**
- Modify: Current HourTV Figma file (read-only during this task)
- Reference: `docs/superpowers/plans/2026-08-11-hourtv-global-figma-cleanup.md`

**Interfaces:**
- Consumes: Current pages, top-level sections/frames, component masters/sets, instances, styles, variables, documentation, prototype flows.
- Produces: Exact canonical inventory plus category A/B/C candidate lists with node IDs and reasons.

- [ ] Enumerate every page and every top-level child with node ID, type, name, dimensions, child count, visibility, lock state, and prototype role.
- [ ] Enumerate every component/component set and count all linked instances by main-component ID across the file.
- [ ] Detect duplicate platform + feature + state roots, obsolete suffixes, empty/test objects, reference-only artwork, download/offline content, and obsolete Smart TV experiments.
- [ ] Classify each candidate as A canonical, B clear duplicate/obsolete, or C ambiguous; confirm every B candidate has a surviving canonical replacement or has no functional/documentation value.
- [ ] Record baseline counts for pages, top-level roots, components, instances, detached instances, locked nodes, download terms, and canonical states.

### Task 2: Remove unambiguous obsolete product clutter

**Files:**
- Modify: Current HourTV Figma file, only category B top-level product/reference/test nodes.

**Interfaces:**
- Consumes: Category B node-ID list from Task 1.
- Produces: One canonical screen per platform + feature + state without removing valid state or platform variants.

- [ ] Delete superseded screen versions only when a verified canonical replacement exists.
- [ ] Delete obsolete backup/version/copy frames and temporary comparison frames.
- [ ] Delete empty frames/sections, unused test rectangles, abandoned experiments, and disconnected reference-only artwork.
- [ ] Delete obsolete user-facing download/offline frames, controls, and documentation while preserving generic playback/loading progress.
- [ ] Delete prior Smart TV experiments superseded by the official 20-screen Smart TV / TV Box section.
- [ ] Recount canonical Android, Tablet, Desktop, and Smart TV inventories and compare them with the baseline.

### Task 3: Safely consolidate duplicate component masters

**Files:**
- Modify: `🎨 HourTV Design System` in the current Figma file only.

**Interfaces:**
- Consumes: Component-family duplicate list and instance dependency map from Task 1.
- Produces: Canonical component families with all active application instances linked.

- [ ] For each functionally duplicate family, select the master with current variables, variants, Auto Layout, and technical QA.
- [ ] Reassign dependent instances to the canonical master only when variant/property mapping is lossless and safe.
- [ ] Verify reassigned instances preserve overrides, dimensions, variants, styles, and prototype behavior.
- [ ] Delete the obsolete master only after its active instance count is exactly zero.
- [ ] Preserve and report any family that cannot be consolidated safely through Figma without breaking instances.

### Task 4: Normalize canonical naming and organization

**Files:**
- Modify: Canonical top-level screen/section names and positions in the current Figma file.

**Interfaces:**
- Consumes: Surviving canonical inventory from Tasks 2–3.
- Produces: Clean platform hierarchy and names without obsolete suffixes.

- [ ] Rename approved surviving screens to clean canonical names after competing versions are removed.
- [ ] Remove obsolete suffixes such as V1, V2, Final, New, Old, Backup, Copy, and Test only where the screen is canonical and unambiguous.
- [ ] Preserve platform/state qualifiers needed to distinguish valid screens.
- [ ] Arrange surviving top-level sections with consistent spacing under Design System, Android, Tablet, Desktop, Smart TV / TV Box, and Handoff organization.
- [ ] Remove unnecessary empty top-level sections after their valid content has been preserved.

### Task 5: Independent post-cleanup acceptance QA

**Files:**
- Inspect: Entire current HourTV Figma file, read-only.

**Interfaces:**
- Consumes: Cleaned Figma file and Task 1 baseline.
- Produces: Final deletion counts, canonical inventory, ambiguity report, and PASS/FAIL verdict.

- [ ] Verify every required feature/state remains, including player states, Skip Intro, Skip Recap, Next Content, search states, library states, Smart TV EPG, and Smart TV seasons/episodes.
- [ ] Verify platforms remain separate and canonical screens remain editable.
- [ ] Verify zero broken component references, zero newly detached instances, and a functional Design System.
- [ ] Verify no user-facing download/offline content remains.
- [ ] Verify no accidental empty application screens or obvious V1/V2/Copy clutter remains.
- [ ] Verify names and page/section organization are consistent.
- [ ] Report exact counts for all 13 requested final-report categories and list every category C item intentionally preserved.

## Self-Review

- Spec coverage: Tasks 1–5 cover duplicate screens, canonical rules, backups, references, components, repeated instances, empty/test objects, downloads, Smart TV, naming, organization, safety classification, QA, and the full final report.
- Placeholder scan: No deferred implementation placeholders remain.
- Consistency: All destructive work consumes the category B node-ID list; category C remains untouched; component deletion requires zero dependent instances.
