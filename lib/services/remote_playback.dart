import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_chrome_cast/flutter_chrome_cast.dart';

import 'cast_service.dart';
import 'dlna_service.dart';

/// Video que se está reproduciendo en un TV, por Chromecast o por DLNA. Los
/// controles remotos solo hablan con esta interfaz.
abstract class RemotePlayback extends ChangeNotifier {
  /// Transmisión en curso (una a la vez); null = nada en el TV.
  static final active = ValueNotifier<RemotePlayback?>(null);

  String get deviceName;
  String get stateLabel;
  bool get playing;
  Duration get position;
  Duration get duration;

  /// 0..1; null si el TV no deja controlar el volumen.
  double? get volume;

  Future<void> togglePlay();
  Future<void> seek(Duration position);
  Future<void> setVolume(double value);
  Future<void> stop();

  /// Termina la transmisión y libera [active].
  Future<void> disconnect();

  @protected
  void ended() {
    if (identical(active.value, this)) active.value = null;
    dispose();
  }
}

class GoogleCastPlayback extends RemotePlayback {
  GoogleCastPlayback() {
    final sessions = GoogleCastSessionManager.instance;
    final media = GoogleCastRemoteMediaClient.instance;
    _session = sessions.currentSession;
    _status = media.mediaStatus;
    _position = media.playerPosition;
    _subs = [
      sessions.currentSessionStream.listen((session) {
        _session = session;
        if (session == null ||
            session.connectionState == GoogleCastConnectState.disconnected) {
          ended();
          return;
        }
        notifyListeners();
      }),
      media.mediaStatusStream.listen((status) {
        _status = status;
        notifyListeners();
      }),
      media.playerPositionStream.listen((position) {
        _position = position;
        notifyListeners();
      }),
    ];
  }

  late final List<StreamSubscription<Object?>> _subs;
  GoogleCastSession? _session;
  GoggleCastMediaStatus? _status;
  Duration _position = Duration.zero;

  @override
  String get deviceName => _session?.device?.friendlyName ?? 'Chromecast';

  @override
  bool get playing => switch (_status?.playerState) {
    CastMediaPlayerState.playing ||
    CastMediaPlayerState.buffering ||
    CastMediaPlayerState.loading => true,
    _ => false,
  };

  @override
  String get stateLabel => switch (_status?.playerState) {
    CastMediaPlayerState.playing => 'Reproduciendo',
    CastMediaPlayerState.paused => 'Pausado',
    CastMediaPlayerState.buffering ||
    CastMediaPlayerState.loading => 'Cargando',
    CastMediaPlayerState.idle => 'Detenido',
    _ => 'Conectado',
  };

  @override
  Duration get position => _position;

  @override
  Duration get duration => _status?.mediaInformation?.duration ?? Duration.zero;

  @override
  double? get volume => (_session?.currentDeviceVolume ?? .5).clamp(0, 1);

  @override
  Future<void> togglePlay() async {
    final media = GoogleCastRemoteMediaClient.instance;
    playing ? await media.pause() : await media.play();
  }

  @override
  Future<void> seek(Duration position) => GoogleCastRemoteMediaClient.instance
      .seek(GoogleCastMediaSeekOption(position: position));

  @override
  Future<void> setVolume(double value) async =>
      GoogleCastSessionManager.instance.setDeviceVolume(value);

  @override
  Future<void> stop() => GoogleCastRemoteMediaClient.instance.stop();

  @override
  Future<void> disconnect() async {
    await CastService.instance.disconnect();
    if (!_disposed) ended();
  }

  bool _disposed = false;

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    for (final sub in _subs) {
      unawaited(sub.cancel());
    }
    super.dispose();
  }
}

class DlnaPlayback extends RemotePlayback {
  DlnaPlayback(this.renderer) {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _poll());
    unawaited(
      DlnaService.instance.volume(renderer).then((v) {
        if (v == null || _disposed) return;
        _volume = v / 100;
        notifyListeners();
      }),
    );
  }

  final DlnaRenderer renderer;
  late final Timer _timer;
  String _state = 'TRANSITIONING';
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  double? _volume;
  bool _polling = false;
  bool _disposed = false;

  Future<void> _poll() async {
    // Sin pantalla de controles abierta no hace falta preguntar al TV.
    if (_polling || !hasListeners) return;
    _polling = true;
    final status = await DlnaService.instance.status(renderer);
    _polling = false;
    if (status == null || _disposed) return;
    _state = status.state;
    _position = status.position;
    _duration = status.duration;
    notifyListeners();
  }

  @override
  String get deviceName => renderer.name;

  @override
  bool get playing => _state == 'PLAYING' || _state == 'TRANSITIONING';

  @override
  String get stateLabel => switch (_state) {
    'PLAYING' => 'Reproduciendo',
    'PAUSED_PLAYBACK' => 'Pausado',
    'TRANSITIONING' => 'Cargando',
    'STOPPED' || 'NO_MEDIA_PRESENT' => 'Detenido',
    _ => 'Conectado',
  };

  @override
  Duration get position => _position;

  @override
  Duration get duration => _duration;

  @override
  double? get volume => _volume;

  @override
  Future<void> togglePlay() async {
    final dlna = DlnaService.instance;
    playing ? await dlna.pause(renderer) : await dlna.play(renderer);
    if (_disposed) return;
    _state = playing ? 'PAUSED_PLAYBACK' : 'PLAYING';
    notifyListeners();
  }

  @override
  Future<void> seek(Duration position) async {
    final max = _duration > Duration.zero ? _duration : position;
    await DlnaService.instance.seek(
      renderer,
      position < Duration.zero
          ? Duration.zero
          : (position > max ? max : position),
    );
  }

  @override
  Future<void> setVolume(double value) async {
    if (_disposed) return;
    _volume = value;
    notifyListeners();
    await DlnaService.instance.setVolume(renderer, (value * 100).round());
  }

  @override
  Future<void> stop() => DlnaService.instance.stop(renderer);

  @override
  Future<void> disconnect() async {
    await DlnaService.instance.stop(renderer);
    if (!_disposed) ended();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _timer.cancel();
    super.dispose();
  }
}
