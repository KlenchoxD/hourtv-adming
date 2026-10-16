import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:streamtv/services/embed_resolver.dart';

// An explicit, opt-in live probe, not a deterministic CI regression test.
// Uses the existing Dart resolver with real HTTPS. Native-only resolvers are
// MoonGetter's observed native miss is simulated so this isolates the VOE
// fallthrough + static route, not the whole APK or native provider library.
// No account API/token, browser automation, ads removal or challenge bypass.
class _DiagnosticNetwork extends HttpOverrides {}

class _ProbeFailure implements Exception {
  const _ProbeFailure(this.stage, [this.status]);
  final String stage;
  final int? status;
}

Future<String> _playlist(
  http.Client client,
  Uri uri,
  Map<String, String> headers,
  String stage,
) async {
  if (uri.scheme != 'https' || uri.userInfo.isNotEmpty) {
    throw _ProbeFailure('$stage-url');
  }
  final response = await client.send(
    http.Request('GET', uri)..headers.addAll(headers),
  );
  if (response.statusCode != 200) {
    await response.stream.listen((_) {}).cancel();
    throw _ProbeFailure(stage, response.statusCode);
  }
  final bytes = <int>[];
  await for (final chunk in response.stream.timeout(
    const Duration(seconds: 15),
  )) {
    bytes.addAll(chunk);
    if (bytes.length > 2 * 1024 * 1024) throw _ProbeFailure('$stage-size');
  }
  final body = utf8.decode(bytes);
  if (!body.trimLeft().startsWith('#EXTM3U')) {
    throw _ProbeFailure('$stage-format');
  }
  debugPrint(
    'VOE_LIVE ${jsonEncode({'stage': stage, 'http': response.statusCode, 'hls': true})}',
  );
  return body;
}

Future<void> _probe(String embed) async {
  final client = http.Client();
  try {
    final result = await EmbedResolver.resolveForPlayback(
      embed,
      client: client,
    );
    final source = result.stream;
    if (source == null) throw const _ProbeFailure('resolve');
    debugPrint(
      'VOE_LIVE ${jsonEncode({'stage': 'resolve', 'source_obtained': true, 'header_names': source.headers.keys.toList()..sort(), 'account_api_used': false, 'premium_login_used': false})}',
    );
    var uri = Uri.parse(source.url);
    var body = await _playlist(client, uri, source.headers, 'master');
    final codecs = RegExp(
      r'CODECS="([^"]+)"',
    ).allMatches(body).map((match) => match.group(1)).toSet().toList();
    debugPrint(
      'VOE_LIVE ${jsonEncode({'stage': 'declared-codecs', 'codecs': codecs})}',
    );
    for (
      var depth = 0;
      body.contains('#EXT-X-STREAM-INF:') && depth < 3;
      depth++
    ) {
      final lines = const LineSplitter().convert(body);
      String? child;
      for (var i = 0; i < lines.length - 1; i++) {
        if (!lines[i].startsWith('#EXT-X-STREAM-INF:')) continue;
        for (var j = i + 1; j < lines.length; j++) {
          final line = lines[j].trim();
          if (line.isNotEmpty && !line.startsWith('#')) {
            child = line;
            break;
          }
        }
        if (child != null) break;
      }
      if (child == null) throw const _ProbeFailure('variant-reference');
      uri = uri.resolve(child);
      body = await _playlist(client, uri, source.headers, 'variant');
    }
    final media = const LineSplitter()
        .convert(body)
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty && !line.startsWith('#'))
        .toList();
    if (media.isEmpty || !body.contains('#EXTINF:')) {
      throw const _ProbeFailure('media-playlist');
    }
    final duration = RegExp(r'#EXTINF:([0-9.]+)')
        .allMatches(body)
        .fold<double>(0, (sum, match) => sum + double.parse(match.group(1)!));
    debugPrint(
      'VOE_LIVE ${jsonEncode({'stage': 'media-playlist', 'segments': media.length, 'declared_duration_seconds': duration.round(), 'end_list': body.contains('#EXT-X-ENDLIST')})}',
    );
    final segment = uri.resolve(media.first);
    if (segment.scheme != 'https' || segment.userInfo.isNotEmpty) {
      throw const _ProbeFailure('segment-url');
    }
    final request = http.Request('GET', segment)
      ..headers.addAll(source.headers)
      ..headers['Range'] = 'bytes=0-65535';
    final response = await client.send(request);
    if (response.statusCode != 200 && response.statusCode != 206) {
      await response.stream.listen((_) {}).cancel();
      throw _ProbeFailure('segment', response.statusCode);
    }
    // Only the first chunk; first cancels the subscription. Never download the
    // movie or print the signed URL, headers, cookies or raw provider bodies.
    final first = await response.stream.first.timeout(
      const Duration(seconds: 15),
    );
    if (first.isEmpty) throw const _ProbeFailure('empty-segment');
    debugPrint(
      'VOE_LIVE ${jsonEncode({'stage': 'segment', 'http': response.statusCode, 'received_bytes': first.length, 'native_playback_verified': false})}',
    );
  } finally {
    client.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const embed = String.fromEnvironment('HOURTV_LIVE_VOE_URL');
  test(
    'owned VOE source: existing static resolver → real HLS → segment',
    () async {
      final uri = Uri.parse(embed);
      expect(uri.scheme, 'https');
      expect(uri.host, 'voe.sx');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      const moonGetter = MethodChannel('hourtv/moongetter');
      const ytDlp = MethodChannel('hourtv/yt_dlp');
      messenger.setMockMethodCallHandler(
        moonGetter,
        (call) async =>
            call.method == 'resolve' ? {'status': 'failed'} : null,
      );
      messenger.setMockMethodCallHandler(ytDlp, (_) async => null);
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        await HttpOverrides.runWithHttpOverrides(
          () => _probe(embed).timeout(const Duration(seconds: 70)),
          _DiagnosticNetwork(),
        );
      } on _ProbeFailure catch (error) {
        fail(
          'Live probe failed at ${error.stage}; HTTP=${error.status ?? 'n/a'}',
        );
      } catch (error) {
        fail(
          'Live probe failed: ${error.runtimeType}; upstream details redacted',
        );
      } finally {
        messenger.setMockMethodCallHandler(moonGetter, null);
        messenger.setMockMethodCallHandler(ytDlp, null);
        debugDefaultTargetPlatformOverride = null;
      }
    },
    skip: embed.isEmpty
        ? 'Opt in with HOURTV_LIVE_VOE_URL; requires network.'
        : false,
    timeout: const Timeout(Duration(seconds: 80)),
  );
}
