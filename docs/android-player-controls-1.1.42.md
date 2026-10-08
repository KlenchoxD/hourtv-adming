# Android 1.1.42 — independent buffering and optional controls

## User story

While a native Android video buffers, playback remains under the controller's
existing policy. Buffering must not pause/resume it, show the chrome, or reset
the five-second auto-hide timer. The user can still show/hide the chrome by
touching the screen. Exactly one central status is drawn: loading or play/pause.
Live channels must not gain pause or seek buttons.

## Changes

- `HourTvPlaybackCenter` owns the single central status and transport layout.
- The buffering painter has its own 76-by-76 repaint boundary. It no longer
  invalidates the broad layer containing the gradient, subtitles and transport.
- A non-interactive loader lets taps reach the existing chrome gesture handler.
- The screen selects only playing, buffering, initialization and error changes;
  position ticks do not rebuild this component.
- `_VideoSelectorState` initializes its baseline eagerly. Its previous lazy
  initializer could consume the first controller event without rebuilding.
  The integrated regression reproduced this on the first buffering event.
- The screen reads buffering directly from the controller, including live and
  seek/resume states, instead of duplicating it in a separate notifier whose
  updates depended on VOD progress tracking.

## Verification boundaries

The native platform is simulated through `VideoPlayerPlatform`, then real
`VideoEventType.bufferingStart` / `bufferingEnd` events enter the actual
`PlayerScreen`. Tests verify hidden chrome stays hidden, tapping the loader
shows optional controls without pausing, auto-hide works during buffering,
and buffering completion does not force controls to appear.

The isolated component tests also cover paused-state preservation, a single
loading indicator, stable central geometry, explicit transport callbacks and
the small repaint boundary. Live regressions assert there is no pause/seek.

Final targeted suite: **41 tests passed**, including the two native event-flow
regressions, seven isolated central-status tests, live no-pause/manual VOD,
resume behavior, all published anime visibility checks using the real catalog
fixture, live-history exclusion and playback-source fallback.

## Scope and limitations

No source URL, playback speed, codec, Android view type, catalog, ads or stored
user data is changed. The video remains on the established Android platform
view path. This fixes UI state loss and loading/control overlap, and isolates
animation painting. It does not establish that all native main-thread stalls
or network/server buffering are eliminated; that requires a comparable device
playback observation. Before this change, the phone logged repeated buffering
and Choreographer frame skips; cumulative gfxinfo is not a spinner-only metric.
