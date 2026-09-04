import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_chrome_cast/flutter_chrome_cast.dart';

import '../models/channel.dart';

class CastService {
  CastService._();

  static final CastService instance = CastService._();
  static const String defaultReceiverAppId = 'CC1AD845';

  bool _initializationAttempted = false;
  bool _available = false;

  bool get isAvailable => _available;

  List<GoogleCastDevice> get devices =>
      _available ? GoogleCastDiscoveryManager.instance.devices : const [];

  Stream<List<GoogleCastDevice>> get devicesStream =>
      GoogleCastDiscoveryManager.instance.devicesStream;

  GoogleCastSession? get currentSession =>
      _available ? GoogleCastSessionManager.instance.currentSession : null;

  Stream<GoogleCastSession?> get sessionStream =>
      GoogleCastSessionManager.instance.currentSessionStream;

  bool get isConnected =>
      _available && GoogleCastSessionManager.instance.hasConnectedSession;

  Future<bool> initialize() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return false;
    }
    if (_initializationAttempted) return _available;
    _initializationAttempted = true;
    try {
      _available = await GoogleCastContext.instance
          .setSharedInstanceWithOptions(
            GoogleCastOptionsAndroid(
              appId: defaultReceiverAppId,
              stopCastingOnAppTerminated: false,
            ),
          );
    } catch (_) {
      _available = false;
    }
    return _available;
  }

  Future<void> startDiscovery() async {
    if (!_available) return;
    await GoogleCastDiscoveryManager.instance.startDiscovery();
  }

  Future<void> stopDiscovery() async {
    if (!_available) return;
    await GoogleCastDiscoveryManager.instance.stopDiscovery();
  }

  Future<void> connectAndLoad({
    required GoogleCastDevice device,
    required String url,
    required String title,
    String? posterUrl,
    Duration position = Duration.zero,
    Duration? duration,
    MediaType? mediaType,
  }) async {
    if (!_available) throw StateError('Google Cast no está disponible.');
    final uri = Uri.parse(url);
    final contentType = contentTypeFor(url, mediaType: mediaType);
    if (contentType == null || !isNetworkUrl(url)) {
      throw const FormatException(
        'El formato de este servidor no es casteable.',
      );
    }

    final manager = GoogleCastSessionManager.instance;
    final currentDeviceId = manager.currentSession?.device?.deviceID;
    if (!manager.hasConnectedSession || currentDeviceId != device.deviceID) {
      final started = await manager.startSessionWithDevice(device);
      if (!started && !manager.hasConnectedSession) {
        throw StateError('No se pudo iniciar la sesión con el dispositivo.');
      }
      await manager.currentSessionStream
          .firstWhere(
            (session) =>
                session?.connectionState == GoogleCastConnectState.connected &&
                session?.device?.deviceID == device.deviceID,
          )
          .timeout(const Duration(seconds: 20));
    }

    final images = <GoogleCastImage>[];
    final poster = Uri.tryParse(posterUrl ?? '');
    if (poster != null &&
        (poster.scheme == 'http' || poster.scheme == 'https')) {
      images.add(GoogleCastImage(url: poster));
    }
    final media = GoogleCastMediaInformation(
      contentId: url,
      contentUrl: uri,
      contentType: contentType,
      streamType: CastMediaStreamType.buffered,
      duration: duration,
      metadata: GoogleCastMovieMediaMetadata(
        title: title,
        images: images.isEmpty ? null : images,
      ),
    );
    await GoogleCastRemoteMediaClient.instance.loadMedia(
      media,
      autoPlay: true,
      playPosition: position,
    );

    // `loadMedia` solo confirma que el comando salió, no que el receptor
    // pudo abrir el video: antes de esto, un formato o cabecera rechazados
    // dejaban al televisor sin mostrar nada mientras la app igual marcaba
    // "Conectado" y pausaba el video local. Se espera el primer estado real
    // del receptor antes de dar la carga por buena.
    try {
      await GoogleCastRemoteMediaClient.instance.mediaStatusStream
          .firstWhere((status) {
            final state = status?.playerState;
            if (state == CastMediaPlayerState.playing ||
                state == CastMediaPlayerState.buffering ||
                state == CastMediaPlayerState.paused) {
              return true;
            }
            if (state == CastMediaPlayerState.idle &&
                status?.idleReason == GoogleCastMediaIdleReason.error) {
              throw StateError(
                'El televisor rechazó este video (formato no compatible).',
              );
            }
            return false;
          })
          .timeout(const Duration(seconds: 12));
    } on TimeoutException {
      throw StateError(
        'El televisor no confirmó la reproducción. Puede que este video no '
        'sea compatible con Chromecast.',
      );
    }
  }

  Future<void> disconnect() async {
    if (!_available) return;
    await GoogleCastSessionManager.instance.endSessionAndStopCasting();
  }

  static bool isNetworkUrl(String value) {
    final uri = Uri.tryParse(value);
    return uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
  }

  static bool needsUnsupportedHeaders(String? userAgent) =>
      userAgent != null && userAgent.trim().isNotEmpty;

  /// Deduce el tipo MIME a partir de la extension de la URL. Muchas fuentes
  /// IPTV sirven HLS/MP4 sin extension visible (query string, redirecciones,
  /// tokens); cuando ya sabemos que tipo de contenido es (`mediaType`, tomado
  /// del propio Channel en vez de adivinar por string), no rechazamos el cast
  /// solo por no encontrar sufijo: En Vivo es HLS casi siempre, VOD es MP4.
  static String? contentTypeFor(String value, {MediaType? mediaType}) {
    final path = Uri.tryParse(value)?.path.toLowerCase() ?? '';
    if (path.endsWith('.m3u8')) return 'application/x-mpegURL';
    if (path.endsWith('.mp4') || path.endsWith('.m4v')) return 'video/mp4';
    if (path.endsWith('.webm')) return 'video/webm';
    if (mediaType == MediaType.live) return 'application/x-mpegURL';
    if (mediaType == MediaType.movie || mediaType == MediaType.series) {
      return 'video/mp4';
    }
    return null;
  }
}
