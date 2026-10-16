import 'package:video_player/video_player.dart';

/// Returns an explicit Android format hint only when the source identifies an
/// adaptive manifest unambiguously. Ordinary files remain on platform
/// auto-detection, which is more reliable than forcing a guessed container.
VideoFormat? videoFormatHintFor(
  Uri uri, {
  String? contentType,
  String? formatHint,
}) {
  if ((uri.scheme != 'https' && uri.scheme != 'http') ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty) {
    return null;
  }

  switch (formatHint?.trim().toLowerCase()) {
    case 'hls':
      return VideoFormat.hls;
    case 'dash':
      return VideoFormat.dash;
    case 'ss':
    case 'smoothstreaming':
      return VideoFormat.ss;
  }

  final mimeType = contentType?.split(';').first.trim().toLowerCase();
  switch (mimeType) {
    case 'application/vnd.apple.mpegurl':
    case 'application/x-mpegurl':
    case 'audio/mpegurl':
    case 'audio/x-mpegurl':
      return VideoFormat.hls;
    case 'application/dash+xml':
      return VideoFormat.dash;
    case 'application/vnd.ms-sstr+xml':
      return VideoFormat.ss;
  }

  final path = uri.path.toLowerCase();
  if (path.endsWith('.m3u8')) return VideoFormat.hls;
  if (path.endsWith('.mpd')) return VideoFormat.dash;
  if (path.endsWith('.ism/manifest') || path.endsWith('.isml/manifest')) {
    return VideoFormat.ss;
  }
  return null;
}
