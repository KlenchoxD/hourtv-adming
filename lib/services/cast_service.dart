import 'dart:async';
import 'dart:io';

import 'package:flutter_chrome_cast/flutter_chrome_cast.dart';

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
    if (!Platform.isAndroid) return false;
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
  }) async {
    if (!_available) throw StateError('Google Cast no está disponible.');
    final uri = Uri.parse(url);
    final contentType = contentTypeFor(url);
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

  static String? contentTypeFor(String value) {
    final path = Uri.tryParse(value)?.path.toLowerCase() ?? '';
    if (path.endsWith('.m3u8')) return 'application/x-mpegURL';
    if (path.endsWith('.mp4') || path.endsWith('.m4v')) return 'video/mp4';
    if (path.endsWith('.webm')) return 'video/webm';
    return null;
  }
}
