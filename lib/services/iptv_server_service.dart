import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/channel.dart';
import 'content_store.dart';
import 'embed_resolver.dart';

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
    const fallbackAddress = '127.0.0.1';
    final base =
        localUrl.value?.replaceFirst('/lista.m3u', '') ??
        'http://$fallbackAddress:${_server?.port ?? defaultPort}';
    final output = buildPlaylist(base);
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

  /// Genera la lista desde el store en memoria. Expuesto para pruebas locales.
  @visibleForTesting
  String buildPlaylist(String baseUrl) {
    final store = ContentStore.instance;
    final out = StringBuffer('#EXTM3U\n');

    for (final movie in store.movies) {
      _addEntry(
        out,
        name: movie.displayName,
        logo: movie.logo,
        group: _movieGroup(movie),
        url: _primaryUrl(movie),
        baseUrl: baseUrl,
      );
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
        _addEntry(
          out,
          name: label,
          logo: episode.logo ?? series.cover,
          group: 'Series',
          url: _primaryUrl(episode),
          baseUrl: baseUrl,
        );
      }
    }

    for (final channel in store.all.where(
      (item) => item.type == MediaType.live,
    )) {
      _addEntry(
        out,
        name: channel.displayName,
        logo: channel.logo,
        group: channel.group?.trim().isNotEmpty == true
            ? channel.group!.trim()
            : 'Canales',
        url: channel.url,
        baseUrl: baseUrl,
        forceDirect: true,
      );
    }
    return out.toString();
  }

  void _addEntry(
    StringBuffer out, {
    required String name,
    required String? logo,
    required String group,
    required String? url,
    required String baseUrl,
    bool forceDirect = false,
  }) {
    final stream = _streamFor(baseUrl, url, forceDirect: forceDirect);
    if (stream == null) return;
    out
      ..write('#EXTINF:-1 tvg-logo="${_escapeAttribute(logo)}" ')
      ..write('group-title="${_escapeAttribute(group)}",${_escapeText(name)}\n')
      ..write('$stream\n');
  }

  String? _streamFor(String baseUrl, String? url, {bool forceDirect = false}) {
    final value = url?.trim();
    if (value == null || value.isEmpty) return null;
    if (forceDirect || _directStream.hasMatch(value)) return value;
    return '$baseUrl/resolve?u=${Uri.encodeQueryComponent(value)}';
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
