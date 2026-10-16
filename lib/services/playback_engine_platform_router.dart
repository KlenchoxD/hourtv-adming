import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'mpv_video_player_platform.dart';

enum PlaybackEngineBackend { media3, mpv }

/// Keeps Flutter's existing VideoPlayerController UI while routing each
/// controller to either the platform Media3 engine or media_kit/mpv.
///
/// The public video_player platform is process-global. This router is installed
/// once, then pins every created player id to its backend so a fallback cannot
/// redirect a live-TV controller or another in-flight player by accident.
class PlaybackEnginePlatformRouter extends VideoPlayerPlatform {
  PlaybackEnginePlatformRouter._(
    this._media3,
    this._mpv, {
    this.creationTimeout = const Duration(seconds: 20),
    this.mpvVideoConfiguration = const VideoControllerConfiguration(),
  });

  @visibleForTesting
  factory PlaybackEnginePlatformRouter.forTesting({
    required VideoPlayerPlatform media3,
    required VideoPlayerPlatform mpv,
    Duration creationTimeout = const Duration(seconds: 20),
    VideoControllerConfiguration mpvVideoConfiguration =
        const VideoControllerConfiguration(),
  }) => PlaybackEnginePlatformRouter._(
    media3,
    mpv,
    creationTimeout: creationTimeout,
    mpvVideoConfiguration: mpvVideoConfiguration,
  );

  static const Object _backendZoneKey = #hourTvPlaybackEngine;
  static PlaybackEnginePlatformRouter? _installed;

  static bool get canUseMpv => _installed != null;

  static Future<T> initializeController<T>(
    PlaybackEngineBackend backend,
    Future<T> Function() initialize, {
    bool isLive = false,
  }) {
    final router = _installed;
    if (router == null) return initialize();
    return router.runWithBackend(backend, initialize, isLive: isLive);
  }

  final VideoPlayerPlatform _media3;
  final Duration creationTimeout;
  final VideoControllerConfiguration mpvVideoConfiguration;
  VideoPlayerPlatform? _mpv;
  Future<void>? _mpvInitialization;
  final Map<int, _RoutedPlayer> _players = {};
  int _nextPlayerId = 0;

  static Future<void> installForAndroid({
    VideoControllerConfiguration mpvVideoConfiguration =
        const VideoControllerConfiguration(),
  }) async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    final current = VideoPlayerPlatform.instance;
    if (current is PlaybackEnginePlatformRouter) {
      _installed = current;
      return;
    }
    final router = PlaybackEnginePlatformRouter._(
      current,
      null,
      mpvVideoConfiguration: mpvVideoConfiguration,
    );
    _installed = router;
    VideoPlayerPlatform.instance = router;
  }

  /// Runs controller creation in an async-local backend scope. Zone scoping
  /// allows concurrent players to initialize against different engines.
  Future<T> runWithBackend<T>(
    PlaybackEngineBackend backend,
    Future<T> Function() operation, {
    bool isLive = false,
  }) async {
    if (backend == PlaybackEngineBackend.mpv) await _ensureMpvBackend();
    return runZoned(
      operation,
      zoneValues: {
        _backendZoneKey: backend,
        MpvVideoPlayerPlatform.livePlaybackZoneKey: isLive,
      },
    );
  }

  Future<void> _ensureMpvBackend() {
    if (_mpv != null) return Future.value();
    return _mpvInitialization ??= _registerMpvBackend().whenComplete(
      () => _mpvInitialization = null,
    );
  }

  Future<void> _registerMpvBackend() async {
    if (!identical(VideoPlayerPlatform.instance, this)) {
      throw StateError('Playback router is not the active platform instance.');
    }
    final backend = MpvVideoPlayerPlatform.createNative(
      videoConfiguration: mpvVideoConfiguration,
    );
    await backend.init();
    _mpv = backend;
  }

  VideoPlayerPlatform get _requestedPlatform {
    final backend = Zone.current[_backendZoneKey] as PlaybackEngineBackend?;
    if (backend == PlaybackEngineBackend.mpv) {
      final mpv = _mpv;
      if (mpv == null) throw StateError('mpv backend is not initialized.');
      return mpv;
    }
    return _media3;
  }

  _RoutedPlayer _route(int playerId) =>
      _players[playerId] ??
      (throw StateError('Playback controller is closed or was not created.'));

  Future<int?> _create(
    VideoPlayerPlatform platform,
    Future<int?> Function() create,
  ) async {
    var expired = false;
    try {
      final nativeId = await create()
          .then((id) {
            if (expired && id != null) {
              unawaited(
                platform.dispose(id).catchError((Object _) {
                  debugPrint('[PLAYER] late_native_handle_disposal_failed');
                }),
              );
            }
            return id;
          })
          .timeout(
            creationTimeout,
            onTimeout: () {
              expired = true;
              throw TimeoutException('Native player creation timed out.');
            },
          );
      if (nativeId == null) {
        throw StateError('The native engine returned no playback handle.');
      }
      final routedId = _nextPlayerId++;
      _players[routedId] = _RoutedPlayer(platform, nativeId);
      return routedId;
    } catch (error) {
      // video_player waits for create() even during dispose(). Deliver a real
      // handle plus an error event, instead of leaving its creating completer
      // unresolved after an engine fails to construct its source.
      final routedId = _nextPlayerId++;
      final failure = error is PlatformException
          ? error
          : PlatformException(code: 'VideoError', message: error.toString());
      _players[routedId] = _RoutedPlayer(_CreationFailurePlatform(failure), 0);
      return routedId;
    }
  }

  @override
  Future<void> init() async {
    _players.clear();
    // VideoPlayerPlatform.instance.init() is started by video_player without
    // awaiting it. Start both delegates before yielding so a slow Media3 init
    // cannot let a new mpv session be created and then disposed by mpv.init().
    final media3Initialization = _media3.init();
    final mpvInitialization = _mpv?.init();
    await Future.wait<void>([media3Initialization, ?mpvInitialization]);
  }

  @override
  Future<int?> create(DataSource dataSource) {
    final platform = _requestedPlatform;
    return _create(
      platform,
      () => platform.createWithOptions(
        VideoCreationOptions(
          dataSource: dataSource,
          viewType: VideoViewType.textureView,
        ),
      ),
    );
  }

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) {
    final platform = _requestedPlatform;
    return _create(platform, () => platform.createWithOptions(options));
  }

  @override
  Future<void> dispose(int playerId) async {
    final route = _players.remove(playerId);
    if (route != null) await route.platform.dispose(route.nativeId);
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) {
    final route = _route(playerId);
    return route.platform.videoEventsFor(route.nativeId);
  }

  @override
  Future<void> setLooping(int playerId, bool looping) {
    final route = _route(playerId);
    return route.platform.setLooping(route.nativeId, looping);
  }

  @override
  Future<void> play(int playerId) {
    final route = _route(playerId);
    return route.platform.play(route.nativeId);
  }

  @override
  Future<void> pause(int playerId) {
    final route = _route(playerId);
    return route.platform.pause(route.nativeId);
  }

  @override
  Future<void> setVolume(int playerId, double volume) {
    final route = _route(playerId);
    return route.platform.setVolume(route.nativeId, volume);
  }

  @override
  Future<void> seekTo(int playerId, Duration position) {
    final route = _route(playerId);
    return route.platform.seekTo(route.nativeId, position);
  }

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) {
    final route = _route(playerId);
    return route.platform.setPlaybackSpeed(route.nativeId, speed);
  }

  @override
  Future<Duration> getPosition(int playerId) {
    final route = _route(playerId);
    return route.platform.getPosition(route.nativeId);
  }

  @override
  Widget buildView(int playerId) {
    final route = _route(playerId);
    return route.platform.buildViewWithOptions(
      VideoViewOptions(playerId: route.nativeId),
    );
  }

  @override
  Widget buildViewWithOptions(VideoViewOptions options) {
    final route = _route(options.playerId);
    return route.platform.buildViewWithOptions(
      VideoViewOptions(playerId: route.nativeId),
    );
  }

  @override
  Future<void> setMixWithOthers(bool mixWithOthers) =>
      _requestedPlatform.setMixWithOthers(mixWithOthers);

  @override
  Future<void> setAllowBackgroundPlayback(bool allowBackgroundPlayback) =>
      _requestedPlatform.setAllowBackgroundPlayback(allowBackgroundPlayback);

  @override
  Future<void> setPreventsDisplaySleepDuringVideoPlayback(
    int playerId,
    bool preventsDisplaySleepDuringVideoPlayback,
  ) {
    final route = _route(playerId);
    return route.platform.setPreventsDisplaySleepDuringVideoPlayback(
      route.nativeId,
      preventsDisplaySleepDuringVideoPlayback,
    );
  }

  @override
  Future<void> setWebOptions(int playerId, VideoPlayerWebOptions options) {
    final route = _route(playerId);
    return route.platform.setWebOptions(route.nativeId, options);
  }

  @override
  Future<List<VideoAudioTrack>> getAudioTracks(int playerId) {
    final route = _route(playerId);
    return route.platform.getAudioTracks(route.nativeId);
  }

  @override
  Future<void> selectAudioTrack(int playerId, String trackId) {
    final route = _route(playerId);
    return route.platform.selectAudioTrack(route.nativeId, trackId);
  }

  @override
  bool isAudioTrackSupportAvailable() =>
      _media3.isAudioTrackSupportAvailable() ||
      (_mpv?.isAudioTrackSupportAvailable() ?? false);

  @override
  Future<List<VideoTrack>> getVideoTracks(int playerId) {
    final route = _route(playerId);
    return route.platform.getVideoTracks(route.nativeId);
  }

  @override
  Future<void> selectVideoTrack(int playerId, VideoTrack? track) {
    final route = _route(playerId);
    return route.platform.selectVideoTrack(route.nativeId, track);
  }

  @override
  bool isVideoTrackSupportAvailable() =>
      _media3.isVideoTrackSupportAvailable() ||
      (_mpv?.isVideoTrackSupportAvailable() ?? false);
}

class _RoutedPlayer {
  const _RoutedPlayer(this.platform, this.nativeId);

  final VideoPlayerPlatform platform;
  final int nativeId;
}

class _CreationFailurePlatform extends VideoPlayerPlatform {
  _CreationFailurePlatform(this.error);
  final PlatformException error;

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => Stream.error(error);

  @override
  Future<void> dispose(int playerId) async {}
}
