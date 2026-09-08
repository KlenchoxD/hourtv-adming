import 'dart:convert';

import 'package:http/http.dart' as http;

/// Stream directo extraído de una página embed, con las cabeceras que su CDN
/// exige (Referer/User-Agent), para reproducirlo nativo en ExoPlayer.
class ResolvedStream {
  final String url;
  final Map<String, String> headers;
  const ResolvedStream(this.url, this.headers);
}

/// Resultado de inspeccionar un embed: puede ser un stream reproducible de
/// forma nativa o un destino web verificado que debe abrirse en el WebView.
class EmbedResolution {
  final ResolvedStream? stream;
  final String? safeWebUrl;

  const EmbedResolution({this.stream, this.safeWebUrl});
}

/// Resuelve enlaces embed (streamwish, vidhide, filemoon, dood y clones de
/// XFileSharing) a su .m3u8/.mp4 directo, como hacen las apps tipo Xuper:
/// descarga la página, desempaqueta el JS "p,a,c,k,e,d" y extrae la fuente.
///
/// No ejecuta JavaScript: el packer es una sustitución determinista de texto.
/// Si no logra resolver, devuelve null y el reproductor usa el WebView.
class EmbedResolver {
  EmbedResolver._();

  static const _ua =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';

  static const Map<String, Set<String>> _trustedRedirectAliases = {
    'voe.sx': {'eugenemakedraw.com'},
  };

  static Future<ResolvedStream?> resolve(String embedUrl) async {
    return (await resolveForPlayback(embedUrl)).stream;
  }

  static Future<EmbedResolution> resolveForPlayback(String embedUrl) async {
    final origin = _origin(embedUrl);
    try {
      final res = await http
          .get(
            Uri.parse(embedUrl),
            headers: {
              'User-Agent': _ua,
              'Referer': origin,
              'Accept': 'text/html,application/xhtml+xml,*/*',
            },
          )
          .timeout(const Duration(seconds: 15));
      if (res.statusCode != 200 || res.body.isEmpty) {
        return const EmbedResolution();
      }
      final html = res.body;

      // VOE: la pagina voe.sx es solo una redireccion JS a un alias propio.
      // El stream real vive en el alias, cifrado en un application/json.
      // Se sigue la redireccion UNA sola vez y solo hacia el alias conocido.
      final safeWebUrl = _safeWebRedirect(html, embedUrl);
      if (safeWebUrl != null) {
        return _resolveTrustedAlias(safeWebUrl).then((voeStream) {
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
      if (source == null) return const EmbedResolution();
      final absolute = _absolute(source, embedUrl);
      // El CDN de estos hosts suele exigir Referer del propio sitio.
      return EmbedResolution(
        stream: ResolvedStream(absolute, {
          'User-Agent': _ua,
          'Referer': '$origin/',
        }),
      );
    } catch (_) {
      return const EmbedResolution();
    }
  }

  /// Descarga el alias de confianza (ej. eugenemakedraw.com para voe.sx) e
  /// intenta resolver el stream nativo desde su payload cifrado. Nunca se
  /// usaria para una redireccion no verificada.
  static Future<ResolvedStream?> _resolveTrustedAlias(String aliasUrl) async {
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
      return _voeSource(res.body, aliasUrl);
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
      final safeWebUrl = _safeWebRedirect(html, url);
      if (safeWebUrl != null) {
        final aliasHtml = byUrl[safeWebUrl];
        final voeStream = aliasHtml == null
            ? null
            : _voeSource(aliasHtml, safeWebUrl);
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

  /// Solo para pruebas: expone la extracción VOE (payload cifrado) sin red.
  static ResolvedStream? debugVoeSource(String html, [String pageUrl = '']) =>
      _voeSource(
        html,
        pageUrl.isEmpty ? 'https://eugenemakedraw.com/e/id' : pageUrl,
      );

  static String? _safeWebRedirect(String html, String sourceUrl) {
    final source = Uri.tryParse(sourceUrl);
    if (source == null || source.scheme != 'https') return null;
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
            !target.hasAuthority) {
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

  static ResolvedStream? _voeSource(String html, String pageUrl) {
    final page = Uri.tryParse(pageUrl);
    if (page == null ||
        page.scheme != 'https' ||
        !_isTrustedVoeAlias(page.host)) {
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
