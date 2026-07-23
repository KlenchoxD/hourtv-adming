import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/channel.dart';
import 'content_store.dart';
import 'embed_resolver.dart';

typedef _PendingEntry = ({
  String name,
  String? logo,
  String group,
  String? url,
});

typedef _ResolvedEntry = ({
  String name,
  String? logo,
  String group,
  String url,
  Map<String, String>? headers,
});

/// Servidor M3U de alcance exclusivamente local. No expone contenido fuera de
/// la red Wi-Fi: publica el catálogo actual y resuelve embeds bajo demanda.
class IptvServerService {
  IptvServerService._();

  static final IptvServerService instance = IptvServerService._();
  static const int defaultPort = 8090;
  static final RegExp _directStream = RegExp(
    r'\.(m3u8|mp4|mkv|ts|mpd|webm|m4v)(\?|$)',
    caseSensitive: false,
  );

  final ValueNotifier<bool> isRunning = ValueNotifier<bool>(false);
  final ValueNotifier<String?> localUrl = ValueNotifier<String?>(null);

  HttpServer? _server;
  Future<void>? _starting;

  bool get running => _server != null;

  Future<void> start() {
    if (_server != null) return Future<void>.value();
    return _starting ??= _start().whenComplete(() => _starting = null);
  }

  Future<void> _start() async {
    final server = await HttpServer.bind(
      InternetAddress.anyIPv4,
      defaultPort,
      shared: true,
    );
    _server = server;
    final address = await _localAddress();
    localUrl.value = address == null
        ? null
        : 'http://$address:${server.port}/lista.m3u';
    isRunning.value = true;

    // No bloquea el servidor. La ruta /lista.m3u siempre usa el estado más
    // reciente del store, incluido el caché de arranque inmediato.
    unawaited(ContentStore.instance.ensureLoaded());
    unawaited(
      server.forEach(_handleRequest).catchError((_) {
        if (identical(_server, server)) {
          _server = null;
          localUrl.value = null;
          isRunning.value = false;
        }
      }),
    );
  }

  Future<void> stop() async {
    final starting = _starting;
    if (starting != null) {
      try {
        await starting;
      } catch (_) {
        // Si bind falló no hay socket que cerrar.
      }
    }
    final server = _server;
    _server = null;
    localUrl.value = null;
    isRunning.value = false;
    if (server != null) await server.close(force: true);
  }

  Future<void> _handleRequest(HttpRequest request) async {
    try {
      if (request.method != 'GET') {
        await _text(
          request,
          HttpStatus.methodNotAllowed,
          'Método no permitido',
        );
        return;
      }
      if (request.uri.path == '/lista.m3u') {
        await _m3u(request);
        return;
      }
      if (request.uri.path == '/resolve') {
        await _resolve(request);
        return;
      }
      await _text(request, HttpStatus.notFound, 'Ruta no encontrada');
    } catch (_) {
      // La conexión puede haberse cerrado por el cliente; no se reintenta.
    }
  }

  Future<void> _m3u(HttpRequest request) async {
    final output = await buildPlaylist();
    request.response.headers
      ..set(HttpHeaders.contentTypeHeader, 'audio/x-mpegurl; charset=utf-8')
      ..set('content-disposition', 'inline; filename="hourtv.m3u"')
      ..set(HttpHeaders.cacheControlHeader, 'no-cache');
    request.response.add(utf8.encode(output));
    await request.response.close();
  }

  Future<void> _resolve(HttpRequest request) async {
    final target = request.uri.queryParameters['u']?.trim();
    if (target == null || target.isEmpty) {
      await _text(request, HttpStatus.badRequest, 'Falta la URL embed');
      return;
    }
    final stream = await EmbedResolver.resolve(target);
    if (stream == null) {
      await _text(request, HttpStatus.notFound, 'No se pudo resolver el embed');
      return;
    }
    request.response.statusCode = HttpStatus.found;
    request.response.headers.set(HttpHeaders.locationHeader, stream.url);
    await request.response.close();
  }

  Future<void> _text(HttpRequest request, int status, String text) async {
    request.response.statusCode = status;
    request.response.headers.contentType = ContentType.text;
    request.response.write(text);
    await request.response.close();
  }

  /// Genera la lista desde el store en memoria. Resuelve los embeds de
  /// películas/series en el momento (en paralelo) para poder incluir el
  /// Referer/User-Agent que su CDN exige incluso en el .m3u8 final; un
  /// redirect 302 no sirve porque las apps IPTV no reenvían esos headers.
  /// Expuesto para pruebas locales.
  @visibleForTesting
  Future<String> buildPlaylist() async {
    final store = ContentStore.instance;
    final pending = <_PendingEntry>[];

    for (final movie in store.movies) {
      pending.add((
        name: movie.displayName,
        logo: movie.logo,
        group: _movieGroup(movie),
        url: _primaryUrl(movie),
      ));
    }

    for (final series in store.series) {
      final episodes = series.episodes ?? const <Channel>[];
      for (final episode in episodes) {
        final season =
            RegExp(r'\d+').firstMatch(episode.group ?? '')?.group(0) ?? '1';
        final idParts = (episode.tvgId ?? '')
            .split(':')
            .where((part) => RegExp(r'^\d+$').hasMatch(part))
            .toList();
        final episodeNumber = idParts.isEmpty ? null : idParts.last;
        final label =
            '${series.name} · T$season${episodeNumber == null ? '' : 'E$episodeNumber'} ${episode.displayName}'
                .trim();
        pending.add((
          name: label,
          logo: episode.logo ?? series.cover,
          group: 'Series',
          url: _primaryUrl(episode),
        ));
      }
    }

    final resolved = await Future.wait(pending.map(_resolveEntry));

    final out = StringBuffer('#EXTM3U\n');
    for (final entry in resolved) {
      if (entry != null) _writeEntry(out, entry);
    }

    for (final channel in store.all.where(
      (item) => item.type == MediaType.live,
    )) {
      final url = channel.url.trim();
      if (url.isEmpty) continue;
      _writeEntry(
        out,
        (
          name: channel.displayName,
          logo: channel.logo,
          group: channel.group?.trim().isNotEmpty == true
              ? channel.group!.trim()
              : 'Canales',
          url: url,
          headers: null,
        ),
      );
    }
    return out.toString();
  }

  /// Streams directos pasan tal cual; embeds se resuelven ya mismo (no con un
  /// enlace a /resolve) para poder adjuntar Referer/User-Agent en el M3U.
  /// Si el host no responde, la entrada simplemente se omite de la lista.
  Future<_ResolvedEntry?> _resolveEntry(_PendingEntry item) async {
    final value = item.url?.trim();
    if (value == null || value.isEmpty) return null;
    if (_directStream.hasMatch(value)) {
      return (
        name: item.name,
        logo: item.logo,
        group: item.group,
        url: value,
        headers: null,
      );
    }
    final stream = await EmbedResolver.resolve(value);
    if (stream == null) return null;
    return (
      name: item.name,
      logo: item.logo,
      group: item.group,
      url: stream.url,
      headers: stream.headers,
    );
  }

  void _writeEntry(StringBuffer out, _ResolvedEntry entry) {
    out
      ..write('#EXTINF:-1 tvg-logo="${_escapeAttribute(entry.logo)}" ')
      ..write(
        'group-title="${_escapeAttribute(entry.group)}",${_escapeText(entry.name)}\n',
      );
    final referer = entry.headers?['Referer'];
    final userAgent = entry.headers?['User-Agent'];
    // Etiquetas VLC-option: las respetan TiviMate, GSE IPTV y Perfect Player
    // para mandar el header en cada request del stream (manifest y segmentos).
    if (referer != null) out.write('#EXTVLCOPT:http-referrer=$referer\n');
    if (userAgent != null) {
      out.write('#EXTVLCOPT:http-user-agent=$userAgent\n');
    }
    out.write('${entry.url}\n');
  }

  String _movieGroup(Channel movie) {
    final categories = <String>[
      ...movie.categories,
      movie.category ?? '',
      movie.genre ?? '',
    ].join(' ').toLowerCase();
    if (categories.contains('anime')) return 'Anime';
    if (categories.contains('infantil')) return 'Infantil';
    if (categories.contains('novela')) return 'Novelas';
    return 'Películas';
  }

  String? _primaryUrl(Channel channel) =>
      channel.servers.isNotEmpty ? channel.servers.first.url : channel.url;

  String _escapeAttribute(String? value) =>
      (value ?? '').replaceAll(RegExp(r'[\r\n"]+'), ' ').trim();

  String _escapeText(String value) =>
      value.replaceAll(RegExp(r'[\r\n,]+'), ' ').trim();

  Future<String?> _localAddress() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );
      final addresses = interfaces
          .expand((interface) => interface.addresses)
          .where((address) => !address.isLoopback)
          .toList();
      for (final address in addresses) {
        final value = address.address;
        if (value.startsWith('192.168.') || value.startsWith('10.')) {
          return value;
        }
      }
      return addresses.isEmpty ? null : addresses.first.address;
    } catch (_) {
      return null;
    }
  }
}
