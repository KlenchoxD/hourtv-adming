import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'supabase_bootstrap.dart';

class TemporaryPlaybackSource {
  const TemporaryPlaybackSource(this.url, this.headers, this.format);
  final String url;
  final Map<String, String> headers;
  final String format;
}

class TemporaryPlaybackException implements Exception {
  const TemporaryPlaybackException(this.code);
  final String code;
  @override
  String toString() => 'TemporaryPlaybackException($code)';
}

/// Requests a fresh ticket just before native playback/recovery. Does not create
/// accounts, change the signed-in profile, persist provider URLs or ask for codes.
class TemporaryPlaybackLinks {
  TemporaryPlaybackLinks({
    required String gatewayOrigin,
    http.Client? client,
    Map<String, String> Function()? sessionHeaders,
  }) : _origin = _parseOrigin(gatewayOrigin),
       _client = client ?? http.Client(),
       _sessionHeaders = sessionHeaders ?? (() => const {});

  static final instance = TemporaryPlaybackLinks(
    gatewayOrigin: const String.fromEnvironment(
      'HOURTV_PLAYBACK_GATEWAY_ORIGIN',
    ),
    sessionHeaders: () {
      final token =
          SupabaseBootstrap.instance.client?.auth.currentSession?.accessToken;
      return token == null ? const {} : {'Authorization': 'Bearer $token'};
    },
  );
  final Uri? _origin;
  final http.Client _client;
  final Map<String, String> Function() _sessionHeaders;
  final _inflight = <String, Future<TemporaryPlaybackSource>>{};

  static Uri? _parseOrigin(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        (uri.path.isNotEmpty && uri.path != '/') ||
        uri.hasQuery ||
        uri.hasFragment) {
      return null;
    }
    return uri;
  }

  String? _sourceId(String value) {
    final uri = Uri.tryParse(value);
    if (_origin == null ||
        uri == null ||
        uri.scheme != 'https' ||
        uri.origin != _origin.origin ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      return null;
    }
    return RegExp(
      r'^/source/([a-zA-Z0-9_-]{1,128})$',
    ).firstMatch(uri.path)?.group(1);
  }

  bool manages(String value) => _sourceId(value) != null;

  Future<TemporaryPlaybackSource> resolve(String value) {
    final id = _sourceId(value);
    if (id == null) {
      return Future.error(
        const TemporaryPlaybackException('untrusted_gateway'),
      );
    }
    return _inflight.putIfAbsent(id, () async {
      try {
        return await _request(id);
      } finally {
        _inflight.remove(id);
      }
    });
  }

  Future<TemporaryPlaybackSource> _request(String id) async {
    try {
      final request = http.Request('POST', _origin!.resolve('/v1/tickets/$id'))
        ..followRedirects = false
        ..headers.addAll(_sessionHeaders());
      final response = await _client
          .send(request)
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) {
        await response.stream.timeout(const Duration(seconds: 8)).drain<void>();
        throw TemporaryPlaybackException(
          response.statusCode == 401
              ? 'playback_session_required'
              : 'gateway_unavailable',
        );
      }
      final bytes = <int>[];
      await for (final part in response.stream.timeout(
        const Duration(seconds: 8),
      )) {
        if (bytes.length + part.length > 16384) {
          throw const TemporaryPlaybackException('invalid_ticket');
        }
        bytes.addAll(part);
      }
      final data = jsonDecode(utf8.decode(bytes));
      if (data is! Map ||
          !['protected', 'direct'].contains(data['mode']) ||
          !['hls', 'mp4'].contains(data['format']) ||
          data['url'] is! String ||
          data['headers'] is! Map) {
        throw const TemporaryPlaybackException('invalid_ticket');
      }
      final target = Uri.tryParse(data['url'] as String);
      if (target == null ||
          target.scheme != 'https' ||
          target.host.isEmpty ||
          target.userInfo.isNotEmpty ||
          target.hasFragment) {
        throw const TemporaryPlaybackException('invalid_ticket');
      }
      if (data['mode'] == 'protected') {
        final expires = data['expiresAt'], server = data['serverTime'];
        if (target.origin != _origin.origin ||
            !RegExp(r'^/media/[A-Za-z0-9_-]+$').hasMatch(target.path) ||
            target.hasQuery ||
            expires is! int ||
            server is! int ||
            expires <= server ||
            expires - server > const Duration(hours: 24).inMilliseconds ||
            (data['headers'] as Map).isNotEmpty) {
          throw const TemporaryPlaybackException('invalid_ticket');
        }
      }
      final headers = <String, String>{};
      for (final entry in (data['headers'] as Map).entries) {
        if (entry.key is! String ||
            entry.value is! String ||
            !RegExp(r'^[A-Za-z0-9-]+$').hasMatch(entry.key as String) ||
            (entry.value as String).contains(RegExp(r'[\r\n]'))) {
          throw const TemporaryPlaybackException('invalid_ticket');
        }
        headers[entry.key as String] = entry.value as String;
      }
      return TemporaryPlaybackSource(
        target.toString(),
        Map.unmodifiable(headers),
        data['format'] as String,
      );
    } on TemporaryPlaybackException {
      rethrow;
    } catch (_) {
      throw const TemporaryPlaybackException('gateway_unavailable');
    }
  }
}
