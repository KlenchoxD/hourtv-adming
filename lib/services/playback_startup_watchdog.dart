import 'dart:async';

/// One-shot guard for a native player that initializes but never starts moving.
/// The caller owns the playback policy; this class only gates a delayed callback
/// against current state and supports cancellation on source changes/dispose.
class PlaybackStartupWatchdog {
  Timer? _timer;
  int _generation = 0;

  void arm({
    required Duration timeout,
    required bool Function() shouldFallback,
    required void Function() onTimeout,
  }) {
    cancel();
    final generation = ++_generation;
    _timer = Timer(timeout, () {
      if (generation != _generation) return;
      _timer = null;
      if (shouldFallback()) onTimeout();
    });
  }

  void cancel() {
    _generation++;
    _timer?.cancel();
    _timer = null;
  }

  void dispose() => cancel();
}
