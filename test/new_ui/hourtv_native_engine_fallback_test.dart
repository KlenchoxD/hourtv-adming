import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamtv/models/channel.dart';
import 'package:streamtv/new_ui/hourtv_player_screen.dart';
import 'package:streamtv/services/playback_engine_platform_router.dart';
import 'package:streamtv/services/playback_progress.dart';
import 'package:streamtv/services/storage_service.dart';
import 'package:streamtv/services/embed_resolver.dart';
import 'package:streamtv/services/ads/ad_config.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:video_player/video_player.dart';

import 'hourtv_player_view_type_test.dart' show MockVideoPlayerPlatform;

class _Engine extends MockVideoPlayerPlatform {
  _Engine({
    this.error,
    this.failOnCreate = false,
    this.teardownGate,
    this.playGate,
  });
  final String? error;
  final bool failOnCreate;
  final Completer<void>? teardownGate;
  final Completer<void>? playGate;
  final sources = <DataSource>[];
  final seeks = <Duration>[];
  int disposed = 0;
  int plays = 0;
  int cancellations = 0;
  MultiStreamController<VideoEvent>? eventSink;

  void failDuringPlayback(String message) => eventSink!.addError(
    PlatformException(code: 'VideoError', message: message),
  );

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    sources.add(options.dataSource);
    if (failOnCreate) {
      throw PlatformException(code: 'VideoError', message: error);
    }
    return 7;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => Stream.multi((sink) {
    eventSink = sink;
    sink.onCancel = () {
      cancellations++;
    };
    if (error == null) {
      sink.add(
        VideoEvent(
          eventType: VideoEventType.initialized,
          duration: const Duration(minutes: 20),
          size: const Size(1920, 1080),
        ),
      );
    } else {
      sink.addError(PlatformException(code: 'VideoError', message: error));
    }
  });

  @override
  Future<void> seekTo(int playerId, Duration position) async =>
      seeks.add(position);

  @override
  Future<void> dispose(int playerId) async {
    await teardownGate?.future;
    disposed++;
  }

  @override
  Future<void> play(int playerId) async {
    plays++;
    await playGate?.future;
  }
}

void main() {
  late VideoPlayerPlatform original;
  setUp(() async {
    original = VideoPlayerPlatform.instance;
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    AdConfig.current = const AdConfig(
      levelPlay: false,
      levelPlayAppKey: '',
      levelPlayInterstitialId: '',
    );
  });

  tearDown(() {
    VideoPlayerPlatform.instance = original;
    debugDefaultTargetPlatformOverride = null;
    AdConfig.current = AdConfig.defaults;
  });

  Future<void> closeScreen(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    // dispose() persists progress without blocking the UI. Drain both queues
    // before the next fake clock is created, or the static write chain retains
    // a continuation in a fake-async zone that is no longer pumped.
    for (var i = 0; i < 5; i++) {
      await tester.pump();
      await tester.runAsync(() async {
        await Future<void>.delayed(Duration.zero);
      });
    }
    debugDefaultTargetPlatformOverride = null;
  }

  testWidgets(
    'local HLS lease survives engine fallback and closes after native teardown',
    (tester) async {
      final media3 = _Engine(error: 'UnrecognizedInputFormatException');
      final mpv = _Engine();
      VideoPlayerPlatform.instance = PlaybackEnginePlatformRouter.forTesting(
        media3: media3,
        mpv: mpv,
      );
      await PlaybackEnginePlatformRouter.installForAndroid();
      var resolutions = 0;
      var released = false;
      final channel = Channel(
        name: 'Webflux session',
        url: 'https://webflux.vip/#fixture',
        forcedType: 'movie',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: PlayerScreen(
            channel: channel,
            allChannels: [channel],
            resolveEmbed: (_, request) async {
              resolutions++;
              return EmbedResolution(
                stream: ResolvedStream(
                  'http://127.0.0.1:9999/session/stream.m3u8',
                  const {},
                  formatHint: VideoFormat.hls,
                  release: () async {
                    expect(
                      mpv.disposed,
                      1,
                      reason:
                          'The decoder must stop before the HLS proxy closes.',
                    );
                    released = true;
                  },
                ),
              );
            },
          ),
        ),
      );
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      }
      expect(resolutions, 1);
      expect(
        media3.sources.single.uri,
        'http://127.0.0.1:9999/session/stream.m3u8',
      );
      expect(mpv.sources.single.uri, media3.sources.single.uri);
      expect(released, isFalse);
      await closeScreen(tester);
      expect(released, isTrue);
    },
  );

  testWidgets(
    'closing during engine transition waits for outstanding native teardown',
    (tester) async {
      final gate = Completer<void>();
      final media3 = _Engine(
        error: 'UnrecognizedInputFormatException',
        teardownGate: gate,
      );
      final mpv = _Engine();
      VideoPlayerPlatform.instance = PlaybackEnginePlatformRouter.forTesting(
        media3: media3,
        mpv: mpv,
      );
      await PlaybackEnginePlatformRouter.installForAndroid();
      var released = false;
      final channel = Channel(
        name: 'Closing session',
        url: 'https://webflux.vip/#fixture',
        forcedType: 'movie',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: PlayerScreen(
            channel: channel,
            allChannels: [channel],
            resolveEmbed: (_, request) async => EmbedResolution(
              stream: ResolvedStream(
                'http://127.0.0.1:9999/session/stream.m3u8',
                const {},
                formatHint: VideoFormat.hls,
                release: () async {
                  released = true;
                },
              ),
            ),
          ),
        ),
      );
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      }
      expect(media3.sources, hasLength(1));
      expect(mpv.sources, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(
        released,
        isFalse,
        reason: 'The earlier native decoder still owns the HLS proxy.',
      );
      gate.complete();
      for (var i = 0; i < 5; i++) {
        await tester.pump();
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      }
      expect(media3.disposed, 1);
      expect(released, isTrue);
      expect(mpv.sources, isEmpty);
      debugDefaultTargetPlatformOverride = null;
    },
  );

  test('failed controller can be closed without a widget frame', () async {
    final media3 = _Engine(error: 'UnrecognizedInputFormatException');
    final mpv = _Engine();
    VideoPlayerPlatform.instance = PlaybackEnginePlatformRouter.forTesting(
      media3: media3,
      mpv: mpv,
    );
    await PlaybackEnginePlatformRouter.installForAndroid();
    final controller = VideoPlayerController.networkUrl(
      Uri.parse('https://example.invalid/video.mp4'),
    );
    await expectLater(
      controller.initialize(),
      throwsA(isA<PlatformException>()),
    );
    await controller.dispose().timeout(const Duration(seconds: 2));
    expect(media3.disposed, 1);
  });

  testWidgets(
    'closing during autoplay retains the proxy until the pending play call returns',
    (tester) async {
      final gate = Completer<void>();
      final media3 = _Engine(playGate: gate);
      final mpv = _Engine();
      VideoPlayerPlatform.instance = PlaybackEnginePlatformRouter.forTesting(
        media3: media3,
        mpv: mpv,
      );
      await PlaybackEnginePlatformRouter.installForAndroid();
      var released = false;
      final channel = Channel(
        name: 'Autoplay session',
        url: 'https://webflux.vip/#fixture',
        forcedType: 'movie',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: PlayerScreen(
            channel: channel,
            allChannels: [channel],
            resolveEmbed: (_, request) async => EmbedResolution(
              stream: ResolvedStream(
                'http://127.0.0.1:9999/session/stream.m3u8',
                const {},
                formatHint: VideoFormat.hls,
                release: () async {
                  released = true;
                },
              ),
            ),
          ),
        ),
      );
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      }
      expect(media3.plays, 1);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(released, isFalse);
      expect(media3.disposed, 0);
      gate.complete();
      await closeScreen(tester);
      expect(media3.disposed, 1);
      expect(released, isTrue);
    },
  );

  for (final failOnCreate in [false, true]) {
    testWidgets(
      'container failure (during creation: $failOnCreate) reuses the source in mpv and saved progress',
      (tester) async {
        final media3 = _Engine(
          error: 'UnrecognizedInputFormatException',
          failOnCreate: failOnCreate,
        );
        final mpv = _Engine();
        VideoPlayerPlatform.instance = PlaybackEnginePlatformRouter.forTesting(
          media3: media3,
          mpv: mpv,
        );
        await PlaybackEnginePlatformRouter.installForAndroid();
        final channel = Channel(
          name: 'Native test',
          url: 'https://example.invalid/video.mp4',
          forcedType: 'movie',
        );
        // Seed persisted data directly, independently of the write queue being
        // tested by playback_progress_test. Each fixture has its own profile/cache.
        await StorageService.setActiveProfile('native-$failOnCreate');
        await StorageService.saveSetting(
          'playbackPositions.profile.${StorageService.activeProfileId}',
          jsonEncode({
            PlaybackProgress.contentKey(channel): const SavedPosition(
              positionMs: 60000,
              durationMs: 1200000,
              fraction: .05,
            ).toMap(),
          }),
        );
        await tester.pumpWidget(
          MaterialApp(
            home: PlayerScreen(
              channel: channel,
              allChannels: [channel],
              resumePlayback: true,
            ),
          ),
        );
        for (var i = 0; i < 20; i++) {
          await tester.pump(const Duration(milliseconds: 100));
          await tester.runAsync(() async {
            // Event cancellation spans the controller's async-local backend zone.
            // Let its real microtask queue drain as well as the widget clock.
            await Future<void>.delayed(Duration.zero);
          });
        }
        expect(media3.sources, hasLength(1));
        expect(
          media3.cancellations,
          failOnCreate ? 0 : 1,
          reason: 'The failed event stream must be cancelled.',
        );
        expect(
          media3.disposed,
          failOnCreate ? 0 : 1,
          reason: 'The failed native handle must close before starting mpv.',
        );
        expect(mpv.sources, hasLength(1));
        expect(mpv.sources.single.uri, channel.url);
        expect(mpv.seeks, contains(const Duration(minutes: 1)));
        expect(mpv.plays, greaterThan(0));
        expect(
          find.textContaining('UnrecognizedInputFormatException'),
          findsNothing,
        );
        await closeScreen(tester);
      },
    );
  }

  testWidgets(
    'late zero-position tick cannot erase resume during engine recovery',
    (tester) async {
      final media3 = _Engine();
      final mpv = _Engine();
      VideoPlayerPlatform.instance = PlaybackEnginePlatformRouter.forTesting(
        media3: media3,
        mpv: mpv,
      );
      await PlaybackEnginePlatformRouter.installForAndroid();
      final channel = Channel(
        name: 'Resume recovery',
        url: 'https://example.invalid/resume.mp4',
        forcedType: 'movie',
      );
      await StorageService.setActiveProfile('native-late-position');
      await StorageService.saveSetting(
        'playbackPositions.profile.${StorageService.activeProfileId}',
        jsonEncode({
          PlaybackProgress.contentKey(channel): const SavedPosition(
            positionMs: 60000,
            durationMs: 1200000,
            fraction: .05,
          ).toMap(),
        }),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: PlayerScreen(
            channel: channel,
            allChannels: [channel],
            resumePlayback: true,
          ),
        ),
      );
      // The mock keeps reporting zero even after seek, like a late native tick.
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      }
      expect(media3.seeks, contains(const Duration(minutes: 1)));
      expect(media3.plays, greaterThan(0));
      media3.failDuringPlayback('DecoderInitializationException');
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      }
      expect(mpv.sources, hasLength(1));
      expect(mpv.seeks, contains(const Duration(minutes: 1)));
      expect(mpv.plays, greaterThan(0));
      await closeScreen(tester);
    },
  );

  testWidgets(
    'HTTP failure does not reopen the same source in mpv or expose diagnostics',
    (tester) async {
      final media3 = _Engine(
        error: 'HttpDataSourceException: Response code: 403',
      );
      final mpv = _Engine();
      VideoPlayerPlatform.instance = PlaybackEnginePlatformRouter.forTesting(
        media3: media3,
        mpv: mpv,
      );
      await PlaybackEnginePlatformRouter.installForAndroid();
      final channel = Channel(
        name: 'Unavailable source',
        url: 'https://example.invalid/video.mp4',
        forcedType: 'movie',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: PlayerScreen(channel: channel, allChannels: [channel]),
        ),
      );
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        await tester.runAsync(() async {
          await Future<void>.delayed(Duration.zero);
        });
      }
      expect(media3.sources, hasLength(1));
      expect(mpv.sources, isEmpty);
      expect(find.textContaining('HttpDataSourceException'), findsNothing);
      await closeScreen(tester);
    },
  );
}
