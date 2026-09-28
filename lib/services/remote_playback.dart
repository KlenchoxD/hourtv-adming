import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_chrome_cast/flutter_chrome_cast.dart';

import 'cast_service.dart';
import 'dlna_service.dart';

/// Video que se está reproduciendo en un TV, por Chromecast o por DLNA. Los
/// controles remotos solo hablan con esta interfaz.
abstract class RemotePlayback extends ChangeNotifier {
  /// Transmisión en curso (una a la vez); null = nada en el TV.
  static final active = ValueNotifier<RemotePlayback?>(null)
    ..addListener(_routeVolumeKeys);

  static const _device = MethodChannel('hourtv/device');

  /// Mientras se transmite, los botones de volumen del teléfono controlan
  /// el TV (como en YouTube) en vez del volumen del teléfono.
  static void _routeVolumeKeys() {
    final on = active.value != null;
    _device.setMethodCallHandler(
      on
          ? (call) async {
              if (call.method == 'volumeKey') {
                await active.value?.stepVolume(call.arguments as int);
              }
            }
          : null,
    );
    _device
        .invokeMethod<void>('remoteVolumeKeys', {'enabled': on})
        .catchError((_) {});
  }

  /// Sube (+1) o baja (-1) el volumen del TV un 5 %.
  Future<void> stepVolume(int direction) async {
    final current = volume;
    if (current == null) return;
    await setVolume((current + direction * .05).clamp(0.0, 1.0));
  }

  String get deviceName;
  String get stateLabel;
  bool get playing;
  Duration get position;
  Duration get duration;

  /// 0..1; null si el TV no deja controlar el volumen.
  double? get volume;

  /// Si se envió un subtítulo con el video (se puede mostrar u ocultar).
  bool get hasSubtitles => false;
  bool get subtitlesOn => false;
  Future<void> setSubtitles(bool on) async {}

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
  GoogleCastPlayback({this.hasSubtitles = false}) {
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
        // Cambios hechos desde el control del TV, salvo justo después de
        // moverlo aquí (la sesión aún trae el valor viejo).
        if (DateTime.now().difference(_volumeSetAt).inSeconds >= 3) {
          _volume = session.currentDeviceVolume.clamp(0, 1);
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
  @override
  final bool hasSubtitles;
  GoogleCastSession? _session;
  // Volumen propio: el de la sesión tarda en actualizarse y hacía que la
  // barra volviera sola a su lugar.
  late double _volume = (_session?.currentDeviceVolume ?? .5).clamp(0, 1);
  DateTime _volumeSetAt = DateTime(0);
  Timer? _volumeSend;
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
  double? get volume => _volume;

  @override
  Future<void> togglePlay() async {
    final media = GoogleCastRemoteMediaClient.instance;
    playing ? await media.pause() : await media.play();
  }

  @override
  Future<void> seek(Duration position) => GoogleCastRemoteMediaClient.instance
      .seek(GoogleCastMediaSeekOption(position: position));

  @override
  Future<void> setVolume(double value) async {
    if (_disposed) return;
    _volume = value.clamp(0, 1);
    _volumeSetAt = DateTime.now();
    notifyListeners();
    // Al arrastrar llegan decenas de valores: se envía el último cada 150 ms.
    _volumeSend ??= Timer(const Duration(milliseconds: 150), () {
      _volumeSend = null;
      if (!_disposed) {
        GoogleCastSessionManager.instance.setDeviceVolume(_volume);
      }
    });
  }

  // Con HLS el TV numera él mismo la pista (la lee de la lista); con MP4
  // es la que se envió.
  int get _textTrackId =>
      _status?.mediaInformation?.tracks
          ?.where((t) => t.type == TrackType.text)
          .firstOrNull
          ?.trackId ??
      CastService.subtitleTrackId;

  @override
  bool get subtitlesOn =>
      _status?.activeTrackIds?.contains(_textTrackId) ?? false;

  @override
  Future<void> setSubtitles(bool on) =>
      GoogleCastRemoteMediaClient.instance.setActiveTrackIDs(
        on ? [_textTrackId] : const [],
      );

  /// Activa los subtítulos en cuanto el TV termina de leer sus pistas.
  Future<void> showSubtitlesWhenReady() async {
    for (var i = 0; i < 25 && !_disposed; i++) {
      final ready =
          _status?.mediaInformation?.tracks?.any(
            (t) => t.type == TrackType.text,
          ) ??
          false;
      if (ready) {
        await setSubtitles(true);
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 400));
    }
  }

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
    _volumeSend?.cancel();
    for (final sub in _subs) {
      unawaited(sub.cancel());
    }
    super.dispose();
  }
}

class DlnaPlayback extends RemotePlayback {
  /// [reload] vuelve a enviar el video con o sin subtítulo desde una
  /// posición: DLNA no permite cambiarlos sin recargar.
  DlnaPlayback(this.renderer, {this.reload, bool subtitlesOn = false})
    : _subtitlesOn = subtitlesOn {
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
  final Future<void> Function(bool subtitles, Duration position)? reload;
  bool _subtitlesOn;
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
  bool get hasSubtitles => reload != null;

  @override
  bool get subtitlesOn => _subtitlesOn;

  @override
  Future<void> setSubtitles(bool on) async {
    final reload = this.reload;
    if (reload == null || on == _subtitlesOn) return;
    await reload(on, _position);
    if (_disposed) return;
    _subtitlesOn = on;
    notifyListeners();
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
