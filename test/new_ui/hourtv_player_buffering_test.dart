import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamtv/models/channel.dart';
import 'package:streamtv/new_ui/hourtv_player_screen.dart';
import 'package:streamtv/new_ui/hourtv_mobile_player_chrome.dart';
import 'package:streamtv/services/ads/ad_config.dart';
import 'package:streamtv/services/storage_service.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'hourtv_player_view_type_test.dart' show MockVideoPlayerPlatform;

class _BufferingPlatform extends MockVideoPlayerPlatform {
  final events = StreamController<VideoEvent>.broadcast();
  int createCalls = 0;
  int playCalls = 0;
  int pauseCalls = 0;
  bool failCreate = false;
  double lastSpeed = 1;
  Duration position = const Duration(seconds: 1);

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    createCalls++;
    if (failCreate) {
      throw StateError('ExoPlaybackException: Source error');
    }
    return super.createWithOptions(options);
  }

  @override
  Future<Duration> getPosition(int textureId) async => position;

  @override
  Future<void> play(int textureId) async => playCalls++;

  @override
  Future<void> pause(int textureId) async => pauseCalls++;

  @override
  Future<void> setPlaybackSpeed(int textureId, double speed) async =>
      lastSpeed = speed;

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
    // Playback UI tests do not exercise the ad SDK. Avoid leaving the fake
    // player behind the production preroll while these tests drive video events.
    AdConfig.current = const AdConfig(
      levelPlay: false,
      levelPlayAppKey: '',
      levelPlayInterstitialId: '',
    );
    originalPlatform = VideoPlayerPlatform.instance;
    platform = _BufferingPlatform();
    VideoPlayerPlatform.instance = platform;
  });

  tearDown(() async {
    await platform.events.close();
    VideoPlayerPlatform.instance = originalPlatform;
    AdConfig.current = AdConfig.defaults;
    debugDefaultTargetPlatformOverride = null;
  });

  Future<void> open(
    WidgetTester tester, {
    bool live = false,
    Channel? channel,
  }) async {
    final currentChannel =
        channel ??
        Channel(
          name: 'Vídeo de prueba',
          url: 'https://example.invalid/video.mp4',
          forcedType: live ? null : 'movie',
        );
    await tester.pumpWidget(
      MaterialApp(
        home: PlayerScreen(
          channel: currentChannel,
          allChannels: [currentChannel],
        ),
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

  testWidgets('native source failure keeps the branded recovery surface', (
    tester,
  ) async {
    platform.failCreate = true;
    await open(tester);
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Conectando…'), findsOneWidget);
    expect(find.textContaining('ExoPlaybackException'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('terminal embed failure stops retrying the same source', (
    tester,
  ) async {
    const resolver = MethodChannel('hourtv/moongetter');
    var resolverCalls = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(resolver, (call) async {
          if (call.method == 'resolve') {
            resolverCalls++;
            return {'status': 'failed', 'retryable': false};
          }
          if (call.method == 'cancel') return null;
          fail('Unexpected method ${call.method}');
        });

    final channel = Channel(
      name: 'Fuente no compatible de prueba',
      url: 'https://unsupported.example.test/#test-video-id',
      forcedType: 'movie',
    );
    await open(tester, channel: channel);
    await tester.pump(const Duration(milliseconds: 50));

    expect(resolverCalls, 1);
    expect(
      find.text('No se pudo iniciar esta fuente. Prueba otro servidor.'),
      findsOneWidget,
    );
    expect(find.text('Conectando…'), findsNothing);
    expect(platform.createCalls, 0);

    await tester.pump(const Duration(minutes: 2));
    expect(resolverCalls, 1);
    expect(platform.createCalls, 0);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(resolver, null);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('transient embed network failure stays in loading and retries', (
    tester,
  ) async {
    const resolver = MethodChannel('hourtv/moongetter');
    var resolverCalls = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(resolver, (call) async {
          if (call.method == 'resolve') {
            resolverCalls++;
            return {'status': 'failed', 'retryable': true};
          }
          if (call.method == 'cancel') return null;
          fail('Unexpected method ${call.method}');
        });

    final channel = Channel(
      name: 'Fuente temporal de prueba',
      url: 'https://unsupported.example.test/#temporary-video-id',
      forcedType: 'movie',
    );
    await open(tester, channel: channel);

    expect(resolverCalls, 1);
    expect(find.text('Conectando…'), findsOneWidget);
    expect(find.textContaining('No se pudo iniciar'), findsNothing);
    expect(platform.createCalls, 0);

    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(resolverCalls, 2);
    expect(find.text('Conectando…'), findsOneWidget);
    expect(find.textContaining('No se pudo iniciar'), findsNothing);
    expect(platform.createCalls, 0);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(resolver, null);
    debugDefaultTargetPlatformOverride = null;
  });

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
    // The controls now remain mounted until the smooth 320 ms fade completes.
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
    await tester.pump(const Duration(milliseconds: 350));
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

  for (final byTap in [true, false]) {
    testWidgets(
      'screen fades all chrome together on ${byTap ? 'tap' : 'timeout'} without restarting video',
      (tester) async {
        await open(tester);
        await tester.pump(const Duration(seconds: 2));
        final creates = platform.createCalls;
        final pauses = platform.pauseCalls;
        if (byTap) {
          await tester.tapAt(const Offset(20, 300));
          await tester.pump(const Duration(milliseconds: 350));
        } else {
          await tester.pump(const Duration(seconds: 5));
        }
        await tester.pump(const Duration(milliseconds: 160));
        expect(
          tester
              .widget<HourTvPlayerScrim>(find.byType(HourTvPlayerScrim))
              .visible,
          isFalse,
        );
        final opacities = tester
            .widgetList<FadeTransition>(
              find.descendant(
                of: find.byType(PlayerChromeVisibility),
                matching: find.byType(FadeTransition),
              ),
            )
            .map((fade) => fade.opacity.value)
            .toList();
        expect(opacities.length, 4); // Scrim, header, center and footer.
        for (final opacity in opacities) {
          expect(opacity, closeTo(.5, .05));
        }
        await tester.pump(const Duration(milliseconds: 360));
        expect(find.byTooltip('Retroceder 10 segundos'), findsNothing);
        expect(find.byTooltip('Ajustes'), findsNothing);
        expect(platform.createCalls, creates);
        expect(platform.pauseCalls, pauses);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        debugDefaultTargetPlatformOverride = null;
      },
    );
  }

  testWidgets('startup with no playback progress advances to the next mirror', (
    tester,
  ) async {
    platform.position = Duration.zero;
    final channel = Channel(
      name: 'Vídeo de prueba',
      url: 'https://example.invalid/video.mp4',
      forcedType: 'movie',
      servers: const [
        ChannelServer(
          name: 'Mirror 2',
          url: 'https://mirror.invalid/video.mp4',
        ),
      ],
    );

    await open(tester, channel: channel);
    expect(platform.createCalls, 1);
    expect(find.text('Conectando…'), findsOneWidget);

    // The platform reports initialized/playing but never moves position. The
    // watchdog must switch mirrors without exposing a provider error screen.
    await tester.pump(const Duration(seconds: 10));
    await tester.pump(const Duration(milliseconds: 100));

    expect(platform.createCalls, 2);
    expect(find.text('Conectando…'), findsOneWidget);
    expect(find.textContaining('ExoPlaybackException'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    // Native disposal is queued behind any previous controller teardown. Drain
    // both queues before the fake clock checks for video_player's timers.
    for (var i = 0; i < 5; i++) {
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    }
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('handoff waits for playback progress, not initialization', (
    tester,
  ) async {
    platform.position = Duration.zero;
    await open(tester);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Conectando…'), findsOneWidget);
    expect(find.text('Conectado'), findsNothing);
    await buffering(tester, true);
    platform.position = const Duration(seconds: 1);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Conectando…'), findsOneWidget);
    await buffering(tester, false);
    expect(find.text('Conectado'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    final handoffFade = tester.widget<AnimatedOpacity>(
      find.byKey(const ValueKey('hourtv-server-handoff-fade')),
    );
    expect(handoffFade.opacity, 0);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets(
    'modern speed control updates native playback without resolving again',
    (tester) async {
      await open(tester);
      await tester.tap(find.byTooltip('Velocidad'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('1.5×'));
      await tester.pumpAndSettle();
      expect(platform.lastSpeed, 1.5);
      expect(platform.createCalls, 1);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      debugDefaultTargetPlatformOverride = null;
    },
  );

  testWidgets('modern options save to Mi lista without restarting playback', (
    tester,
  ) async {
    final channel = Channel(
      name: 'Película de prueba',
      url: 'https://example.invalid/video.mp4',
      forcedType: 'movie',
    );
    await open(tester, channel: channel);
    await tester.tap(find.byTooltip('Ajustes'));
    await tester.pumpAndSettle();
    expect(find.text('Guardar en Mi lista'), findsOneWidget);
    await tester.tap(find.text('Guardar en Mi lista'));
    await tester.pumpAndSettle();
    expect(channel.isFavorite, isTrue);
    expect(platform.createCalls, 1);
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
