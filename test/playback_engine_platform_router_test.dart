import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:streamtv/services/playback_engine_platform_router.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

void main() {
  test('creation failures become disposable error handles', () async {
    final media3 = _FakeVideoPlayerPlatform(
      id: 7,
      creationError: PlatformException(
        code: 'VideoError',
        message: 'DecoderInitializationException',
      ),
    );
    final router = PlaybackEnginePlatformRouter.forTesting(
      media3: media3,
      mpv: _FakeVideoPlayerPlatform(id: 7),
    );
    final id = await router.createWithOptions(
      VideoCreationOptions(
        dataSource: DataSource(
          sourceType: DataSourceType.network,
          uri: 'https://cdn.example/video.mp4',
        ),
        viewType: VideoViewType.textureView,
      ),
    );
    expect(id, isNotNull);
    await expectLater(
      router.videoEventsFor(id!).first,
      throwsA(isA<PlatformException>()),
    );
    await router.dispose(id);
    expect(media3.disposedIds, isEmpty);
  });

  test(
    'timed-out native creation releases a handle that arrives late',
    () async {
      final pending = Completer<int?>();
      final media3 = _FakeVideoPlayerPlatform(
        id: 7,
        pendingCreation: pending.future,
      );
      final router = PlaybackEnginePlatformRouter.forTesting(
        media3: media3,
        mpv: _FakeVideoPlayerPlatform(id: 7),
        creationTimeout: const Duration(milliseconds: 1),
      );
      final id = await router.createWithOptions(
        VideoCreationOptions(
          dataSource: DataSource(
            sourceType: DataSourceType.network,
            uri: 'https://cdn.example/video.mp4',
          ),
          viewType: VideoViewType.textureView,
        ),
      );
      await expectLater(
        router.videoEventsFor(id!).first,
        throwsA(isA<PlatformException>()),
      );
      await router.dispose(id);
      pending.complete(7);
      await Future<void>.delayed(Duration.zero);
      expect(media3.disposedIds, [7]);
    },
  );
  test(
    'routes each VideoPlayerController id to its selected native engine',
    () async {
      final media3 = _FakeVideoPlayerPlatform(id: 7);
      final mpv = _FakeVideoPlayerPlatform(id: 7);
      final router = PlaybackEnginePlatformRouter.forTesting(
        media3: media3,
        mpv: mpv,
      );
      final options = VideoCreationOptions(
        dataSource: DataSource(
          sourceType: DataSourceType.network,
          uri: 'https://cdn.example/episode.m3u8',
          httpHeaders: {'Referer': 'https://source.example/watch'},
        ),
        viewType: VideoViewType.textureView,
      );

      final creations = await Future.wait([
        router.runWithBackend(PlaybackEngineBackend.media3, () async {
          await Future<void>.delayed(Duration.zero);
          return router.createWithOptions(options);
        }),
        router.runWithBackend(PlaybackEngineBackend.mpv, () async {
          await Future<void>.delayed(Duration.zero);
          return router.createWithOptions(options);
        }),
      ]);
      final media3Id = creations[0];
      final mpvId = creations[1];

      expect(media3Id, isNotNull);
      expect(mpvId, isNotNull);
      expect(mpvId, isNot(media3Id));
      expect(
        mpv.lastOptions?.dataSource.httpHeaders,
        options.dataSource.httpHeaders,
      );

      await router.setVolume(media3Id!, 0.25);
      await router.setVolume(mpvId!, 0.75);
      expect(media3.lastVolumeCall, (7, 0.25));
      expect(mpv.lastVolumeCall, (7, 0.75));

      await router.dispose(media3Id);
      await router.dispose(mpvId);
      expect(media3.disposedIds, [7]);
      expect(mpv.disposedIds, [7]);
      expect(() => router.play(media3Id), throwsStateError);
      expect(() => router.play(mpvId), throwsStateError);
    },
  );

  test('initializes both engines before a new mpv session can race init', () async {
    final media3Initialization = Completer<void>();
    final media3 = _FakeVideoPlayerPlatform(
      id: 7,
      initializationGate: media3Initialization.future,
    );
    final mpv = _FakeVideoPlayerPlatform(id: 11);
    final router = PlaybackEnginePlatformRouter.forTesting(
      media3: media3,
      mpv: mpv,
    );
    final options = VideoCreationOptions(
      dataSource: DataSource(
        sourceType: DataSourceType.network,
        uri: 'https://cdn.example/episode.m3u8',
      ),
      viewType: VideoViewType.textureView,
    );

    final initialization = router.init();
    final id = await router.runWithBackend(
      PlaybackEngineBackend.mpv,
      () => router.createWithOptions(options),
    );
    media3Initialization.complete();
    await initialization;

    expect(mpv.activeIds, {11});
    await router.dispose(id!);
  });
}

class _FakeVideoPlayerPlatform extends VideoPlayerPlatform {
  _FakeVideoPlayerPlatform({
    required this.id,
    this.creationError,
    this.pendingCreation,
    this.initializationGate,
  });

  final int id;
  final Object? creationError;
  final Future<int?>? pendingCreation;
  final Future<void>? initializationGate;
  VideoCreationOptions? lastOptions;
  (int, double)? lastVolumeCall;
  final disposedIds = <int>[];
  final activeIds = <int>{};

  @override
  Future<void> init() async {
    await initializationGate;
    activeIds.clear();
  }

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    lastOptions = options;
    if (creationError != null) throw creationError!;
    if (pendingCreation != null) return pendingCreation;
    activeIds.add(id);
    return id;
  }

  @override
  Future<void> setVolume(int playerId, double volume) async {
    lastVolumeCall = (playerId, volume);
  }

  @override
  Future<void> dispose(int playerId) async {
    disposedIds.add(playerId);
    activeIds.remove(playerId);
  }
}
