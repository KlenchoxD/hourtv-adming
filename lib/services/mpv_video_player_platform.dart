import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:media_kit/media_kit.dart' as mpv;
import 'package:media_kit_video/media_kit_video.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'mpv_video_event_bridge.dart';

void _traceMpv(String message) {
  if (kDebugMode) debugPrint('[HourTV-MPV] $message');
}

/// Returns actionable native-player error text without leaking signed URLs or
/// request credentials into debug logs or test output.
@visibleForTesting
String sanitizeMpvDiagnostic(Object error) {
  var message = error.toString().replaceAll(
    RegExp(r'https?://[^\s<>"\]]+', caseSensitive: false),
    '[url]',
  );
  message = message.replaceAllMapped(
    RegExp(
      r'\b(authorization|proxy-authorization|cookie|set-cookie|x-api-key)\s*[:=]\s*(?:bearer\s+)?(?:"[^"]*"|\x27[^\x27]*\x27|[^\s,;]+)',
      caseSensitive: false,
    ),
    (match) => '${match.group(1)}=[redacted]',
  );
  message = message.replaceAllMapped(
    RegExp(
      r'([?&]?(?:token|sig|signature|key|auth|password|api[_-]?key)=)[^&\s,;]+',
      caseSensitive: false,
    ),
    (match) => '${match.group(1)}[redacted]',
  );
  message = message.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (message.length > 240) message = '${message.substring(0, 240)}…';
  return '[${error.runtimeType}] $message';
}

/// HourTV's native mpv adapter. It keeps video_player's Dart captions and
/// controls while translating native playback, buffering and track events.
class MpvVideoPlayerPlatform extends VideoPlayerPlatform {
  static const Object livePlaybackZoneKey = #hourTvMpvLivePlayback;
  static bool _libraryInitialized = false;

  static MpvVideoPlayerPlatform createNative({
    mpv.PlayerConfiguration configuration = const mpv.PlayerConfiguration(),
    VideoControllerConfiguration videoConfiguration =
        const VideoControllerConfiguration(),
  }) {
    if (!_libraryInitialized) {
      mpv.MediaKit.ensureInitialized();
      _libraryInitialized = true;
    }
    return MpvVideoPlayerPlatform._(configuration, videoConfiguration);
  }

  MpvVideoPlayerPlatform._(this._configuration, this._videoConfiguration);

  final mpv.PlayerConfiguration _configuration;
  final VideoControllerConfiguration _videoConfiguration;

  final Map<int, _MpvSession> _sessions = {};
  int _nextId = 0;

  _MpvSession _session(int id) =>
      _sessions[id] ?? (throw StateError('Native playback session is closed.'));

  @override
  Future<void> init() async {
    for (final id in _sessions.keys.toList()) {
      await dispose(id);
    }
  }

  @override
  Future<int?> create(DataSource dataSource) async {
    final resource = switch (dataSource.sourceType) {
      DataSourceType.asset =>
        'asset:///${dataSource.package == null ? '' : 'packages/${dataSource.package}/'}${dataSource.asset}',
      _ => dataSource.uri ?? (throw ArgumentError('A media URI is required.')),
    };
    final player = mpv.Player(configuration: _configuration);
    final session = _MpvSession(
      player,
      resource: resource,
      headers: Map.of(dataSource.httpHeaders),
      isLive: Zone.current[livePlaybackZoneKey] == true,
      videoConfiguration: _videoConfiguration,
    );
    final id = _nextId++;
    _sessions[id] = session;
    session.bindEvents();
    // Create media_kit's Android output before initialization starts. The
    // video_player widget only mounts its view after it receives the
    // initialized event, so waiting for buildView() here would deadlock.
    session.startPlaybackWhenReady();
    _traceMpv('create handle=$id type=${dataSource.sourceType}');
    return id;
  }

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) =>
      create(options.dataSource);

  @override
  Future<void> dispose(int playerId) async {
    final session = _sessions.remove(playerId);
    if (session != null) await session.dispose();
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) =>
      _session(playerId).events.stream;

  @override
  Future<void> play(int playerId) => _session(playerId).player.play();

  @override
  Future<void> pause(int playerId) => _session(playerId).player.pause();

  @override
  Future<void> setLooping(int playerId, bool looping) =>
      _session(playerId).player.setPlaylistMode(
        looping ? mpv.PlaylistMode.single : mpv.PlaylistMode.none,
      );

  @override
  Future<void> setVolume(int playerId, double volume) =>
      _session(playerId).player.setVolume(volume.clamp(0.0, 1.0) * 100);

  @override
  Future<void> seekTo(int playerId, Duration position) =>
      _session(playerId).player.seek(position);

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) =>
      _session(playerId).player.setRate(speed);

  @override
  Future<Duration> getPosition(int playerId) async =>
      _session(playerId).player.state.position;

  @override
  Widget buildView(int playerId) {
    final session = _session(playerId);
    return Video(
      key: ValueKey(session.video),
      controller: session.video,
      controls: NoVideoControls,
      wakelock: false,
      fill: const Color(0x00000000),
      pauseUponEnteringBackgroundMode: false,
      resumeUponEnteringForegroundMode: false,
    );
  }

  @override
  Widget buildViewWithOptions(VideoViewOptions options) =>
      buildView(options.playerId);

  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}

  @override
  Future<void> setAllowBackgroundPlayback(bool allowBackgroundPlayback) async {}

  @override
  Future<void> setWebOptions(
    int playerId,
    VideoPlayerWebOptions options,
  ) async {}

  @override
  bool isAudioTrackSupportAvailable() => true;

  @override
  Future<List<VideoAudioTrack>> getAudioTracks(int playerId) async {
    final state = _session(playerId).player.state;
    return [
      for (final track in state.tracks.audio)
        if (track.id != 'auto' && track.id != 'no')
          VideoAudioTrack(
            id: track.id,
            label: track.title,
            language: track.language,
            isSelected: state.track.audio.id == track.id,
            codec: track.codec,
            bitrate: track.bitrate,
            sampleRate: track.samplerate,
            channelCount: track.channelscount,
          ),
    ];
  }

  @override
  Future<void> selectAudioTrack(int playerId, String trackId) {
    final player = _session(playerId).player;
    final track = player.state.tracks.audio.firstWhere(
      (track) => track.id == trackId,
    );
    return player.setAudioTrack(track);
  }

  @override
  bool isVideoTrackSupportAvailable() => true;

  @override
  Future<List<VideoTrack>> getVideoTracks(int playerId) async {
    final state = _session(playerId).player.state;
    return [
      for (final track in state.tracks.video)
        if (track.id != 'auto' && track.id != 'no')
          VideoTrack(
            id: track.id,
            label: track.title,
            isSelected: state.track.video.id == track.id,
            width: track.w,
            height: track.h,
            bitrate: track.bitrate,
            frameRate: track.fps,
            codec: track.codec,
          ),
    ];
  }

  @override
  Future<void> selectVideoTrack(int playerId, VideoTrack? track) {
    final player = _session(playerId).player;
    return player.setVideoTrack(
      track == null
          ? mpv.VideoTrack.auto()
          : player.state.tracks.video.firstWhere(
              (candidate) => candidate.id == track.id,
            ),
    );
  }
}

class _MpvSession {
  _MpvSession(
    this.player, {
    required this.resource,
    required this.headers,
    required bool isLive,
    required this.videoConfiguration,
  }) : events = MpvVideoEventBridge(isLive: isLive);

  final mpv.Player player;
  final String resource;
  final Map<String, String> headers;
  final VideoControllerConfiguration videoConfiguration;
  final MpvVideoEventBridge events;
  final subscriptions = <StreamSubscription<dynamic>>[];
  VideoController? _video;
  bool _disposed = false;
  bool _opened = false;
  String? _lastMetadataTrace;
  Future<void>? _openTask;
  Timer? _diagnosticsTimer;
  int _diagnosticSamples = 0;
  bool _diagnosticReadInFlight = false;

  VideoController get video =>
      _video ??= VideoController(player, configuration: videoConfiguration);

  void startPlaybackWhenReady() {
    final controller = video;
    _openTask ??= _openAfterVideoOutput(controller);
  }

  Future<void> _openAfterVideoOutput(VideoController controller) async {
    try {
      _traceMpv('video_output_wait');
      await controller.platform.future;
      if (_disposed) return;
      _traceMpv('video_output_ready');
      await open(resource, headers);
    } catch (error) {
      if (_disposed) return;
      _traceMpv('video_output_failed ${sanitizeMpvDiagnostic(error)}');
      reportError(error);
    }
  }

  void emit(VideoEvent event) {
    events.emit(event);
  }

  void reportError(Object error) {
    events.reportError(error);
  }

  void notifyMetadata() {
    if (_disposed) return;
    final state = player.state;
    final params = state.videoParams;
    final fallbackTrack = _videoTrackWithDimensions(
      state.tracks.video,
      selectedTrackId: state.track.video.id,
    );
    final trackWidth =
        fallbackTrack?.rotate == 90 || fallbackTrack?.rotate == 270
        ? fallbackTrack?.h
        : fallbackTrack?.w;
    final trackHeight =
        fallbackTrack?.rotate == 90 || fallbackTrack?.rotate == 270
        ? fallbackTrack?.w
        : fallbackTrack?.h;
    final audioOnly =
        _opened &&
        state.tracks.audio.any((t) => t.id != 'auto' && t.id != 'no') &&
        !state.tracks.video.any((t) => t.id != 'auto' && t.id != 'no');
    final trace =
        'metadata open=$_opened duration=${state.duration.inMilliseconds}ms '
        'params=${params.dw}x${params.dh} '
        'track=${trackWidth}x$trackHeight audioOnly=$audioOnly';
    if (trace != _lastMetadataTrace) {
      _lastMetadataTrace = trace;
      _traceMpv(trace);
    }
    events.notifyMetadata(
      duration: state.duration,
      width: _positive(params.dw) ? params.dw : trackWidth,
      height: _positive(params.dh) ? params.dh : trackHeight,
      audioOnly: audioOnly,
    );
  }

  bool _positive(int? value) => value != null && value > 0;

  mpv.VideoTrack? _videoTrackWithDimensions(
    List<mpv.VideoTrack> tracks, {
    required String selectedTrackId,
  }) {
    bool hasDimensions(mpv.VideoTrack track) =>
        _positive(track.w) && _positive(track.h);

    for (final track in tracks) {
      if (track.id == selectedTrackId && hasDimensions(track)) return track;
    }
    for (final track in tracks) {
      if (track.id != 'auto' && track.id != 'no' && hasDimensions(track)) {
        return track;
      }
    }
    return null;
  }

  void bindEvents() {
    subscriptions.addAll([
      player.stream.duration.listen((_) => notifyMetadata()),
      player.stream.videoParams.listen((_) => notifyMetadata()),
      player.stream.tracks.listen((_) => notifyMetadata()),
      player.stream.playing.listen(
        (playing) => emit(
          VideoEvent(
            eventType: VideoEventType.isPlayingStateUpdate,
            isPlaying: playing,
          ),
        ),
      ),
      player.stream.completed.listen((completed) {
        if (completed) emit(VideoEvent(eventType: VideoEventType.completed));
      }),
      player.stream.buffering.listen(
        (buffering) => emit(
          VideoEvent(
            eventType: buffering
                ? VideoEventType.bufferingStart
                : VideoEventType.bufferingEnd,
          ),
        ),
      ),
      player.stream.buffer.listen(
        (buffer) => emit(
          VideoEvent(
            eventType: VideoEventType.bufferingUpdate,
            buffered: [DurationRange(Duration.zero, buffer)],
          ),
        ),
      ),
      // Initialization failures must be delivered before the first frame.
      player.stream.error.listen((error) {
        _traceMpv('native_error ${sanitizeMpvDiagnostic(error)}');
        reportError(error);
      }),
    ]);
  }

  Future<void> open(String resource, Map<String, String> headers) async {
    try {
      _traceMpv('open_start');
      // Media3 initializes its controller as soon as the demuxer reports the
      // stream metadata. libmpv may not expose decoded video dimensions while
      // opened paused; the app does not mount VideoPlayer until initialize()
      // completes, so pausing here creates an initialization deadlock. Start
      // the alternate native engine and let its first decoded frame complete
      // initialization; this is already an autoplay playback path.
      await player.open(mpv.Media(resource, httpHeaders: headers), play: true);
      if (_disposed) return;
      _opened = true;
      _traceMpv(
        'open_ready duration=${player.state.duration.inMilliseconds}ms '
        'videoTracks=${player.state.tracks.video.length}',
      );
      // HourTV draws its own captions through VideoPlayerController.
      await player.setSubtitleTrack(mpv.SubtitleTrack.no());
      notifyMetadata();
      _startPerformanceDiagnostics();
    } catch (error) {
      _traceMpv('open_failed ${sanitizeMpvDiagnostic(error)}');
      reportError(error);
    }
  }

  void _startPerformanceDiagnostics() {
    if (!kDebugMode || _diagnosticsTimer != null) return;
    unawaited(_emitPerformanceSample());
    _diagnosticsTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_disposed || ++_diagnosticSamples >= 7) {
        timer.cancel();
        _diagnosticsTimer = null;
        return;
      }
      unawaited(_emitPerformanceSample());
    });
  }

  Future<void> _emitPerformanceSample() async {
    if (_disposed || _diagnosticReadInFlight) return;
    _diagnosticReadInFlight = true;
    try {
      const properties = <String>[
        'vo',
        'vo-configured',
        'hwdec',
        'hwdec-current',
        'hwdec-interop',
        'video-codec',
        'container-fps',
        'estimated-vf-fps',
        'frame-drop-count',
        'decoder-frame-drop-count',
        'vo-delayed-frame-count',
        'demuxer-cache-duration',
      ];
      final values = <String>[];
      for (final property in properties) {
        try {
          final value =
              await (player.platform as dynamic).getProperty(
                    property,
                    waitForInitialization: false,
                  )
                  as String;
          if (value.isNotEmpty) {
            final sanitizedValue = value.replaceAll(
              RegExp(r'[^A-Za-z0-9_.:/,+-]'),
              '_',
            );
            final safeValue = sanitizedValue.substring(
              0,
              sanitizedValue.length.clamp(0, 72).toInt(),
            );
            values.add('$property=$safeValue');
          }
        } catch (_) {
          // Some properties are unsupported by particular libmpv builds.
        }
      }
      if (!_disposed && values.isNotEmpty) {
        _traceMpv('performance ${values.join(' ')}');
      }
    } finally {
      _diagnosticReadInFlight = false;
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _diagnosticsTimer?.cancel();
    _diagnosticsTimer = null;
    await Future.wait(
      subscriptions.map((subscription) => subscription.cancel()),
    );
    try {
      await player.dispose();
    } finally {
      await events.dispose();
    }
  }
}
