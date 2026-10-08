# Android 1.1.41 — published anime visibility

## Fixed boundaries

- Admin JSON `series[].categories` now survives the shared series-card projection.
- The mobile Anime filter receives the original categories rather than a replacement containing only the genre text.
- Home genre rows include structured series as title cards, alongside movies and flat series. Episodes and live channels are not inserted into these rows.
- Genre-row caches invalidate when structured series or the parental/profile filter mode change.
- Search and Home use the same projection and series identity; existing detail resolution remains compatible.

## Verification

The targeted catalog, search, parental-control, playback fallback and update-download suite passed 33 tests. A second suite covering the new regressions, series detail and episode virtualization passed 23 tests (49 distinct tests across both runs). Static analysis of all four changed Dart files reported no issues. The optional published-catalog integration test was run with `HOURTV_PUBLISHED_CATALOG_TEST_PATH` pointing to the published catalog snapshot, including its 264 anime series.

The new regression test can run against another published snapshot without changing repository data:

```powershell
$env:HOURTV_PUBLISHED_CATALOG_TEST_PATH='C:/path/to/catalog.json'
flutter test --no-pub test/published_anime_visibility_test.dart
```

## Playback investigation and limitation

The connected moto g24 on 2026-10-07 used hardware AVC decoding at 1280×720 and reported 23.974 fps. SurfaceFlinger samples showed alternating presentation intervals of about 33/50 ms on the 60 Hz display; the device advertised 60/90 Hz modes, neither an integer multiple of that source rate. An initial approximately two-second buffering event was recorded, with no continuing decoder failure established by the bounded observation.

No playback-speed alteration, invented 60-fps interpolation, forced global refresh rate or codec replacement is included in this release. These measurements support a cadence mismatch, but do not establish that every perceived artifact is caused by it. Further playback verification requires the device to be reconnected through ADB; it was disconnected when this update was prepared.

This release does not modify catalog publications, server URLs, episodes, ads or user data.
