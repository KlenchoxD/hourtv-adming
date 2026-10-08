import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamtv/models/channel.dart';
import 'package:streamtv/new_ui/hourtv_player_screen.dart';
import 'package:streamtv/services/storage_service.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'hourtv_player_view_type_test.dart' show MockVideoPlayerPlatform;

class _BufferingPlatform extends MockVideoPlayerPlatform {
  final events = StreamController<VideoEvent>.broadcast();
  int playCalls = 0;
  int pauseCalls = 0;

  @override
  Future<void> play(int textureId) async => playCalls++;

  @override
  Future<void> pause(int textureId) async => pauseCalls++;

  @override
  Stream<VideoEvent> videoEventsFor(int textureId) => Stream.multi((sink) {
    sink.add(
      VideoEvent(
        eventType: VideoEventType.initialized,
        duration: const Duration(minutes: 20),
        size: const Size(1280, 720),
      ),
    );
    final subscription = events.stream.listen(sink.add);
    sink.onCancel = subscription.cancel;
  });
}

void main() {
  late _BufferingPlatform platform;
  late VideoPlayerPlatform originalPlatform;

  setUp(() async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    await StorageService.saveSetting('autoPlay', true);
    originalPlatform = VideoPlayerPlatform.instance;
    platform = _BufferingPlatform();
    VideoPlayerPlatform.instance = platform;
  });

  tearDown(() async {
    await platform.events.close();
    VideoPlayerPlatform.instance = originalPlatform;
    debugDefaultTargetPlatformOverride = null;
  });

  Future<void> open(WidgetTester tester, {bool live = false}) async {
    final channel = Channel(
      name: 'Vídeo de prueba',
      url: 'https://example.invalid/video.mp4',
      forcedType: live ? null : 'movie',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: PlayerScreen(channel: channel, allChannels: [channel]),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  Future<void> buffering(WidgetTester tester, bool active) async {
    platform.events.add(
      VideoEvent(
        eventType: active
            ? VideoEventType.bufferingStart
            : VideoEventType.bufferingEnd,
      ),
    );
    await tester.pump();
    await tester.pump(); // Stream event -> controller listener -> next frame.
  }

  testWidgets('native loading leaves playback running and chrome optional', (
    tester,
  ) async {
    await open(tester);
    expect(find.byTooltip('Pausar'), findsOneWidget);
    final plays = platform.playCalls;
    final pauses = platform.pauseCalls;

    // User hides chrome. A buffering event must not show or restart it.
    await tester.tapAt(const Offset(20, 300));
    // The real screen also recognizes double-tap seek; a single tap waits.
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.byTooltip('Retroceder 10 segundos'), findsNothing);
    await buffering(tester, true);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byTooltip('Pausar'), findsNothing);
    expect(find.byTooltip('Retroceder 10 segundos'), findsNothing);
    expect(platform.playCalls, plays);
    expect(platform.pauseCalls, pauses);

    // Touch on the loader reaches the screen and shows optional controls.
    await tester.tapAt(
      tester.getCenter(find.byType(CircularProgressIndicator)),
    );
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.byTooltip('Retroceder 10 segundos'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byTooltip('Pausar'), findsNothing);
    expect(platform.pauseCalls, pauses);

    // Existing five-second auto-hide still runs while buffering.
    await tester.pump(const Duration(seconds: 6));
    expect(find.byTooltip('Retroceder 10 segundos'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await buffering(tester, false);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byTooltip('Pausar'), findsNothing);
    expect(platform.playCalls, plays);
    expect(platform.pauseCalls, pauses);

    await tester.tapAt(const Offset(20, 300));
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.byTooltip('Pausar'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('live buffering never introduces pause or seek controls', (
    tester,
  ) async {
    await open(tester, live: true);
    final pauses = platform.pauseCalls;
    await buffering(tester, true);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byTooltip('Pausar'), findsNothing);
    expect(find.byTooltip('Retroceder 10 segundos'), findsNothing);
    expect(find.byTooltip('Adelantar 10 segundos'), findsNothing);
    await buffering(tester, false);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(platform.pauseCalls, pauses);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    debugDefaultTargetPlatformOverride = null;
  });
}
