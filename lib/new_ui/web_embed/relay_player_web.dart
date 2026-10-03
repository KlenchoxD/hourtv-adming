import 'dart:async';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
// Reuse the pinned 2.4.0 HTML media event adapter; do not fork native players.
// ignore: implementation_imports
import 'package:video_player_web/src/video_player.dart' as media;
import 'package:web/web.dart' as web;

@JS('hourTvHlsSupported')
external bool _supported();
@JS('hourTvAttachHls')
external _Hls _attach(
  web.HTMLVideoElement video,
  JSString url,
  JSFunction error,
);
extension type _Hls(JSObject _) implements JSObject {
  external void destroy();
}

void registerHourTvRelayPlayer() {
  final current = VideoPlayerPlatform.instance;
  if (current is _RelayPlatform || !_supported()) return;
  VideoPlayerPlatform.instance = _RelayPlatform(current);
}

class _Session {
  final media.VideoPlayer player;
  final _Hls hls;
  final StreamController<VideoEvent> events;
  final StreamSubscription<VideoEvent> subscription;
  _Session(this.player, this.hls, this.events, this.subscription);
  Future<void> dispose() async {
    hls.destroy();
    await subscription.cancel();
    player.pause();
    player.dispose();
    await events.close();
  }
}

/// Existing players are delegated unchanged. Only relay HLS uses MSE/AES support.
class _RelayPlatform extends VideoPlayerPlatform {
  final VideoPlayerPlatform delegate;
  final Map<int, _Session> sessions = {};
  int nextId = 1000000;
  _RelayPlatform(this.delegate);

  @override
  Future<void> init() async {
    for (final session in sessions.values) {
      await session.dispose();
    }
    sessions.clear();
    await delegate.init();
  }

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    final uri = Uri.tryParse(options.dataSource.uri ?? '');
    if (uri?.host != 'hourtv-live-relay.hourtv-release-20261002.workers.dev') {
      return delegate.createWithOptions(options);
    }
    final id = nextId++;
    final video = web.HTMLVideoElement()
      ..id = 'hourtv-relay-$id'
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.border = 'none';
    ui_web.platformViewRegistry.registerViewFactory(
      'hourtv-relay-$id',
      (_) => video,
    );
    final events = StreamController<VideoEvent>();
    final player = media.VideoPlayer(videoElement: video)..initialize();
    final subscription = player.events.listen(
      events.add,
      onError: events.addError,
    );
    final hls = _attach(
      video,
      uri.toString().toJS,
      ((JSString detail) {
        if (!events.isClosed) {
          events.addError(
            PlatformException(code: 'HLS_STREAM_ERROR', message: detail.toDart),
          );
        }
      }).toJS,
    );
    sessions[id] = _Session(player, hls, events, subscription);
    return id;
  }

  @override
  Future<void> dispose(int id) async {
    final session = sessions.remove(id);
    if (session != null) {
      await session.dispose();
    } else {
      await delegate.dispose(id);
    }
  }

  @override
  Stream<VideoEvent> videoEventsFor(int id) =>
      sessions[id]?.events.stream ?? delegate.videoEventsFor(id);
  @override
  Future<void> play(int id) => sessions[id]?.player.play() ?? delegate.play(id);
  @override
  Future<void> pause(int id) async {
    if (sessions.containsKey(id)) {
      sessions[id]!.player.pause();
    } else {
      await delegate.pause(id);
    }
  }

  @override
  Future<void> setLooping(int id, bool value) async {
    if (sessions.containsKey(id)) {
      sessions[id]!.player.setLooping(value);
    } else {
      await delegate.setLooping(id, value);
    }
  }

  @override
  Future<void> setVolume(int id, double value) async {
    if (sessions.containsKey(id)) {
      sessions[id]!.player.setVolume(value);
    } else {
      await delegate.setVolume(id, value);
    }
  }

  @override
  Future<void> seekTo(int id, Duration value) async {
    if (sessions.containsKey(id)) {
      sessions[id]!.player.seekTo(value);
    } else {
      await delegate.seekTo(id, value);
    }
  }

  @override
  Future<void> setPlaybackSpeed(int id, double value) async {
    if (sessions.containsKey(id)) {
      sessions[id]!.player.setPlaybackSpeed(value);
    } else {
      await delegate.setPlaybackSpeed(id, value);
    }
  }

  @override
  Future<Duration> getPosition(int id) async =>
      sessions[id]?.player.getPosition() ?? await delegate.getPosition(id);
  @override
  Widget buildViewWithOptions(VideoViewOptions options) =>
      sessions.containsKey(options.playerId)
      ? HtmlElementView(viewType: 'hourtv-relay-${options.playerId}')
      : delegate.buildViewWithOptions(options);
  @override
  Future<void> setWebOptions(int id, VideoPlayerWebOptions options) =>
      sessions[id]?.player.setOptions(options) ??
      delegate.setWebOptions(id, options);
  @override
  Future<void> setMixWithOthers(bool value) => delegate.setMixWithOthers(value);
  @override
  Future<void> setAllowBackgroundPlayback(bool value) =>
      delegate.setAllowBackgroundPlayback(value);
}
