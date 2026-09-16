import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../models/channel.dart';
import 'hourtv_subtitle_track.dart';
import 'subtitle_controller.dart';

/// Descubre pistas explícitas del catálogo y las declaradas por un manifiesto
/// HLS maestro. No intenta reproducir playlists HLS segmentadas como si fueran
/// un archivo WebVTT único.
class SubtitleDiscoveryService {
  static const int maxManifestBytes = 256 * 1024;
  static const Duration timeout = Duration(seconds: 5);

  Future<List<HourTvSubtitleTrack>> discover({
    required Channel channel,
    required Uri activeUrl,
    String? selectedServerUrl,
    Map<String, String> activeHeaders = const {},
    http.Client? httpClient,
  }) async {
    final found = <HourTvSubtitleTrack>[
      ...channel.subtitleTracks,
      for (final server in channel.servers)
        if (server.url == (selectedServerUrl ?? activeUrl.toString()))
          ...server.subtitleTracks,
    ];

    if (_looksLikeHls(activeUrl)) {
      final client = httpClient ?? http.Client();
      try {
        final manifest = await _loadManifest(client, activeUrl, activeHeaders);
        if (manifest != null) {
          found.addAll(
            parseMasterManifest(
              manifest,
              baseUri: activeUrl,
              headers: activeHeaders,
            ),
          );
        }
      } finally {
        if (httpClient == null) client.close();
      }
    }

    final unique = <String, HourTvSubtitleTrack>{};
    for (final track in found) {
      final url = track.url?.trim();
      if (track.id.isEmpty || url == null || url.isEmpty) continue;
      unique.putIfAbsent(
        '${Uri.tryParse(url)?.normalizePath()}|${track.languageCode}',
        () => track,
      );
    }
    return List.unmodifiable(unique.values);
  }

  static bool _looksLikeHls(Uri uri) =>
      uri.path.toLowerCase().endsWith('.m3u8');

  Future<String?> _loadManifest(
    http.Client client,
    Uri uri,
    Map<String, String> headers,
  ) async {
    try {
      var current = uri;
      http.StreamedResponse? response;
      for (var redirects = 0; redirects <= 3; redirects++) {
        final request = http.Request('GET', current)
          ..followRedirects = false
          ..headers.addAll(
            SubtitleController.filterSafeHeaders(
              sourceHost: uri.host,
              targetUri: current,
              sourceHeaders: headers,
            ),
          );
        response = await client.send(request).timeout(timeout);
        if (response.statusCode < 300 || response.statusCode >= 400) break;
        final location = response.headers['location'];
        await response.stream.drain<void>();
        if (location == null || redirects == 3) return null;
        final next = current.resolve(location);
        if (next.scheme != 'http' && next.scheme != 'https') return null;
        current = next;
      }
      if (response == null || response.statusCode != 200) return null;
      final contentType = (response.headers['content-type'] ?? '')
          .toLowerCase();
      if (contentType.contains('text/html') ||
          contentType.contains('application/json')) {
        return null;
      }
      final bytes = <int>[];
      await for (final chunk in response.stream.timeout(timeout)) {
        bytes.addAll(chunk);
        if (bytes.length > maxManifestBytes) return null;
      }
      String decoded;
      try {
        decoded = utf8.decode(bytes, allowMalformed: false);
      } on FormatException {
        decoded = latin1.decode(bytes);
      }
      final text = decoded.trimLeft();
      return text.startsWith('#EXTM3U') ? text : null;
    } catch (_) {
      return null;
    }
  }

  static List<HourTvSubtitleTrack> parseMasterManifest(
    String manifest, {
    required Uri baseUri,
    Map<String, String> headers = const {},
  }) {
    final result = <HourTvSubtitleTrack>[];
    var index = 0;
    for (final rawLine in const LineSplitter().convert(manifest)) {
      final line = rawLine.trim();
      if (!line.startsWith('#EXT-X-MEDIA:')) continue;
      final attributes = _parseAttributes(
        line.substring('#EXT-X-MEDIA:'.length),
      );
      if (attributes['TYPE']?.toUpperCase() != 'SUBTITLES') continue;
      final rawUri = attributes['URI'];
      if (rawUri == null || rawUri.isEmpty) continue;
      final resolved = baseUri.resolve(rawUri);
      if (resolved.scheme != 'http' && resolved.scheme != 'https') continue;
      final isVtt = resolved.path.toLowerCase().endsWith('.vtt');
      final language = attributes['LANGUAGE']?.trim().toLowerCase();
      final label = attributes['NAME']?.trim();
      final characteristics =
          attributes['CHARACTERISTICS']?.toLowerCase() ?? '';
      result.add(
        HourTvSubtitleTrack(
          id: 'hls-${language ?? 'und'}-${index++}-${resolved.path.hashCode.abs()}',
          label: label?.isNotEmpty == true ? label! : (language ?? 'Subtítulo'),
          languageCode: language?.isNotEmpty == true ? language! : 'und',
          url: resolved.toString(),
          format: isVtt ? SubtitleFormat.vtt : SubtitleFormat.unsupported,
          provenance: SubtitleProvenance.hlsEmbedded,
          isHlsMediaPlaylist: !isVtt,
          requiredHeaders: Map.unmodifiable(headers),
          hearingImpaired: characteristics.contains(
            'transcribes-spoken-dialog',
          ),
          isForced: attributes['FORCED']?.toUpperCase() == 'YES',
          isDefault: attributes['DEFAULT']?.toUpperCase() == 'YES',
        ),
      );
    }
    return result;
  }

  static Map<String, String> _parseAttributes(String input) {
    final result = <String, String>{};
    final matcher = RegExp(r'''([A-Z0-9-]+)=("(?:[^"\\]|\\.)*"|[^,]*)''');
    for (final match in matcher.allMatches(input)) {
      var value = match.group(2) ?? '';
      if (value.length >= 2 && value.startsWith('"') && value.endsWith('"')) {
        value = value.substring(1, value.length - 1).replaceAll(r'\"', '"');
      }
      result[match.group(1)!] = value;
    }
    return result;
  }
}
