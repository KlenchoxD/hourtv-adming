import 'dart:async' show TimeoutException;
import 'dart:convert';
import 'dart:io' show HandshakeException, HttpException, SocketException;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:video_player/video_player.dart';
import 'provider_stream_bridge.dart';
import 'extraction_engine.dart';
import 'subtitles/hourtv_subtitle_track.dart';
import 'webflux_stream_resolver.dart';

/// Stream directo extraído de una página embed, con las cabeceras que su CDN
/// exige (Referer/User-Agent), para reproducirlo nativo en ExoPlayer.
class ResolvedStream {
  final String url;
  final Map<String, String> headers;
  final VideoFormat? formatHint;
  final List<HourTvSubtitleTrack> subtitleTracks;

  /// Releases playback-scoped resources after the native decoder is closed.
  final Future<void> Function()? release;
  const ResolvedStream(
    this.url,
    this.headers, {
    this.formatHint,
    this.subtitleTracks = const [],
    this.release,
  });
}

/// Resultado de inspeccionar un embed: puede ser un stream reproducible de
/// forma nativa o un destino verificado pendiente de resolución.
class EmbedResolution {
  final ResolvedStream? stream;
  final String? safeWebUrl;
  final bool terminalFailure;
  final bool retryableFailure;

  const EmbedResolution({
    this.stream,
    this.safeWebUrl,
    this.terminalFailure = false,
    this.retryableFailure = false,
  });
}

/// Resuelve enlaces embed (streamwish, vidhide, filemoon, dood y clones de
/// XFileSharing) a su .m3u8/.mp4 directo, como hacen las apps tipo Xuper:
/// descarga la página, desempaqueta el JS "p,a,c,k,e,d" y extrae la fuente.
///
/// No ejecuta JavaScript: el packer es una sustitución determinista de texto.
/// Si no logra resolver, devuelve null para probar el siguiente servidor.
class EmbedResolver {
  EmbedResolver._();

  static const _ua =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';

  static const Map<String, Set<String>> _trustedRedirectAliases = {
    'voe.sx': {
      'eugenemakedraw.com',
      'katherineschoolphone.com',
      'jeremyparticipantanything.com',
    },
  };

  static Future<ResolvedStream?> resolve(String embedUrl) async {
    return (await resolveForPlayback(embedUrl)).stream;
  }

  static Future<EmbedResolution> resolveForPlayback(
    String embedUrl, {
    http.Client? client,
    ExtractionRequest? request,
    WebfluxStreamResolver? webfluxResolver,
  }) async {
    embedUrl = _normalizeVoePlaybackUrl(embedUrl);
    final resolverRequestId = ProviderStreamBridge.newResolverRequestId();
    EmbedResolution? unresolvedFailure;
    WebfluxStreamResolver? activeWebfluxResolver;
    final engine = ExtractionEngine<EmbedResolution>([
      ExtractorAdapter(
        id: 'webflux-local-hls',
        supports: (uri) =>
            !kIsWeb &&
            defaultTargetPlatform == TargetPlatform.android &&
            WebfluxStreamResolver.supports(uri),
        timeout: const Duration(seconds: 25),
        cancel: () => activeWebfluxResolver?.disposeAll(),
        extract: (uri) async {
          final resolver = webfluxResolver ?? WebfluxStreamResolver();
          activeWebfluxResolver = resolver;
          try {
            final url = await resolver.resolveToLocalM3u8(
              uri.toString(),
              request: request,
            );
            return EmbedResolution(
              stream: ResolvedStream(
                url,
                const {},
                formatHint: VideoFormat.hls,
                release: resolver.disposeAll,
              ),
            );
          } on WebfluxResolutionCancelled {
            return const EmbedResolution();
          } on WebfluxResolutionException catch (error) {
            return EmbedResolution(
              terminalFailure: !error.retryable,
              retryableFailure: error.retryable,
            );
          } catch (_) {
            await resolver.disposeAll();
            // This provider is handled here; a temporary capture/CDN failure
            // must not send its SPA through unrelated generic extractors.
            return const EmbedResolution(retryableFailure: true);
          }
        },
      ),
      ExtractorAdapter(
        id: 'moongetter-native',
        supports: (uri) => uri.scheme == 'https',
        timeout: const Duration(seconds: 10),
        cancel: () => ProviderStreamBridge.cancelMoonGetter(resolverRequestId),
        extract: (uri) async {
          final result = await ProviderStreamBridge.resolveMoonGetter(
            uri.toString(),
            requestId: resolverRequestId,
          );
          if (result == null || !result.recognized) {
            throw const UnsupportedExtractionException();
          }
          final source = result.stream;
          if (source == null) {
            final failure = EmbedResolution(
              terminalFailure: !result.retryableFailure,
              retryableFailure: result.retryableFailure,
            );
            if (uri.host == 'voe.sx') {
              // The pinned native extractor recognizes VOE but can return no
              // variant. Our independent VOE parser must still get a chance;
              // a recognized host is not itself a resolved playback source.
              unresolvedFailure = failure;
              debugPrint('[PLAYER] voe_native_miss trying=static-embed');
              return null;
            }
            return failure;
          }
          return EmbedResolution(
            stream: ResolvedStream(
              source.url,
              source.headers,
              formatHint: source.formatHint,
              subtitleTracks: source.subtitleTracks,
            ),
          );
        },
      ),
      ExtractorAdapter(
        id: 'byse-session',
        supports: (uri) =>
            uri.scheme == 'https' &&
            uri.host == 'byseraguci.com' &&
            uri.path.startsWith('/e/'),
        // The provider's normal page is inspected only for this known host.
        // Do this before generic resolvers so it does not pay their timeouts.
        // Playback itself remains in the native player.
        timeout: const Duration(seconds: 145),
        cancel: () => ProviderStreamBridge.cancelResolver(resolverRequestId),
        extract: (uri) async {
          final source = await ProviderStreamBridge.resolve(
            uri.toString(),
            requestId: resolverRequestId,
          );
          return source == null
              ? EmbedResolution(safeWebUrl: uri.toString())
              : EmbedResolution(
                  stream: ResolvedStream(
                    source.url,
                    source.headers,
                    formatHint: source.formatHint,
                    subtitleTracks: source.subtitleTracks,
                  ),
                );
        },
      ),
      ExtractorAdapter(
        id: 'static-embed',
        // A root-page fragment is client-side state: HTTP never receives it.
        // Only a host-specific adapter can use such an ID, so avoid fetching
        // the same generic shell and then handing it to yt-dlp.
        supports: (uri) => !_isRootFragmentReference(uri),
        timeout: const Duration(seconds: 210),
        extract: (uri) async {
          final result = await _resolveStatic(
            uri.toString(),
            client: client,
            request: request,
          );
          final hasDestination =
              result.stream != null || result.safeWebUrl != null;
          if (!hasDestination &&
              (result.terminalFailure || result.retryableFailure)) {
            unresolvedFailure = result;
          }
          // A failure value is not an extracted destination. Returning it as
          // non-null makes ExtractionEngine stop before yt-dlp can try the
          // same HTTPS page with its independent extractor.
          return hasDestination ? result : null;
        },
      ),
      ExtractorAdapter(
        id: 'yt-dlp-local',
        supports: (uri) =>
            uri.scheme == 'https' && !_isRootFragmentReference(uri),
        timeout: const Duration(seconds: 35),
        cancel: () => ProviderStreamBridge.cancelYtDlp(resolverRequestId),
        extract: (uri) async {
          final source = await ProviderStreamBridge.resolveYtDlp(
            uri.toString(),
            requestId: resolverRequestId,
          );
          return source == null
              ? null
              : EmbedResolution(
                  stream: ResolvedStream(
                    source.url,
                    source.headers,
                    formatHint: source.formatHint,
                    subtitleTracks: source.subtitleTracks,
                  ),
                );
        },
      ),
    ]);
    final result = await engine.resolve(embedUrl, request: request);
    final stream = result.value?.stream;
    if (stream != null) {
      final host = Uri.tryParse(stream.url)?.host ?? 'unknown';
      debugPrint(
        '[PLAYER] embed_resolved extractor=${result.extractorId ?? 'unknown'} '
        'host=$host',
      );
    } else if (result.value?.terminalFailure == true ||
        unresolvedFailure?.terminalFailure == true) {
      debugPrint(
        '[PLAYER] embed_terminal_failure extractor=${result.extractorId ?? 'unknown'}',
      );
    } else if (result.value?.retryableFailure == true ||
        unresolvedFailure?.retryableFailure == true ||
        result.status == ExtractionStatus.timedOut) {
      debugPrint(
        '[PLAYER] embed_retryable_failure extractor=${result.extractorId ?? 'unknown'}',
      );
    } else {
      debugPrint(
        '[PLAYER] embed_unresolved status=${result.status.name} '
        'extractor=${result.extractorId ?? 'none'}',
      );
    }
    if (result.value != null) return result.value!;
    if (result.status == ExtractionStatus.cancelled) {
      return const EmbedResolution();
    }
    if (result.status == ExtractionStatus.timedOut) {
      return const EmbedResolution(retryableFailure: true);
    }
    return unresolvedFailure ??
        EmbedResolution(
          terminalFailure:
              result.status == ExtractionStatus.unsupported ||
              result.status == ExtractionStatus.failed,
        );
  }

  static Future<EmbedResolution> _resolveStatic(
    String embedUrl, {
    http.Client? client,
    ExtractionRequest? request,
  }) async {
    final origin = _origin(embedUrl);
    try {
      final res = await (client?.get ?? http.get)(
        Uri.parse(embedUrl),
        headers: {
          'User-Agent': _ua,
          'Referer': origin,
          'Accept': 'text/html,application/xhtml+xml,*/*',
        },
      ).timeout(const Duration(seconds: 15));
      if (res.statusCode != 200 || res.body.isEmpty) {
        final retryable = _isRetryableHttpStatus(res.statusCode);
        debugPrint(
          '[PLAYER] embed_http ${res.statusCode} host=${Uri.parse(embedUrl).host}',
        );
        return EmbedResolution(
          terminalFailure: !retryable,
          retryableFailure: retryable,
        );
      }
      final html = res.body;
      if (Uri.parse(embedUrl).host == 'mp4.nu') {
        return _resolveMp4Wrapper(
          embedUrl,
          html,
          client: client,
          request: request,
        );
      }
      if (_isOkRu(embedUrl)) {
        return EmbedResolution(stream: _okRuSource(html, embedUrl));
      }

      // VOE: la pagina voe.sx es solo una redireccion JS a un alias propio.
      // El stream real vive en el alias, cifrado en un application/json.
      // Se sigue la redireccion UNA sola vez y solo hacia el alias conocido.
      final safeWebUrl =
          _safeWebRedirect(html, embedUrl) ??
          _voeEpisodeRedirect(html, embedUrl);
      if (safeWebUrl != null) {
        return _resolveTrustedAlias(safeWebUrl, verifiedRedirect: true).then((
          voeStream,
        ) {
          return voeStream != null
              ? EmbedResolution(stream: voeStream)
              : EmbedResolution(safeWebUrl: safeWebUrl);
        });
      }

      // Alias de VOE (o host directo con el mismo formato): payload cifrado.
      final voeStream = _voeSource(html, embedUrl);
      if (voeStream != null) return EmbedResolution(stream: voeStream);

      // Demas hosts: packer p,a,c,k,e,d / jwplayer / file:"...".
      final source = _extractSource(html);
      if (source == null) {
        debugPrint('[PLAYER] embed_no_source host=${Uri.parse(embedUrl).host}');
        return const EmbedResolution();
      }
      final absolute = _absolute(source, embedUrl);
      // El CDN de estos hosts suele exigir Referer del propio sitio.
      return EmbedResolution(
        stream: ResolvedStream(absolute, {
          'User-Agent': _ua,
          'Referer': '$origin/',
        }),
      );
    } catch (e) {
      debugPrint('[PLAYER] embed_error ${e.runtimeType}');
      final retryable =
          request?.isCancelled != true && _isTransientNetworkFailure(e);
      return EmbedResolution(
        terminalFailure: !retryable && request?.isCancelled != true,
        retryableFailure: retryable,
      );
    }
  }

  static bool _isRootFragmentReference(Uri uri) =>
      uri.fragment.isNotEmpty &&
      (uri.path.isEmpty || uri.path == '/') &&
      uri.query.isEmpty;

  /// VOE's public file URL and embed URL share an ID, but their redirect pages
  /// are not interchangeable. Normalize only the exact HTTPS file route;
  /// signed/query URLs, aliases and other providers must remain untouched.
  static String _normalizeVoePlaybackUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host != 'voe.sx' ||
        uri.userInfo.isNotEmpty ||
        uri.hasPort ||
        uri.hasQuery ||
        uri.hasFragment ||
        !RegExp(r'^/[a-zA-Z0-9]{8,}$').hasMatch(uri.path)) {
      return url;
    }
    return uri.replace(path: '/e${uri.path}').toString();
  }

  static bool _isRetryableHttpStatus(int status) =>
      status == 408 || status == 425 || status == 429 || status >= 500;

  static bool _isTransientNetworkFailure(Object error) =>
      error is TimeoutException ||
      error is SocketException ||
      error is HttpException ||
      error is HandshakeException ||
      error is http.ClientException;

  /// Follow only the observed mp4.nu handoff, never arbitrary page scripts.
  static Future<EmbedResolution> _resolveMp4Wrapper(
    String source,
    String html, {
    http.Client? client,
    ExtractionRequest? request,
  }) async {
    final match = RegExp(
      r'''window\.location\.replace\(\s*["']([^"']+)["']\s*\)''',
    ).firstMatch(html);
    if (match == null) return const EmbedResolution();
    final origin = Uri.parse(source);
    var next = origin.resolve(match.group(1)!);
    if (next.scheme != 'https' ||
        next.host != 'mp4.nu' ||
        next.userInfo.isNotEmpty ||
        next.path != '/r.php' ||
        !next.queryParameters.containsKey('h')) {
      return const EmbedResolution();
    }
    final transport = client ?? http.Client();
    try {
      final visited = <String>{};
      for (var hop = 0; hop < 4; hop++) {
        if (request?.isCancelled == true) return const EmbedResolution();
        if (!visited.add(next.toString())) break;
        final httpRequest = http.Request('GET', next)
          ..followRedirects = false
          ..headers.addAll({'User-Agent': _ua, 'Referer': source});
        final response = await transport
            .send(httpRequest)
            .timeout(const Duration(seconds: 15));
        final location = response.headers['location'];
        await response.stream.drain<void>().timeout(
          const Duration(seconds: 15),
        );
        if (![301, 302, 303, 307, 308].contains(response.statusCode) ||
            location == null) {
          break;
        }
        next = next.resolve(location);
        if (next.scheme != 'https' ||
            next.userInfo.isNotEmpty ||
            next.hasPort && next.port != 443) {
          break;
        }
        if (next.host == 'byseraguci.com' && next.path.startsWith('/e/')) {
          return await resolveForPlayback(
            next.toString(),
            client: transport,
            request: request,
          );
        }
        if (next.host != 'mp4.nu') break;
      }
      return const EmbedResolution();
    } catch (error) {
      final retryable = _isTransientNetworkFailure(error);
      return EmbedResolution(
        terminalFailure: !retryable,
        retryableFailure: retryable,
      );
    } finally {
      if (client == null) transport.close();
    }
  }

  /// Descarga el alias de confianza (ej. eugenemakedraw.com para voe.sx) e
  /// intenta resolver el stream nativo desde su payload cifrado. Nunca se
  /// usaria para una redireccion no verificada.
  static Future<ResolvedStream?> _resolveTrustedAlias(
    String aliasUrl, {
    bool verifiedRedirect = false,
  }) async {
    try {
      final res = await http
          .get(
            Uri.parse(aliasUrl),
            headers: {
              'User-Agent': _ua,
              'Referer': _origin(aliasUrl),
              'Accept': 'text/html,application/xhtml+xml,*/*',
            },
          )
          .timeout(const Duration(seconds: 15));
      if (res.statusCode != 200 || res.body.isEmpty) return null;
      return _voeSource(res.body, aliasUrl, verifiedRedirect: verifiedRedirect);
    } catch (_) {
      return null;
    }
  }

  /// Solo para pruebas: expone la extracción sin red. Refleja el orden de
  /// la resolución real: VOE (payload cifrado) antes que packer/genérico.
  static String? debugExtract(String html) {
    final voeUrl = debugVoeSource(html)?.url;
    if (voeUrl != null) return voeUrl;
    return _extractSource(html);
  }

  /// Solo para pruebas: valida redirecciones JavaScript sin realizar red.
  static String? debugSafeWebRedirect(String html, String sourceUrl) =>
      _safeWebRedirect(html, sourceUrl);

  /// Solo para pruebas: resuelve con un mapa falso de respuestas, sin red.
  /// [responses] contiene la respuesta HTML de cada URL visitada.
  static EmbedResolution debugResolve(
    String startUrl,
    List<(String, String)> responses,
  ) {
    final byUrl = {for (final (url, html) in responses) url: html};
    EmbedResolution resolve(String url) {
      final html = byUrl[url];
      if (html == null) return const EmbedResolution();
      if (_isOkRu(url)) {
        return EmbedResolution(stream: _okRuSource(html, url));
      }
      final safeWebUrl =
          _safeWebRedirect(html, url) ?? _voeEpisodeRedirect(html, url);
      if (safeWebUrl != null) {
        final aliasHtml = byUrl[safeWebUrl];
        final voeStream = aliasHtml == null
            ? null
            : _voeSource(aliasHtml, safeWebUrl, verifiedRedirect: true);
        return voeStream != null
            ? EmbedResolution(stream: voeStream)
            : EmbedResolution(safeWebUrl: safeWebUrl);
      }
      final voeStream = _voeSource(html, url);
      if (voeStream != null) return EmbedResolution(stream: voeStream);
      final source = _extractSource(html);
      if (source == null) return const EmbedResolution();
      final absolute = _absolute(source, url);
      return EmbedResolution(
        stream: ResolvedStream(absolute, {
          'User-Agent': _ua,
          'Referer': '${_origin(url)}/',
        }),
      );
    }

    return resolve(startUrl);
  }

  static bool _isOkRu(String url) {
    final host = Uri.tryParse(url)?.host.toLowerCase() ?? '';
    return host == 'ok.ru' || host.endsWith('.ok.ru');
  }

  /// Rotación de dominios anunciada por el origen HTTPS real de VOE.
  /// Se conserva el ID exacto del vídeo y se excluyen anuncios y credenciales.
  static String? _voeEpisodeRedirect(String html, String sourceUrl) {
    final source = Uri.tryParse(sourceUrl);
    if (source == null ||
        source.scheme != 'https' ||
        source.host != 'voe.sx' ||
        source.userInfo.isNotEmpty) {
      return null;
    }
    final parts = source.pathSegments.where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty ||
        parts.length > 2 ||
        (parts.length == 2 && parts.first != 'e') ||
        !RegExp(r'^[a-zA-Z0-9]{8,}$').hasMatch(parts.last)) {
      return null;
    }
    for (final match in RegExp(
      r'''(?:window\.)?location\.href\s*=\s*['"](https://[^'"]+)['"]''',
    ).allMatches(html)) {
      final target = Uri.tryParse(match.group(1)!);
      if (target == null ||
          target.scheme != 'https' ||
          !target.hasAuthority ||
          target.userInfo.isNotEmpty ||
          target.hasPort ||
          target.hasQuery ||
          target.hasFragment ||
          target.path != '/e/${parts.last}') {
        continue;
      }
      return target.toString();
    }
    return null;
  }

  /// OK.ru publica la fuente del vídeo dentro de data-options, no en el primer
  /// literal .m3u8 del HTML (ese literal es una plantilla de CDN sin autorización).
  static ResolvedStream? _okRuSource(String html, String pageUrl) {
    for (final element
        in html_parser.parse(html).querySelectorAll('[data-options]')) {
      try {
        final options = jsonDecode(element.attributes['data-options']!);
        if (options is! Map || options['flashvars'] is! Map) continue;
        dynamic metadata = options['flashvars']['metadata'];
        if (metadata is String) metadata = jsonDecode(metadata);
        if (metadata is! Map) continue;
        final candidates = <String>[
          if (metadata['hlsManifestUrl'] is String) metadata['hlsManifestUrl'],
          if (metadata['videos'] is List)
            for (final video in (metadata['videos'] as List).reversed)
              if (video is Map && video['url'] is String) video['url'],
        ];
        for (final candidate in candidates) {
          final uri = Uri.tryParse(candidate);
          if (uri == null ||
              uri.scheme != 'https' ||
              !uri.hasAuthority ||
              uri.userInfo.isNotEmpty) {
            continue;
          }
          return ResolvedStream(candidate, {
            'User-Agent': _ua,
            'Referer': pageUrl,
          });
        }
      } catch (_) {
        // Otro elemento puede contener las opciones reales del reproductor.
      }
    }
    return null;
  }

  /// Solo para pruebas: expone la extracción VOE (payload cifrado) sin red.
  static ResolvedStream? debugVoeSource(String html, [String pageUrl = '']) =>
      _voeSource(
        html,
        pageUrl.isEmpty ? 'https://eugenemakedraw.com/e/id' : pageUrl,
      );

  static String? _safeWebRedirect(String html, String sourceUrl) {
    final source = Uri.tryParse(sourceUrl);
    if (source == null ||
        source.scheme != 'https' ||
        source.userInfo.isNotEmpty) {
      return null;
    }
    final allowed = _trustedRedirectAliases[source.host.toLowerCase()];
    if (allowed == null) return null;

    final patterns = <RegExp>[
      RegExp(
        r'''(?:window\.|document\.)?location\.href\s*=\s*["']([^"']+)["']''',
        caseSensitive: false,
      ),
      RegExp(
        r'''(?:window\.|document\.)?location\.replace\(\s*["']([^"']+)["']\s*\)''',
        caseSensitive: false,
      ),
    ];
    for (final pattern in patterns) {
      for (final match in pattern.allMatches(html)) {
        final target = Uri.tryParse(match.group(1) ?? '');
        if (target == null ||
            target.scheme != 'https' ||
            !target.hasAuthority ||
            target.userInfo.isNotEmpty) {
          continue;
        }
        final host = target.host.toLowerCase();
        if (allowed.any((alias) => host == alias || host.endsWith('.$alias'))) {
          return target.toString();
        }
      }
    }
    return null;
  }

  /// Busca la URL del stream en el HTML: primero desempaqueta el packer, y si
  /// no hay, mira el HTML crudo (algunos ponen sources:[{file:"..."}] directo).
  static String? _extractSource(String html) {
    final unpacked = _unpack(html);
    for (final text in [unpacked, html]) {
      if (text == null) continue;
      // 1) URL .m3u8/.mp4 absoluta.
      final direct = RegExp(r'''https?://[^"'\\ )]+\.(?:m3u8|mp4)[^"'\\ )]*''');
      for (final match in direct.allMatches(text)) {
        final candidate = match.group(0);
        if (candidate != null && !_isDecoy(candidate)) return candidate;
      }
      // 2) file:"..." / "file":"..." dentro de la config del reproductor.
      final fileField = RegExp(
        r'''["']?file["']?\s*:\s*["']([^"']+\.(?:m3u8|mp4)[^"']*)["']''',
      );
      for (final match in fileField.allMatches(text)) {
        final candidate = match.group(1);
        if (candidate != null && !_isDecoy(candidate)) return candidate;
      }
      // 3) sources:[{file:"..."}] con ruta relativa.
      final rel = RegExp(
        r'''["']?file["']?\s*:\s*["'](/[^"']+\.(?:m3u8|mp4)[^"']*)["']''',
      ).firstMatch(text);
      if (rel != null) return rel.group(1);
    }
    return null;
  }

  static bool _isDecoy(String url) {
    final host = Uri.tryParse(url)?.host.toLowerCase() ?? '';
    return host == 'test-videos.co.uk' || host.endsWith('.test-videos.co.uk');
  }

  // ─────────────────────────────────────────────────────────────────────
  // VOE: payload cifrado en <script type="application/json">["..."]</script>
  //
  // Descifrado (determinista, sin ejecutar JS — mismo algoritmo publico
  // documentado por stream-bypass y cyberdrop-dl):
  //   rot13 -> quitar secuencias especiales -> base64 -> shift(-3)
  //   -> invertir -> base64 -> JSON
  // El JSON trae "source" (m3u8 HLS) y "fallback" (mp4s por calidad).
  // El `var source='...Big_Buck_Bunny...mp4'` en texto claro es un señuelo
  // y NUNCA debe usarse (lo cubre _isDecoy).
  // ─────────────────────────────────────────────────────────────────────

  static ResolvedStream? _voeSource(
    String html,
    String pageUrl, {
    bool verifiedRedirect = false,
  }) {
    final page = Uri.tryParse(pageUrl);
    if (page == null ||
        page.scheme != 'https' ||
        page.userInfo.isNotEmpty ||
        (!verifiedRedirect && !_isTrustedVoeAlias(page.host))) {
      return null;
    }
    final payload = _voeDecrypt(html);
    if (payload == null) return null;
    final streamUrl = _voePickUrl(payload);
    if (streamUrl == null) return null;
    return ResolvedStream(streamUrl, {
      'User-Agent': _ua,
      'Referer': '${_origin(pageUrl)}/',
    });
  }

  /// Descifra el primer `<script type="application/json">` valido de VOE.
  /// Devuelve el mapa del reproductor o null si la pagina no lo trae.
  static Map<String, dynamic>? _voeDecrypt(String html) {
    final scripts = RegExp(
      r'<script\s+type="application/json"\s*>(.*?)</script>',
      dotAll: true,
    ).allMatches(html);
    for (final script in scripts) {
      final raw = script.group(1)?.trim() ?? '';
      if (raw.isEmpty) continue;
      String? candidates;
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List && decoded.isNotEmpty && decoded.first is String) {
          candidates = decoded.first as String;
        } else if (decoded is Map<String, dynamic>) {
          return decoded;
        }
      } catch (_) {
        continue;
      }
      final decrypted = _voeUnpack(candidates ?? raw);
      if (decrypted != null) return decrypted;
    }
    return null;
  }

  static Map<String, dynamic>? _voeUnpack(String encrypted) {
    String? b64decode(String s) {
      try {
        final normalized = s.replaceAllMapped(
          RegExp(r'[^A-Za-z0-9+/=]'),
          (m) => '',
        );
        final bytes = base64.decode(normalized);
        return String.fromCharCodes(bytes);
      } catch (_) {
        return null;
      }
    }

    String shift(String s, int n) =>
        String.fromCharCodes(s.codeUnits.map((c) => c + n));

    var text = encrypted;
    text = String.fromCharCodes(text.codeUnits.map(_rot13));
    text = text
        .replaceAll(r'@$', '')
        .replaceAll('^^', '')
        .replaceAll(r'~@', '')
        .replaceAll(r'%?', '')
        .replaceAll(r'*~', '')
        .replaceAll('!!', '')
        .replaceAll(r'#&', '');
    final stepB64a = b64decode(text);
    if (stepB64a == null) return null;
    var decodedText = shift(stepB64a, -3);
    decodedText = decodedText.split('').reversed.join();
    final stepB64b = b64decode(decodedText);
    if (stepB64b == null) return null;
    try {
      final decoded = jsonDecode(stepB64b);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  static int _rot13(int c) {
    if (c >= 65 && c <= 90) return ((c - 65 + 13) % 26) + 65;
    if (c >= 97 && c <= 122) return ((c - 97 + 13) % 26) + 97;
    return c;
  }

  /// source (HLS) primero; si no existe, el mejor mp4 de fallback. Nunca
  /// devuelve el señuelo (el payload real no lo contiene).
  static String? _voePickUrl(Map<String, dynamic> payload) {
    final source = payload['source'];
    if (source is String && _isSecureMediaUrl(source)) return source;
    final fallback = payload['fallback'];
    if (fallback is List) {
      for (final item in fallback.reversed) {
        if (item is Map<String, dynamic>) {
          final file = item['file'];
          if (file is String && _isSecureMediaUrl(file) && !_isDecoy(file)) {
            return file;
          }
        }
      }
    }
    return null;
  }

  static bool _isTrustedVoeAlias(String host) {
    final normalized = host.toLowerCase();
    return _trustedRedirectAliases.values
        .expand((aliases) => aliases)
        .any((alias) => normalized == alias || normalized.endsWith('.$alias'));
  }

  static bool _isSecureMediaUrl(String value) {
    final uri = Uri.tryParse(value);
    return uri != null && uri.scheme == 'https' && uri.hasAuthority;
  }

  /// Desempaqueta el clásico `eval(function(p,a,c,k,e,d){...}('P',A,C,'W'.split('|')))`.
  /// Sustitución pura de tokens base-N por palabras; sin evaluar código.
  static String? _unpack(String js) {
    final m = RegExp(
      r"\}\s*\(\s*'(.*?)'\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*'(.*?)'\s*\.split\('\|'\)",
      dotAll: true,
    ).firstMatch(js);
    if (m == null) return null;
    var payload = m.group(1)!.replaceAll(r"\'", "'").replaceAll(r'\\', r'\');
    final radix = int.tryParse(m.group(2)!) ?? 36;
    final count = int.tryParse(m.group(3)!) ?? 0;
    final words = m.group(4)!.split('|');
    for (var i = count - 1; i >= 0; i--) {
      if (i < words.length && words[i].isNotEmpty) {
        payload = payload.replaceAll(
          RegExp(r'\b' + _baseN(i, radix) + r'\b'),
          words[i],
        );
      }
    }
    return payload;
  }

  /// Entero a base-N (2..36) con dígitos 0-9a-z, igual que JS Number.toString(radix).
  static String _baseN(int n, int radix) {
    if (n == 0) return '0';
    const digits = '0123456789abcdefghijklmnopqrstuvwxyz';
    final r = radix < 2 ? 2 : (radix > 36 ? 36 : radix);
    var v = n;
    final buf = StringBuffer();
    final chars = <String>[];
    while (v > 0) {
      chars.add(digits[v % r]);
      v = v ~/ r;
    }
    for (var i = chars.length - 1; i >= 0; i--) {
      buf.write(chars[i]);
    }
    return buf.toString();
  }

  static String _origin(String url) {
    final u = Uri.tryParse(url);
    if (u == null) return '';
    return '${u.scheme}://${u.host}';
  }

  static String _absolute(String source, String pageUrl) {
    if (source.startsWith('http')) return source;
    final page = Uri.parse(pageUrl);
    return source.startsWith('/')
        ? '${page.scheme}://${page.host}$source'
        : '${page.scheme}://${page.host}/$source';
  }
}
