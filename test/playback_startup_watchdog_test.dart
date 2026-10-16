import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:streamtv/services/playback_startup_watchdog.dart';

void main() {
  group('PlaybackStartupWatchdog', () {
    test(
      'calls back after the deadline only while fallback is still needed',
      () async {
        final watchdog = PlaybackStartupWatchdog();
        var fallbackNeeded = true;
        var called = false;
        final completed = Completer<void>();

        watchdog.arm(
          timeout: const Duration(milliseconds: 20),
          shouldFallback: () => fallbackNeeded,
          onTimeout: () {
            called = true;
            completed.complete();
          },
        );

        await completed.future.timeout(const Duration(seconds: 1));

        expect(called, isTrue);
        watchdog.dispose();
      },
    );

    test(
      'does not fallback if playback recovers before the deadline',
      () async {
        final watchdog = PlaybackStartupWatchdog();
        var fallbackNeeded = true;
        var called = false;

        watchdog.arm(
          timeout: const Duration(milliseconds: 30),
          shouldFallback: () => fallbackNeeded,
          onTimeout: () => called = true,
        );
        await Future<void>.delayed(const Duration(milliseconds: 5));
        fallbackNeeded = false;
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(called, isFalse);
        watchdog.dispose();
      },
    );

    test(
      'cancels stale callbacks when a new source replaces the old one',
      () async {
        final watchdog = PlaybackStartupWatchdog();
        var oldSourceCalled = false;
        var newSourceCalled = false;
        final completed = Completer<void>();

        watchdog.arm(
          timeout: const Duration(milliseconds: 20),
          shouldFallback: () => true,
          onTimeout: () => oldSourceCalled = true,
        );
        await Future<void>.delayed(const Duration(milliseconds: 5));
        watchdog.arm(
          timeout: const Duration(milliseconds: 20),
          shouldFallback: () => true,
          onTimeout: () {
            newSourceCalled = true;
            completed.complete();
          },
        );
        await completed.future.timeout(const Duration(seconds: 1));

        expect(oldSourceCalled, isFalse);
        expect(newSourceCalled, isTrue);
        watchdog.dispose();
      },
    );
  });
}
