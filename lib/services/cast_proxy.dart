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

  // Subtítulo de la transmisión en curso: WebVTT para Chromecast, SRT para
  // los TV DLNA.
  List<int>? _vtt;
  List<int>? _srt;
  Duration _subtitleLength = Duration.zero;
  // Reloj del video (PTS, 90 kHz) al empezar: alinea el subtítulo HLS.
  int? _firstPts;

  /// URL que el TV puede pedir para reproducir [url] con [headers].
  /// Empieza una transmisión nueva: llamar antes que [subtitleUrls].
  Future<String> urlFor(String url, Map<String, String> headers) async {
    await _ensureStarted();
    _newToken();
    _headers = Map.unmodifiable(headers);
    // "?e=1" marca la lista de entrada: es donde se agrega la pista de
    // subtítulos para Chromecast.
    return '${_proxied(Uri.parse(url))}?e=1';
  }

  /// Publica un subtítulo (SRT o WebVTT) para el TV; devuelve sus URLs en
  /// los dos formatos.
  Future<({String vtt, String srt})> subtitleUrls(String text) async {
    await _ensureStarted();
    if (_token == null) _newToken();
    final vtt = toVtt(text);
    _vtt = utf8.encode(vtt);
    _srt = utf8.encode(toSrt(text));
    _subtitleLength = lastCueEnd(vtt);
    final base = 'http://$_host:${_server!.port}/$_token';
    return (vtt: '$base/sub.vtt', srt: '$base/sub.srt');
  }

  void _newToken() {
    final random = Random.secure();
    _token = List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    _vtt = null;
    _srt = null;
    _subtitleLength = Duration.zero;
    _firstPts = null;
  }

  /// Primer PTS (90 kHz) de un segmento MPEG-TS, o null.
  @visibleForTesting
  static int? firstPts(List<int> ts) {
    for (var i = 0; i + 188 <= ts.length; i += 188) {
      if (ts[i] != 0x47 || ts[i + 1] & 0x40 == 0) continue; // inicio de PES
      var p = i + 4;
      if (ts[i + 3] & 0x20 != 0) p += 1 + ts[p]; // campo de adaptación
      if (p + 14 > i + 188) continue;
      if (ts[p] != 0 || ts[p + 1] != 0 || ts[p + 2] != 1) continue;
      if (ts[p + 7] & 0x80 == 0) continue; // sin PTS
      final b = ts.sublist(p + 9, p + 14);
      return ((b[0] >> 1) & 0x07) << 30 |
          b[1] << 22 |
          (b[2] >> 1) << 15 |
          b[3] << 7 |
          b[4] >> 1;
    }
    return null;
  }

  /// WebVTT para la pista HLS: sin números de cue y con X-TIMESTAMP-MAP
  /// (el reproductor HLS de Chromecast lo exige para ubicar los tiempos).
  @visibleForTesting
  static String hlsVtt(String vtt, int? firstPts) {
    final body = vtt
        .replaceFirst(RegExp(r'^WEBVTT[^\n]*\n+'), '')
        .replaceAllMapped(
          RegExp(r'(^|\n\n)\d+\n(?=\d{2}:\d{2})'),
          (m) => m[1]!,
        );
    final map = 'X-TIMESTAMP-MAP=MPEGTS:${firstPts ?? 0},LOCAL:00:00:00.000';
    return 'WEBVTT\n$map\n\n$body';
  }

  /// Fin del último subtítulo (duración de la pista HLS de subtítulos).
  @visibleForTesting
  static Duration lastCueEnd(String vtt) {
    var end = Duration.zero;
    for (final m in RegExp(
      r'--> *(\d{2}):(\d{2}):(\d{2})\.(\d{3})',
    ).allMatches(vtt)) {
      final t = Duration(
        hours: int.parse(m[1]!),
        minutes: int.parse(m[2]!),
        seconds: int.parse(m[3]!),
        milliseconds: int.parse(m[4]!),
      );
      if (t > end) end = t;
    }
    return end;
  }

  /// Agrega a una lista HLS de entrada la pista de subtítulos [subPlaylist].
  /// El reproductor HLS de Chromecast no acepta un subtítulo suelto junto a
  /// un stream HLS, pero sí uno declarado en la propia lista maestra. Si la
  /// entrada es una lista de segmentos (sin variantes), se envuelve en una
  /// maestra que apunta a [mediaUrl].
  @visibleForTesting
  static String withSubtitles(
    String playlist,
    String subPlaylist,
    String mediaUrl,
  ) {
    const media =
        '#EXT-X-MEDIA:TYPE=SUBTITLES,GROUP-ID="hourtv-subs",NAME="Español",'
        'LANGUAGE="es",DEFAULT=NO,AUTOSELECT=NO,FORCED=NO,URI=';
    final declared = '$media"$subPlaylist"';
    if (!playlist.contains('#EXT-X-STREAM-INF')) {
      return '#EXTM3U\n$declared\n'
          '#EXT-X-STREAM-INF:BANDWIDTH=2000000,SUBTITLES="hourtv-subs"\n'
          '$mediaUrl\n';
    }
    final lines = <String>[];
    for (final line in const LineSplitter().convert(playlist)) {
      if (line.startsWith('#EXT-X-STREAM-INF:')) {
        final attrs = line.replaceAll(RegExp(r',?SUBTITLES="[^"]*"'), '');
        lines.add('$attrs,SUBTITLES="hourtv-subs"');
      } else if (line.startsWith('#EXT-X-MEDIA:') &&
          line.contains('TYPE=SUBTITLES')) {
        continue; // las del servidor no se pueden leer desde el TV
      } else {
        lines.add(line);
      }
      if (line.trim() == '#EXTM3U') lines.add(declared);
    }
    return '${lines.join('\n')}\n';
  }

  static final _srtTime = RegExp(r'(\d{2}:\d{2}:\d{2}),(\d{3})');
  static final _vttTime = RegExp(r'(\d{2}:\d{2}:\d{2})\.(\d{3})');

  @visibleForTesting
  static String toVtt(String text) {
    final clean = _clean(text);
    if (clean.trimLeft().startsWith('WEBVTT')) return clean;
    final body = clean.replaceAllMapped(_srtTime, (m) => '${m[1]}.${m[2]}');
    return 'WEBVTT\n\n$body';
  }

  @visibleForTesting
  static String toSrt(String text) {
    final clean = _clean(text);
    if (!clean.trimLeft().startsWith('WEBVTT')) return clean;
    final body = clean.trimLeft().replaceFirst(RegExp(r'^WEBVTT[^\n]*\n+'), '');
    return body.replaceAllMapped(_vttTime, (m) => '${m[1]},${m[2]}');
  }

  static String _clean(String text) =>
      text.replaceAll('\r\n', '\n').replaceFirst('\uFEFF', '');

  String _subtitlePlaylist() {
    final seconds = _subtitleLength.inSeconds + 60;
    return '#EXTM3U\n#EXT-X-VERSION:3\n#EXT-X-TARGETDURATION:$seconds\n'
        '#EXT-X-MEDIA-SEQUENCE:0\n#EXT-X-PLAYLIST-TYPE:VOD\n'
        '#EXTINF:$seconds.0,\nsub-hls.vtt\n#EXT-X-ENDLIST\n';
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
      final segments = request.uri.pathSegments;
      if (segments.length == 2 && segments[0] == _token) {
        final sub = switch (segments[1]) {
          'sub.m3u8' => (
            _vtt == null ? null : utf8.encode(_subtitlePlaylist()),
            'application/vnd.apple.mpegurl',
          ),
          'sub-hls.vtt' => (
            _vtt == null
                ? null
                : utf8.encode(hlsVtt(utf8.decode(_vtt!), _firstPts)),
            'text/vtt; charset=utf-8',
          ),
          'sub.vtt' => (_vtt, 'text/vtt; charset=utf-8'),
          'sub.srt' => (_srt, 'application/x-subrip; charset=utf-8'),
          _ => null,
        };
        if (sub != null) {
          final (body, type) = sub;
          if (!kReleaseMode) {
            debugPrint(
              '[CAST] subtítulo ${request.method} ${segments[1]} '
              '${body?.length ?? 0} bytes',
            );
          }
          response.statusCode = body == null
              ? HttpStatus.notFound
              : HttpStatus.ok;
          response.headers.set(HttpHeaders.contentTypeHeader, type);
          if (body != null && request.method != 'HEAD') response.add(body);
          await response.close();
          return;
        }
      }
      final target = _decode(segments);
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
      var playlist = rewritePlaylist(text, finalUrl, _proxied);
      if (request.uri.queryParameters['e'] == '1' && _vtt != null) {
        playlist = withSubtitles(
          playlist,
          'http://$_host:${_server!.port}/$_token/sub.m3u8',
          _proxied(finalUrl),
        );
      }
      final body = utf8.encode(playlist);
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
    if (_firstPts == null && finalUrl.path.toLowerCase().endsWith('.ts')) {
      // Se mira el primer trozo del primer segmento para leer su PTS (solo
      // ese: los siguientes no empiezan alineados a paquetes de 188 bytes).
      var first = true;
      await response.addStream(
        upstream.map((chunk) {
          if (first) {
            first = false;
            _firstPts ??= firstPts(chunk);
          }
          return chunk;
        }),
      );
    } else {
      await response.addStream(upstream);
    }
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
