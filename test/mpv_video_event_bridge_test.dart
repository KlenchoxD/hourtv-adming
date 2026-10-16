import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamtv/services/mpv_video_event_bridge.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

void main() {
  test(
    'initialization errors arrive even before metadata or a listener',
    () async {
      final bridge = MpvVideoEventBridge(isLive: false);
      bridge.reportError('Failed to open source');
      final error = Completer<Object>();
      final subscription = bridge.stream.listen(
        (_) {},
        onError: error.complete,
      );
      expect(await error.future, isA<PlatformException>());
      await subscription.cancel();
      await bridge.dispose();
    },
  );

  test(
    'VOD waits for dimensions and duration and initializes exactly once',
    () async {
      final bridge = MpvVideoEventBridge(isLive: false);
      final events = <VideoEvent>[];
      final subscription = bridge.stream.listen(events.add);
      bridge.notifyMetadata(duration: Duration.zero, width: 1920, height: 1080);
      await Future<void>.delayed(Duration.zero);
      expect(events, isEmpty);
      bridge.notifyMetadata(
        duration: const Duration(minutes: 24),
        width: 1920,
        height: 1080,
      );
      bridge.notifyMetadata(
        duration: const Duration(minutes: 24),
        width: 1920,
        height: 1080,
      );
      await Future<void>.delayed(Duration.zero);
      expect(events, hasLength(1));
      expect(events.single.eventType, VideoEventType.initialized);
      expect(events.single.size?.aspectRatio, closeTo(16 / 9, .001));
      await subscription.cancel();
      await bridge.dispose();
    },
  );

  test('live sources initialize without a finite duration', () async {
    final bridge = MpvVideoEventBridge(isLive: true);
    final initialized = bridge.stream.first;
    bridge.notifyMetadata(duration: Duration.zero, width: 1280, height: 720);
    expect((await initialized).eventType, VideoEventType.initialized);
    await bridge.dispose();
  });

  test(
    'audio-only metadata is explicit rather than a transient track list',
    () async {
      final bridge = MpvVideoEventBridge(isLive: false);
      final initialized = bridge.stream.first;
      bridge.notifyMetadata(
        duration: const Duration(minutes: 5),
        audioOnly: true,
      );
      expect((await initialized).size, Size.zero);
      await bridge.dispose();
    },
  );

  test('disposed event bridges ignore late native events', () async {
    final bridge = MpvVideoEventBridge(isLive: true);
    await bridge.dispose();
    bridge.reportError('Late failure');
    bridge.notifyMetadata(duration: Duration.zero, width: 1280, height: 720);
    bridge.emit(VideoEvent(eventType: VideoEventType.completed));
  });
}
