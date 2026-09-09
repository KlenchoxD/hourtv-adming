import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_chrome_cast/flutter_chrome_cast.dart';

import '../models/channel.dart';
import 'device_type.dart';

/// Motivo estructurado por el cual un stream no es apto para Chromecast directo.
enum StreamBlockReason {
  requiresHeaders,
  webViewOrEmbed,
  unsupportedFormat,
  invalidUrl,
}

/// Información tipada y descriptiva sobre la incompatibilidad de un stream.
class StreamBlockInfo {
  final StreamBlockReason reason;
  final String explanation;
  final bool isHeaderOrWebView;

  const StreamBlockInfo({
    required this.reason,
    required this.explanation,
    required this.isHeaderOrWebView,
  });

  @override
  String toString() => explanation;
}

/// Objetivo alcanzado al abrir los ajustes de transmisión del sistema Android.
enum CastSettingsTarget {
  cast,
  wireless,
  display;

  String get label => switch (this) {
    CastSettingsTarget.cast => 'Ajustes de transmisión',
    CastSettingsTarget.wireless => 'Ajustes de redes inalámbricas',
    CastSettingsTarget.display => 'Ajustes de pantalla',
  };
}

/// Resultado de la invocación de openCastSettings.
class OpenCastSettingsResult {
  final bool opened;
  final CastSettingsTarget? target;
  final String? errorMessage;

  const OpenCastSettingsResult({
    required this.opened,
    this.target,
    this.errorMessage,
  });

  static const unavailable = OpenCastSettingsResult(
    opened: false,
    errorMessage:
        'Este dispositivo no ofrece ninguna actividad compatible para transmitir o duplicar pantalla.',
  );
}

class CastService {
  CastService._();

  static final CastService instance = CastService._();
  static const String defaultReceiverAppId = 'CC1AD845';
  static const MethodChannel _platform = MethodChannel('hourtv/device');

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
      streamType: mediaType == MediaType.live
          ? CastMediaStreamType.live
          : CastMediaStreamType.buffered,
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

  /// Indica si la plataforma actual soporta duplicación de pantalla. Solo
  /// aplica a Android móvil y tablet; en Android TV, escritorio o web no
  /// se muestra a menos que exista una implementación nativa real.
  static bool isScreenMirroringSupported([BuildContext? context]) {
    if (kIsWeb) return false;
    if (defaultTargetPlatform != TargetPlatform.android) return false;
    if (context != null && DeviceProfile.isTv(context)) return false;
    return true;
  }

  /// Abre el panel de ajustes de transmisión o duplicación del sistema.
  /// Intenta ACTION_CAST_SETTINGS -> ACTION_WIRELESS_SETTINGS -> ACTION_DISPLAY_SETTINGS.
  Future<OpenCastSettingsResult> openCastSettings() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return const OpenCastSettingsResult(
        opened: false,
        errorMessage:
            'La duplicación de pantalla mediante ajustes del sistema solo está disponible en Android.',
      );
    }
    try {
      final res = await _platform.invokeMethod<dynamic>('openCastSettings');
      final type = res is String ? res : (res == true ? 'cast' : null);
      if (type == 'display') {
        return const OpenCastSettingsResult(
          opened: true,
          target: CastSettingsTarget.display,
        );
      } else if (type == 'wireless') {
        return const OpenCastSettingsResult(
          opened: true,
          target: CastSettingsTarget.wireless,
        );
      } else if (type == 'cast' || res == true) {
        return const OpenCastSettingsResult(
          opened: true,
          target: CastSettingsTarget.cast,
        );
      }
      return OpenCastSettingsResult.unavailable;
    } on PlatformException catch (e) {
      return OpenCastSettingsResult(
        opened: false,
        errorMessage:
            e.message ?? OpenCastSettingsResult.unavailable.errorMessage,
      );
    } catch (_) {
      return OpenCastSettingsResult.unavailable;
    }
  }

  Future<void> disconnect() async {
    if (!_available) return;
    await GoogleCastSessionManager.instance.endSessionAndStopCasting();
  }

  static const directMediaExtensions = <String>[
    '.m3u8',
    '.mpd',
    '.mp4',
    '.m4v',
    '.mov',
    '.webm',
    '.mkv',
    '.ts',
    '.flv',
    '.avi',
    '.mp3',
    '.aac',
    '.ogg',
  ];

  static const _knownEmbedDomains = <String>[
    'voe.sx',
    'eugenemakedraw.com',
    'niramirus.com',
  ];

  static const _knownEmbedSecondLevelLabels = <String>[
    'streamwish',
    'vidhide',
    'vidhidepro',
    'vidhidepre',
    'filemoon',
    'dood',
    'doodstream',
    'streamtape',
    'mixdrop',
    'upstream',
    'mp4upload',
    'streamlare',
  ];

  /// Determina si [url] es un enlace web/embed en lugar de un stream multimedia directo.
  static bool isEmbedStreamUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      return false;
    }
    final path = uri.path.toLowerCase();
    return !directMediaExtensions.any(path.endsWith);
  }

  /// Devuelve true si la URL pertenece a un host embed conocido
  /// (VOE, Streamwish, Vidhide, Filemoon, Dood, Streamtape, etc.).
  /// Compara etiquetas reales del hostname, subdominios o sufijos válidos,
  /// evitando falsos positivos por coincidencias parciales (como evilstreamwish.com).
  static bool isKnownEmbedHost(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasAuthority) return false;
    final host = uri.host.toLowerCase();

    for (final domain in _knownEmbedDomains) {
      if (host == domain || host.endsWith('.$domain')) {
        return true;
      }
    }

    final labels = host.split('.');
    if (labels.length < 2) return false;

    // Detectar si los dos últimos componentes forman un TLD compuesto (ej. co.uk, com.ar)
    final tld2 = '${labels[labels.length - 2]}.${labels[labels.length - 1]}';
    const twoPartTlds = <String>{
      'co.uk',
      'com.ar',
      'com.br',
      'com.mx',
      'co.nz',
      'com.au',
    };

    final sldIndex = twoPartTlds.contains(tld2)
        ? labels.length - 3
        : labels.length - 2;

    if (sldIndex >= 0) {
      final sldLabel = labels[sldIndex];
      if (_knownEmbedSecondLevelLabels.contains(sldLabel)) {
        return true;
      }
    }

    return false;
  }

  /// Devuelve true si la ruta de la URL corresponde a un patrón embed inequívoco
  /// (/embed/, /e/{id}, /v/{id}) y no es una extensión de video directa ni ruta IPTV.
  static bool hasUnequivocalEmbedPath(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      return false;
    }
    final path = uri.path.toLowerCase();
    if (directMediaExtensions.any(path.endsWith)) return false;
    final segments = uri.pathSegments;
    if (segments.isNotEmpty) {
      final first = segments.first.toLowerCase();
      if (first == 'embed' || first == 'e' || first == 'v') {
        return true;
      }
    }
    return path.contains('/embed/');
  }

  /// Determina si [url] es un proveedor o ruta embed conocido para la UI de la ficha.
  static bool isLikelyEmbedUrl(String url) =>
      isKnownEmbedHost(url) || hasUnequivocalEmbedPath(url);

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
  ///
  /// Excepción: Si la URL corresponde a un host embed conocido (VOE, Streamwish, etc.)
  /// o a una ruta embed inequívoca, no debe considerarse automáticamente MP4 sin extensión.
  static String? contentTypeFor(String value, {MediaType? mediaType}) {
    final path = Uri.tryParse(value)?.path.toLowerCase() ?? '';
    if (path.endsWith('.m3u8')) return 'application/x-mpegURL';
    if (path.endsWith('.mp4') || path.endsWith('.m4v')) return 'video/mp4';
    if (path.endsWith('.webm')) return 'video/webm';
    if (isKnownEmbedHost(value) || hasUnequivocalEmbedPath(value)) return null;
    if (mediaType == MediaType.live) return 'application/x-mpegURL';
    if (mediaType == MediaType.movie || mediaType == MediaType.series) {
      return 'video/mp4';
    }
    return null;
  }

  /// Evalúa si [streamUrl] puede enviarse por Chromecast directo o si presenta
  /// bloqueos técnicos (cabeceras privadas, visor web, formato incompatible).
  static StreamBlockInfo? checkStreamBlocked({
    required String streamUrl,
    MediaType? mediaType,
    String? userAgent,
    bool requiresHeaders = false,
    bool isEmbedOrWebView = false,
  }) {
    if (isEmbedOrWebView || isKnownEmbedHost(streamUrl) || hasUnequivocalEmbedPath(streamUrl)) {
      return const StreamBlockInfo(
        reason: StreamBlockReason.webViewOrEmbed,
        explanation:
            'Este servidor se reproduce mediante visor web y no se puede transmitir directamente por Chromecast.',
        isHeaderOrWebView: true,
      );
    }
    if (requiresHeaders || needsUnsupportedHeaders(userAgent)) {
      return const StreamBlockInfo(
        reason: StreamBlockReason.requiresHeaders,
        explanation:
            'Este servidor exige cabeceras personalizadas (User-Agent o Referer) y el receptor predeterminado de Chromecast no permite enviarlas, por lo que el televisor rechazaría el vídeo.',
        isHeaderOrWebView: true,
      );
    }
    if (!isNetworkUrl(streamUrl)) {
      return const StreamBlockInfo(
        reason: StreamBlockReason.invalidUrl,
        explanation:
            'La dirección del servidor no es una URL de red válida para Chromecast.',
        isHeaderOrWebView: false,
      );
    }
    if (contentTypeFor(streamUrl, mediaType: mediaType) == null) {
      return const StreamBlockInfo(
        reason: StreamBlockReason.unsupportedFormat,
        explanation:
            'Este servidor no expone una URL HLS (.m3u8) ni MP4, que son los formatos que acepta Chromecast.',
        isHeaderOrWebView: false,
      );
    }
    return null;
  }
}
