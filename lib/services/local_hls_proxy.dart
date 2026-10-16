import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;

class HlsUpstreamException implements Exception {
  const HlsUpstreamException(this.statusCode);
  final int statusCode;
}

enum _ResourceKind { playlist, media, key, subtitle }

class _Resource {
  const _Resource(this.uri, this.kind);
  final Uri uri;
  final _ResourceKind kind;
}

/// A playback-scoped, streaming bridge. Only resources registered from an HLS
/// playlist are addressable; clients cannot supply an upstream URL themselves.
/// Upstream credentials stay in memory and never appear in the local URLs.
class LocalHlsProxy {
  LocalHlsProxy({
    http.Client? client,
    this.cookiesFor,
    this.timeout = const Duration(seconds: 12),
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final Duration timeout;
  final Future<String?> Function(Uri)? cookiesFor;
  Future<String?> Function(Uri)? _activeCookiesFor;
  final _resources = <String, _Resource>{};
  final _paths = <String, String>{};
  final _session = List.generate(
    16,
    (_) => Random.secure().nextInt(256),
  ).map((v) => v.toRadixString(16).padLeft(2, '0')).join();
  HttpServer? _server;
  Uri? _origin;
  Map<String, String> _headers = const {};
  String? _initialBody;
  bool _closed = false;

  Future<Uri> start(
    Uri manifest, {
    Map<String, String> headers = const {},
    Future<String?> Function(Uri)? cookiesFor,
  }) async {
    if (_closed || _server != null) {
      throw StateError('HLS session already used');
    }
    _validate(manifest);
    _origin = manifest;
    _activeCookiesFor = cookiesFor ?? this.cookiesFor;
    _headers = Map.unmodifiable(
      headers.map((key, value) => MapEntry(key.toLowerCase(), value)),
    );
    try {
      final response = await _fetch(manifest);
      if (response.statusCode != HttpStatus.ok) {
        await response.stream.drain<void>();
        throw HlsUpstreamException(response.statusCode);
      }
      final body = await _readPlaylist(response);
      if (_closed) throw StateError('HLS session closed');
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      if (_closed) {
        await server.close(force: true);
        throw StateError('HLS session closed');
      }
      _server = server;
      final rootPath = '/$_session/stream.m3u8';
      final effectiveUri = response.request?.url ?? manifest;
      _resources[rootPath] = _Resource(effectiveUri, _ResourceKind.playlist);
      _paths['playlist:$effectiveUri'] = rootPath;
      _initialBody = _rewrite(body, effectiveUri);
      server.listen(
        (request) => unawaited(_serve(request)),
        onError: (Object _) {},
      );
      return _local(rootPath);
    } catch (_) {
      await close();
      rethrow;
    }
  }

  static void _validate(Uri uri) {
    if (uri.scheme != 'https' || uri.host.isEmpty || uri.userInfo.isNotEmpty) {
      throw const FormatException('HLS requires a secure upstream URL');
    }
  }

  Uri _local(String path) =>
      Uri(scheme: 'http', host: '127.0.0.1', port: _server!.port, path: path);

  Uri _resolve(Uri parent, String reference) {
    var target = parent.resolve(reference.trim());
    _validate(target);
    // These are the provider's observed session parameters, not every query
    // value. Never attach them to another origin or overwrite a child token.
    if (target.origin == parent.origin) {
      final additions = <String>[];
      for (final key in const ['k', 'kx']) {
        if (!target.queryParameters.containsKey(key)) {
          for (final value
              in parent.queryParametersAll[key] ?? const <String>[]) {
            additions.add(
              '${Uri.encodeQueryComponent(key)}=${Uri.encodeQueryComponent(value)}',
            );
          }
        }
      }
      if (additions.isNotEmpty) {
        target = target.replace(
          query: [if (target.hasQuery) target.query, ...additions].join('&'),
        );
      }
    }
    return target;
  }

  String _register(Uri parent, String reference, _ResourceKind kind) {
    final target = _resolve(parent, reference);
    final key = '${kind.name}:$target';
    final path = _paths.putIfAbsent(key, () {
      final extension = switch (kind) {
        _ResourceKind.playlist => '.m3u8',
        _ResourceKind.key => '.key',
        _ResourceKind.subtitle => '.vtt',
        _ResourceKind.media =>
          target.path.endsWith('.woff')
              ? '.mp4'
              : target.path.endsWith('.woff2')
              ? '.m4s'
              : target.path.endsWith('.ts')
              ? '.ts'
              : '.mp4',
      };
      final value = '/$_session/r/${_resources.length}$extension';
      _resources[value] = _Resource(target, kind);
      return value;
    });
    return _local(path).toString();
  }

  String _rewrite(String body, Uri parent) {
    if (!body.trimLeft().startsWith('#EXTM3U')) {
      throw const FormatException('Upstream is not an HLS playlist');
    }
    final output = <String>[];
    var nextIsPlaylist = false;
    final uriAttribute = RegExp(r'\bURI="([^"]+)"');
    for (final raw in const LineSplitter().convert(body)) {
      final line = raw.trim();
      if (line.isEmpty) {
        output.add(raw);
        continue;
      }
      if (!line.startsWith('#')) {
        output.add(
          _register(
            parent,
            line,
            nextIsPlaylist ? _ResourceKind.playlist : _ResourceKind.media,
          ),
        );
        nextIsPlaylist = false;
        continue;
      }
      if (line.startsWith('#EXT-X-STREAM-INF:')) nextIsPlaylist = true;
      final kind =
          line.startsWith('#EXT-X-KEY:') ||
              line.startsWith('#EXT-X-SESSION-KEY:')
          ? _ResourceKind.key
          : line.startsWith('#EXT-X-MEDIA:') ||
                line.startsWith('#EXT-X-I-FRAME-STREAM-INF:') ||
                line.startsWith('#EXT-X-RENDITION-REPORT:')
          ? _ResourceKind.playlist
          : _ResourceKind.media;
      output.add(
        raw.replaceAllMapped(uriAttribute, (match) {
          final reference = match.group(1)!;
          final resourceKind =
              kind == _ResourceKind.playlist &&
                  reference.split('?').first.endsWith('.vtt')
              ? _ResourceKind.subtitle
              : kind;
          return 'URI="${_register(parent, reference, resourceKind)}"';
        }),
      );
    }
    return '${output.join('\n')}\n';
  }

  Future<http.StreamedResponse> _fetch(
    Uri uri, {
    String method = 'GET',
    Map<String, String> requestHeaders = const {},
  }) async {
    var target = uri;
    for (var hop = 0; hop <= 4; hop++) {
      if (_closed) throw StateError('HLS session closed');
      _validate(target);
      final headers = Map<String, String>.of(_headers);
      if (target.origin != _origin!.origin) {
        headers.remove('cookie');
        headers.remove('authorization');
      }
      final cookiesFor = _activeCookiesFor;
      if (cookiesFor != null) {
        headers.remove('cookie');
        final cookies = await cookiesFor(target).timeout(timeout);
        if (cookies?.isNotEmpty == true) headers['cookie'] = cookies!;
      }
      final request = http.Request(method, target)
        ..followRedirects = false
        ..headers.addAll(headers)
        ..headers.addAll(requestHeaders)
        ..headers['accept-encoding'] = 'identity';
      final response = await _client.send(request).timeout(timeout);
      final location = response.headers['location'];
      if (![301, 302, 303, 307, 308].contains(response.statusCode) ||
          location == null) {
        return http.StreamedResponse(
          response.stream,
          response.statusCode,
          request: request,
          headers: response.headers,
          contentLength: response.contentLength,
          reasonPhrase: response.reasonPhrase,
          isRedirect: response.isRedirect,
          persistentConnection: response.persistentConnection,
        );
      }
      await response.stream.drain<void>().timeout(timeout);
      target = target.resolve(location);
    }
    throw const HttpException('Too many HLS redirects');
  }

  Future<String> _readPlaylist(http.StreamedResponse response) async {
    final bytes = <int>[];
    await for (final chunk in response.stream.timeout(timeout)) {
      if (bytes.length + chunk.length > 2 * 1024 * 1024) {
        throw const FormatException('HLS playlist exceeds size limit');
      }
      bytes.addAll(chunk);
    }
    final body = utf8.decode(bytes).replaceFirst('\ufeff', '');
    if (!body.trimLeft().startsWith('#EXTM3U')) {
      throw const FormatException('Upstream is not an HLS playlist');
    }
    return body;
  }

  Future<void> _serve(HttpRequest request) async {
    final response = request.response;
    final resource = _resources[request.uri.path];
    try {
      if (_closed || resource == null) {
        response.statusCode = HttpStatus.notFound;
      } else if (!['GET', 'HEAD'].contains(request.method)) {
        response.statusCode = HttpStatus.methodNotAllowed;
      } else if (resource.kind == _ResourceKind.playlist) {
        var body = request.uri.path.endsWith('/stream.m3u8')
            ? _initialBody
            : null;
        if (request.method != 'HEAD') _initialBody = null;
        if (body == null) {
          final upstream = await _fetch(resource.uri);
          if (upstream.statusCode != HttpStatus.ok) {
            response.statusCode = upstream.statusCode;
            await upstream.stream.drain<void>();
            await response.close();
            return;
          }
          body = _rewrite(
            await _readPlaylist(upstream),
            upstream.request?.url ?? resource.uri,
          );
        }
        response.headers.set(
          HttpHeaders.contentTypeHeader,
          'application/vnd.apple.mpegurl; charset=utf-8',
        );
        response.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
        if (request.method != 'HEAD') response.write(body);
      } else {
        final upstream = await _fetch(
          resource.uri,
          method: request.method,
          requestHeaders: {
            for (final key in const ['range', 'if-range'])
              if (request.headers.value(key) case final String value)
                key: value,
          },
        );
        response.statusCode = upstream.statusCode;
        for (final key in const [
          'content-range',
          'accept-ranges',
          'etag',
          'last-modified',
        ]) {
          final value = upstream.headers[key];
          if (value != null) response.headers.set(key, value);
        }
        if (upstream.contentLength != null &&
            !upstream.headers.containsKey('content-encoding')) {
          response.contentLength = upstream.contentLength!;
        }
        final disguised =
            resource.uri.path.endsWith('.woff') ||
            resource.uri.path.endsWith('.woff2');
        response.headers.set(
          HttpHeaders.contentTypeHeader,
          disguised
              ? 'video/mp4'
              : upstream.headers['content-type'] ??
                    (resource.kind == _ResourceKind.subtitle
                        ? 'text/vtt'
                        : 'application/octet-stream'),
        );
        await response.addStream(upstream.stream.timeout(timeout));
      }
      await response.close();
    } catch (error) {
      try {
        response.statusCode = error is TimeoutException
            ? HttpStatus.gatewayTimeout
            : HttpStatus.badGateway;
        await response.close();
      } catch (_) {
        response
            .detachSocket()
            .then((socket) => socket.destroy())
            .catchError((Object _) {});
      }
    }
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _client.close();
    final server = _server;
    _server = null;
    _initialBody = null;
    _resources.clear();
    _paths.clear();
    await server?.close(force: true);
  }
}
