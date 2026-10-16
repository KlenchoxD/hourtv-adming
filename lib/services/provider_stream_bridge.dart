import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'subtitles/hourtv_subtitle_track.dart';

typedef NativeResolvedStream = ({
  String url,
  Map<String, String> headers,
  VideoFormat? formatHint,
  List<HourTvSubtitleTrack> subtitleTracks,
});

class MoonGetterResolution {
  final bool recognized;
  final NativeResolvedStream? stream;
  final bool retryableFailure;

  const MoonGetterResolution({
    required this.recognized,
    this.stream,
    this.retryableFailure = false,
  });
}

/// Resolves the normal provider page; playback remains in the native player.
class ProviderStreamBridge {
  static const _channel = MethodChannel('hourtv/provider_stream');
  static const _moonGetterChannel = MethodChannel('hourtv/moongetter');
  static int _nextResolverRequestId = 0;

  static int newResolverRequestId() => ++_nextResolverRequestId;

  /// Unknown hosts are reported separately from recognized hosts that failed.
  /// The latter should advance to the next catalog source without retrying the
  /// same page through slower generic extractors.
  static Future<MoonGetterResolution?> resolveMoonGetter(
    String url, {
    int? requestId,
  }) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
    try {
      final id = requestId ?? newResolverRequestId();
      final result = await _moonGetterChannel.invokeMapMethod<String, dynamic>(
        'resolve',
        {'url': url, 'requestId': id},
      );
      return switch (result?['status']) {
        'unsupported' => const MoonGetterResolution(recognized: false),
        'failed' => MoonGetterResolution(
          recognized: true,
          retryableFailure: result?['retryable'] == true,
        ),
        'resolved' => MoonGetterResolution(
          recognized: true,
          stream: _decodeSource(result),
        ),
        'cancelled' => null,
        _ => null,
      };
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  static Future<void> cancelMoonGetter(int requestId) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _moonGetterChannel.invokeMethod<void>('cancel', {
        'requestId': requestId,
      });
    } on PlatformException {
      // Cancellation is best-effort; the native resolver also has a hard cap.
    } on MissingPluginException {
      // Older app builds do not expose this channel.
    }
  }

  static Future<
    ({
      String url,
      Map<String, String> headers,
      VideoFormat? formatHint,
      List<HourTvSubtitleTrack> subtitleTracks,
    })?
  >
  resolve(String url, {int? requestId}) =>
      _resolve(_channel, url, requestId: requestId ?? newResolverRequestId());

  static Future<void> cancelResolver(int requestId) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _channel.invokeMethod<void>('cancel', {'requestId': requestId});
    } on PlatformException {
      // The resolver may already have completed or timed out.
    } on MissingPluginException {
      // Older app builds do not expose request-scoped cancellation.
    }
  }

  static Future<
    ({
      String url,
      Map<String, String> headers,
      VideoFormat? formatHint,
      List<HourTvSubtitleTrack> subtitleTracks,
    })?
  >
  resolveYtDlp(String url, {int? requestId}) => _resolve(
    const MethodChannel('hourtv/yt_dlp'),
    url,
    requestId: requestId ?? newResolverRequestId(),
  );

  static Future<void> cancelYtDlp(int requestId) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await const MethodChannel(
        'hourtv/yt_dlp',
      ).invokeMethod<void>('cancel', {'requestId': requestId});
    } on PlatformException {
      // The native resolver may already have returned or timed out.
    } on MissingPluginException {
      // Older app builds do not expose request-scoped cancellation.
    }
  }

  static Future<
    ({
      String url,
      Map<String, String> headers,
      VideoFormat? formatHint,
      List<HourTvSubtitleTrack> subtitleTracks,
    })?
  >
  _resolve(MethodChannel channel, String url, {int? requestId}) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
    try {
      final arguments = <String, Object?>{'url': url};
      if (requestId != null) arguments['requestId'] = requestId;
      final result = await channel.invokeMapMethod<String, dynamic>(
        'resolve',
        arguments,
      );
      return _decodeSource(result);
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  static NativeResolvedStream? _decodeSource(Map<String, dynamic>? result) {
    final rawUrl = result?['url'];
    if (rawUrl is! String) return null;
    final uri = Uri.tryParse(rawUrl);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      return null;
    }
    final raw = result?['headers'];
    final headers = <String, String>{};
    const allowedMediaHeaders = {'user-agent', 'referer', 'origin', 'accept'};
    if (raw is Map) {
      for (final entry in raw.entries) {
        if (entry.key is String && entry.value is String) {
          final key = entry.key as String;
          final value = entry.value as String;
          if (key.contains(RegExp(r'[\r\n:]')) ||
              value.contains(RegExp(r'[\r\n]')) ||
              !allowedMediaHeaders.contains(key.toLowerCase())) {
            continue;
          }
          headers[key] = value;
        }
      }
    }
    final formatHint = switch (result?['formatHint']) {
      'hls' => VideoFormat.hls,
      'dash' => VideoFormat.dash,
      'ss' => VideoFormat.ss,
      _ => null,
    };
    return (
      url: uri.toString(),
      headers: Map<String, String>.unmodifiable(headers),
      formatHint: formatHint,
      subtitleTracks: _decodeSubtitleTracks(result?['subtitles']),
    );
  }

  static List<HourTvSubtitleTrack> _decodeSubtitleTracks(dynamic raw) {
    if (raw is! List) return const [];
    const allowedHeaders = {'user-agent', 'referer', 'origin', 'accept'};
    final tracks = <HourTvSubtitleTrack>[];
    final seenUrls = <String>{};
    for (final item in raw.take(12)) {
      if (item is! Map) continue;
      final rawUrl = item['url'];
      if (rawUrl is! String) continue;
      final uri = Uri.tryParse(rawUrl);
      if (uri == null ||
          uri.scheme != 'https' ||
          uri.host.isEmpty ||
          uri.userInfo.isNotEmpty) {
        continue;
      }

      final rawLanguage = item['language'] is String
          ? item['language'] as String
          : 'und';
      if (rawLanguage.contains(RegExp(r'[\r\n]')) ||
          rawLanguage != rawLanguage.trim() ||
          !RegExp(r'^[A-Za-z0-9_-]{1,32}$').hasMatch(rawLanguage)) {
        continue;
      }
      final language = rawLanguage;
      final extension = item['ext'] is String
          ? (item['ext'] as String).toLowerCase()
          : null;
      final format = switch (extension) {
        'vtt' || 'webvtt' => SubtitleFormat.vtt,
        'srt' || 'subrip' => SubtitleFormat.srt,
        'ass' => SubtitleFormat.ass,
        _ => null,
      };
      if (format == null) continue;
      if (!seenUrls.add(uri.toString())) continue;

      final requiredHeaders = <String, String>{};
      final rawHeaders = item['headers'];
      if (rawHeaders is Map) {
        for (final entry in rawHeaders.entries) {
          if (entry.key is! String || entry.value is! String) continue;
          final key = entry.key as String;
          final value = entry.value as String;
          if (key.contains(RegExp(r'[\r\n:]')) ||
              value.contains(RegExp(r'[\r\n]')) ||
              !allowedHeaders.contains(key.toLowerCase())) {
            continue;
          }
          requiredHeaders[key] = value;
        }
      }

      tracks.add(
        HourTvSubtitleTrack(
          id: 'extractor:$language:${tracks.length}',
          label: language,
          languageCode: language,
          url: uri.toString(),
          format: format,
          sourceId: 'local-extractor',
          requiredHeaders: Map<String, String>.unmodifiable(requiredHeaders),
          isDefault: item['isDefault'] == true,
        ),
      );
    }
    return List.unmodifiable(tracks);
  }
}
