import 'package:http/http.dart' as http;

/// Stream directo extraído de una página embed, con las cabeceras que su CDN
/// exige (Referer/User-Agent), para reproducirlo nativo en ExoPlayer.
class ResolvedStream {
  final String url;
  final Map<String, String> headers;
  const ResolvedStream(this.url, this.headers);
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

  static Future<ResolvedStream?> resolve(String embedUrl) async {
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
      if (res.statusCode != 200 || res.body.isEmpty) return null;
      final html = res.body;
      final source = _extractSource(html);
      if (source == null) return null;
      final absolute = _absolute(source, embedUrl);
      // El CDN de estos hosts suele exigir Referer del propio sitio.
      return ResolvedStream(absolute, {
        'User-Agent': _ua,
        'Referer': '$origin/',
      });
    } catch (_) {
      return null;
    }
  }

  /// Solo para pruebas: expone la extracción sin red.
  static String? debugExtract(String html) => _extractSource(html);

  /// Busca la URL del stream en el HTML: primero desempaqueta el packer, y si
  /// no hay, mira el HTML crudo (algunos ponen sources:[{file:"..."}] directo).
  static String? _extractSource(String html) {
    final unpacked = _unpack(html);
    for (final text in [unpacked, html]) {
      if (text == null) continue;
      // 1) URL .m3u8/.mp4 absoluta.
      final direct = RegExp(
        r'''https?://[^"'\\ )]+\.(?:m3u8|mp4)[^"'\\ )]*''',
      ).firstMatch(text);
      if (direct != null) return direct.group(0);
      // 2) file:"..." / "file":"..." dentro de la config del reproductor.
      final fileField = RegExp(
        r'''["']?file["']?\s*:\s*["']([^"']+\.(?:m3u8|mp4)[^"']*)["']''',
      ).firstMatch(text);
      if (fileField != null) return fileField.group(1);
      // 3) sources:[{file:"..."}] con ruta relativa.
      final rel = RegExp(
        r'''["']?file["']?\s*:\s*["'](/[^"']+\.(?:m3u8|mp4)[^"']*)["']''',
      ).firstMatch(text);
      if (rel != null) return rel.group(1);
    }
    return null;
  }

  /// Desempaqueta el clásico `eval(function(p,a,c,k,e,d){...}('P',A,C,'W'.split('|')))`.
  /// Sustitución pura de tokens base-N por palabras; sin evaluar código.
  static String? _unpack(String js) {
    final m = RegExp(
      r"\}\s*\(\s*'(.*?)'\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*'(.*?)'\s*\.split\('\|'\)",
      dotAll: true,
    ).firstMatch(js);
    if (m == null) return null;
    var payload = m
        .group(1)!
        .replaceAll(r"\'", "'")
        .replaceAll(r'\\', r'\');
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
