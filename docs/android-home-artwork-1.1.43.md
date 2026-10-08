# Android 1.1.43 — Home artwork and legibility

## User stories

- A partially watched anime/series uses its original series poster on Home,
  while tapping it still resumes the original episode at its stored progress.
- Hero and card images keep their intrinsic proportions on a cold first load,
  warm cache and a new in-memory image-cache session.
- Native poster titles and header search/profile controls are more visible.

## Implementation

`ContinueWatchingEntry` separates display artwork from the playable Channel.
The existing series-resolution pass supplies its cover without mutating the
episode thumbnail, saved history, servers, identifiers or progress. The legacy
`continueWatching` getter still returns the same playable Channel instances.
Missing series artwork falls back to the existing episode image.

`hourTvArtworkProvider` wraps the cached-network or asset provider with
`ResizeImagePolicy.fit`, respecting the memory-size budget without deforming
the original. `HourTvArtwork` uses that one provider for both the ready image
and the hero-ready callback. Previously the native cached widget resized both
dimensions exactly, while the hero custom image builder returned the original
unbounded provider, causing inconsistent decode paths.

The policy distinction is documented in Flutter's primary API reference:
https://api.flutter.dev/flutter/painting/ResizeImagePolicy.html

Native poster titles are 14 logical pixels with weight 700 (previously 12/600).
The web title style is unchanged. Search and profile use 48-by-48 logical touch
targets, matching the existing minimum-touch token. Search has a white 28px
glyph, and the larger avatar has a subtle circular surface and outline.

## Evidence and limitations

The pixel-decoding regression reproduces the old exact resize of a 600x300
image to 120x178, then confirms the new provider decodes it to 120x60. Tests
also verify portrait art in hero bounds, no unnecessary upscaling, cold/warm/
restarted-cache equality, actual Home poster override and original-episode tap,
fallbacks, title size/weight, and header callbacks/48px geometry at 320px width.
Existing hero, progressive Home, placeholder geometry, continue-watching and
player-buffering tests are retained.

The focused regression suite passes all 40 tests without skips.

No device data is cleared to simulate a fresh install. Image-cache tests run
in the isolated Flutter test process; a tester's exact original first-install
screen cannot be retrospectively reconstructed without its capture/logs.
