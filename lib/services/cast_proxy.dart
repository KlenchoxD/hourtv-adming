import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';

/// Puente HTTP en la red Wi-Fi para transmitir a un TV videos que exigen
/// cabeceras (Referer/User-Agent) o que no permiten CORS: el TV le pide cada
/// archivo al teléfono y este lo trae del servidor con esas cabeceras. Las
/// listas HLS se reescriben para que también los segmentos pasen por aquí.
///
/// Solo atiende URLs bajo un token aleatorio de la transmisión en curso.
class CastProxy {
  CastProxy._();

  static final CastProxy instance = CastProxy._();

  HttpServer? _server;
  String? _host;
  final _client = HttpClient()..connectionTimeout = const Duration(seconds: 15);

  // Una transmisión a la vez: un token nuevo invalida el anterior.
  String? _token;
  Map<String, String> _headers = const {};

  /// URL que el TV puede pedir para reproducir [url] con [headers].
  Future<String> urlFor(String url, Map<String, String> headers) async {
    await _ensureStarted();
    final random = Random.secure();
    _token = List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    _headers = Map.unmodifiable(headers);
    return _proxied(Uri.parse(url));
  }

  Future<void> _ensureStarted() async {
    // La IP se vuelve a leer: el teléfono pudo cambiar de red.
    _host = await lanAddress();
    if (_host == null) {
      throw StateError('Conéctate a una red Wi-Fi para transmitir.');
    }
    if (_server != null) return;
    final server = await HttpServer.bind(InternetAddress.anyIPv4, 0);
    _server = server;
    server.listen(
      (request) => unawaited(_handle(request)),
      onError: (_) {},
      onDone: () => _server = null,
    );
  }

  String _proxied(Uri target) {
    final encoded = base64Url.encode(utf8.encode(target.toString()));
    // La extensión al final ayuda a los TV que deciden el formato por ella.
    final ext = _extension(target.path);
    return 'http://$_host:${_server!.port}/$_token/$encoded$ext';
  }

  static String _extension(String path) {
    final match = RegExp(
      r'\.(m3u8|mp4|m4v|ts|m4s|aac|vtt|key|mkv|webm)$',
      caseSensitive: false,
    ).firstMatch(path);
    return match == null ? '' : '.${match.group(1)!.toLowerCase()}';
  }

  Future<void> _handle(HttpRequest request) async {
    final response = request.response;
    response.headers
      ..set('Access-Control-Allow-Origin', '*')
      ..set('Access-Control-Allow-Headers', 'Range, Content-Type')
      ..set('Access-Control-Expose-Headers', 'Content-Length, Content-Range');
    try {
      if (request.method == 'OPTIONS') {
        await response.close();
        return;
      }
      final target = _decode(request.uri.pathSegments);
      if (target == null) {
        response.statusCode = HttpStatus.notFound;
        await response.close();
        return;
      }
      await _forward(request, target);
    } catch (e) {
      debugPrint('[CAST] proxy ${e.runtimeType}');
      try {
        response.statusCode = HttpStatus.badGateway;
        await response.close();
      } catch (_) {}
    }
  }

  Uri? _decode(List<String> segments) {
    if (segments.length != 2 || segments[0] != _token) return null;
    var encoded = segments[1];
    final dot = encoded.indexOf('.');
    if (dot >= 0) encoded = encoded.substring(0, dot);
    try {
      final target = Uri.parse(utf8.decode(base64Url.decode(encoded)));
      return target.scheme == 'http' || target.scheme == 'https'
          ? target
          : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _forward(HttpRequest request, Uri target) async {
    final upstreamRequest = await _client.getUrl(target);
    _headers.forEach(upstreamRequest.headers.set);
    // Sin compresión: el cuerpo se reenvía tal cual con su Content-Length.
    upstreamRequest.headers.set(HttpHeaders.acceptEncodingHeader, 'identity');
    final range = request.headers.value(HttpHeaders.rangeHeader);
    if (range != null) {
      upstreamRequest.headers.set(HttpHeaders.rangeHeader, range);
    }
    final upstream = await upstreamRequest.close();
    final finalUrl = upstream.redirects.fold<Uri>(
      target,
      (url, redirect) => url.resolveUri(redirect.location),
    );
    final response = request.response;
    final type = upstream.headers.contentType?.mimeType.toLowerCase() ?? '';
    final isPlaylist =
        type.contains('mpegurl') ||
        finalUrl.path.toLowerCase().endsWith('.m3u8');

    if (!kReleaseMode) {
      debugPrint(
        '[CAST] proxy ${request.method} ${upstream.statusCode} $type '
        '${finalUrl.pathSegments.isEmpty ? '' : finalUrl.pathSegments.last}',
      );
    }
    response.statusCode = upstream.statusCode;
    if (isPlaylist && upstream.statusCode == HttpStatus.ok) {
      final text = await upstream.transform(utf8.decoder).join();
      final body = utf8.encode(rewritePlaylist(text, finalUrl, _proxied));
      response.headers
        ..set(HttpHeaders.contentTypeHeader, 'application/vnd.apple.mpegurl')
        ..set(HttpHeaders.cacheControlHeader, 'no-cache')
        ..contentLength = body.length;
      if (request.method != 'HEAD') response.add(body);
      await response.close();
      return;
    }

    for (final name in const [
      HttpHeaders.contentTypeHeader,
      HttpHeaders.contentLengthHeader,
      HttpHeaders.contentRangeHeader,
      HttpHeaders.acceptRangesHeader,
    ]) {
      final value = upstream.headers.value(name);
      if (value != null) response.headers.set(name, value);
    }
    // Varios TV DLNA (Samsung, LG) no reproducen sin estas cabeceras.
    response.headers
      ..set('transferMode.dlna.org', 'Streaming')
      ..set(
        'contentFeatures.dlna.org',
        'DLNA.ORG_OP=01;DLNA.ORG_CI=0;'
            'DLNA.ORG_FLAGS=01700000000000000000000000000000',
      );
    if (request.method == 'HEAD') {
      await upstream.drain<void>();
      await response.close();
      return;
    }
    await response.addStream(upstream);
    await response.close();
  }

  /// Reescribe una lista HLS para que cada URI (segmentos, variantes, claves,
  /// pistas) pase por [proxied].
  @visibleForTesting
  static String rewritePlaylist(
    String playlist,
    Uri base,
    String Function(Uri) proxied,
  ) {
    final uriAttr = RegExp(r'URI="([^"]+)"');
    return const LineSplitter()
        .convert(playlist)
        .map((line) {
          final trimmed = line.trim();
          if (trimmed.isEmpty) return line;
          if (!trimmed.startsWith('#')) {
            return proxied(base.resolve(trimmed));
          }
          return line.replaceAllMapped(
            uriAttr,
            (m) => 'URI="${proxied(base.resolve(m.group(1)!))}"',
          );
        })
        .join('\n');
  }

  /// IPv4 del teléfono en la red Wi-Fi (la que ve el TV).
  static Future<String?> lanAddress() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
      );
      String? private;
      String? any;
      for (final interface in interfaces) {
        for (final address in interface.addresses) {
          if (address.isLoopback || address.isLinkLocal) continue;
          final value = address.address;
          if (interface.name.startsWith('wlan')) return value;
          if (value.startsWith('192.168.') || value.startsWith('10.')) {
            private ??= value;
          }
          any ??= value;
        }
      }
      return private ?? any;
    } catch (_) {
      return null;
    }
  }
}
