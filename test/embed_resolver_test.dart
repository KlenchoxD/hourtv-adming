import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:streamtv/services/embed_resolver.dart';

/// Cifra un payload con el esquema inverso de VOE, para generar fixtures:
/// b64(json) -> reverse -> shift(+3) -> b64 -> secuencias especiales -> rot13.
String _voeEncrypt(String payloadJson) {
  final e1 = base64Encode(payloadJson.codeUnits);
  final e2 = e1.split('').reversed.join();
  final e3 = String.fromCharCodes(e2.codeUnits.map((c) => c + 3));
  final e4 = base64Encode(e3.codeUnits);
  final withSpecials = e4
      .replaceAll('@', '@\$')
      .replaceAll('^', '^^')
      .replaceAll('!', '!!');
  return String.fromCharCodes(withSpecials.codeUnits.map(_rot13Char));
}

int _rot13Char(int c) {
  if (c >= 65 && c <= 90) return ((c - 65 + 13) % 26) + 65;
  if (c >= 97 && c <= 122) return ((c - 97 + 13) % 26) + 97;
  return c;
}

String _voeScriptTag(String encrypted) =>
    '<script type="application/json">["$encrypted"]</script>';

void main() {
  // El packer sustituye tokens base-36 por palabras. Este ejemplo mínimo
  // codifica sources:[{file:"https://cdn.test/x/master.m3u8"}] con radix 36.
  // Tokens: 0->sources, 1->file, 2->https, 3->cdn, 4->master
  test('extractSource desempaqueta el packer y saca el m3u8', () {
    const packed =
        '''eval(function(p,a,c,k,e,d){while(c--)if(k[c])p=p.replace(new RegExp('\\\\b'+c.toString(a)+'\\\\b','g'),k[c]);return p}('0:[{1:"2://3.test/x/4.m3u8"}]',36,5,'sources|file|https|cdn|master'.split('|')))''';
    final url = EmbedResolver.debugExtract(packed);
    expect(url, 'https://cdn.test/x/master.m3u8');
  });

  test('extractSource encuentra m3u8 directo sin packer', () {
    const html = 'var x = "https://host.tv/live/stream.m3u8?t=1"; //...';
    expect(
      EmbedResolver.debugExtract(html),
      'https://host.tv/live/stream.m3u8?t=1',
    );
  });

  test('devuelve null si no hay stream', () {
    expect(EmbedResolver.debugExtract('<html>nada aqui</html>'), isNull);
  });

  test('detecta la redireccion HTTPS legitima de VOE', () {
    const html = '''<script>
      window.location.href = 'https://eugenemakedraw.com/e/2suzh7well4u';
    </script>''';

    expect(
      EmbedResolver.debugSafeWebRedirect(html, 'https://voe.sx/e/2suzh7well4u'),
      'https://eugenemakedraw.com/e/2suzh7well4u',
    );
  });

  test('rechaza redirecciones de VOE hacia publicidad o HTTP', () {
    const ad =
        "<script>window.location.href='https://ads.example/click';</script>";
    const insecure =
        "<script>window.location.href='http://eugenemakedraw.com/e/id';</script>";

    expect(
      EmbedResolver.debugSafeWebRedirect(ad, 'https://voe.sx/e/id'),
      isNull,
    );
    expect(
      EmbedResolver.debugSafeWebRedirect(insecure, 'https://voe.sx/e/id'),
      isNull,
    );
  });

  test('no extrae el MP4 señuelo conocido de la pagina destino de VOE', () {
    const html = '''<script>
      var source = 'https://test-videos.co.uk/vids/bigbuckbunny/mp4/h264/720/Big_Buck_Bunny_720_10s_1MB.mp4';
    </script>''';

    expect(EmbedResolver.debugExtract(html), isNull);
  });

  test('conserva la extraccion nativa de Barmonrey', () {
    const html = '''<script>
      jwplayer('player').setup({
        sources: [{file: 'https://spark.9bg.net/media/example/master.m3u8'}]
      });
    </script>''';

    expect(
      EmbedResolver.debugExtract(html),
      'https://spark.9bg.net/media/example/master.m3u8',
    );
  });

  // ─────────────────────────────────────────────────────────────────────
  // VOE nativo: el payload application/json cifrado contiene el m3u8 real.
  // ─────────────────────────────────────────────────────────────────────

  group('VOE payload cifrado (application/json)', () {
    final payload = jsonEncode({
      'key': 'k',
      'file_code': '2suzh7well4u',
      'title': 'QNFTRS79BM6984FGD45L1X1 (1).mkv',
      'source':
          'https://cdn.voe.example/engine/hls2/01/17384/2suzh7well4u_,n,.urlset/master.m3u8?t=TOKEN',
      'fallback': [],
      'captions': [],
    });

    test('extrae el m3u8 real del payload cifrado de VOE', () {
      final html =
          '<html><body>señuelo previo</body>'
          '${_voeScriptTag(_voeEncrypt(payload))}'
          '<script>var source=\'https://test-videos.co.uk/vids/bigbuckbunny/mp4/h264/720/Big_Buck_Bunny_720_10s_1MB.mp4\';</script>'
          '</html>';
      expect(
        EmbedResolver.debugExtract(html),
        'https://cdn.voe.example/engine/hls2/01/17384/2suzh7well4u_,n,.urlset/master.m3u8?t=TOKEN',
      );
    });

    test('prefiere el m3u8 (source) sobre el mp4 de fallback', () {
      final payloadWithFallback = jsonEncode({
        'file_code': '2suzh7well4u',
        'source': 'https://cdn.voe.example/hls/master.m3u8?t=TOKEN',
        'fallback': [
          {
            'type': 'mp4',
            'label': '1080',
            'file': 'https://cdn.voe.example/dl/video_1080.mp4?t=TOKEN',
          },
        ],
      });
      final html = _voeScriptTag(_voeEncrypt(payloadWithFallback));
      expect(
        EmbedResolver.debugExtract(html),
        'https://cdn.voe.example/hls/master.m3u8?t=TOKEN',
      );
    });

    test('usa el mp4 de fallback legitim si no hay source hls', () {
      final payloadMp4Only = jsonEncode({
        'file_code': '2suzh7well4u',
        'source': null,
        'fallback': [
          {
            'type': 'mp4',
            'label': '720',
            'file': 'https://cdn.voe.example/dl/video_720.mp4?t=TOKEN',
          },
        ],
      });
      final html = _voeScriptTag(_voeEncrypt(payloadMp4Only));
      expect(
        EmbedResolver.debugExtract(html),
        'https://cdn.voe.example/dl/video_720.mp4?t=TOKEN',
      );
    });

    test('un payload corrupto no rompe la extraccion ni elige el señuelo', () {
      const corrupt =
          '<script type="application/json">["no-base64!!"]</script>'
          '<script>var source=\'https://test-videos.co.uk/x.mp4\';</script>';
      expect(EmbedResolver.debugExtract(corrupt), isNull);
    });

    test('exposicion de debug del descifrado VOE', () {
      final html = _voeScriptTag(_voeEncrypt(payload));
      final resolved = EmbedResolver.debugVoeSource(html);
      expect(resolved, isNotNull);
      expect(
        resolved!.url,
        'https://cdn.voe.example/engine/hls2/01/17384/2suzh7well4u_,n,.urlset/master.m3u8?t=TOKEN',
      );
      // El Referer que exige el CDN de VOE: el origen de la pagina embed.
      expect(resolved.headers['Referer'], 'https://eugenemakedraw.com/');
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  // Orquestacion: VOE debe resolverse NATIVO siguiendo su propia
  // redireccion, sin caer al WebView.
  // ─────────────────────────────────────────────────────────────────────

  group('VOE sigue su redireccion a alias y resuelve nativo (sin red)', () {
    final voePayload = jsonEncode({
      'key': 'k',
      'file_code': '2suzh7well4u',
      'title': 'QNFTRS79BM6984FGD45L1X1 (1).mkv',
      'source':
          'https://cdn.voe.example/engine/hls2/01/17384/2suzh7well4u_,n,.urlset/master.m3u8?t=TOKEN',
      'fallback': [],
      'captions': [],
    });

    test('resolveForPlayback voe.sx -> eugenemakedraw.com entrega stream', () {
      final resolution = EmbedResolver.debugResolve(
        // Pagina voe.sx: solo redirige
        'https://voe.sx/e/2suzh7well4u',
        [
          (
            'https://voe.sx/e/2suzh7well4u',
            '<script>window.location.href = '
                "'https://eugenemakedraw.com/e/2suzh7well4u';</script>",
          ),
          (
            'https://eugenemakedraw.com/e/2suzh7well4u',
            _voeScriptTag(_voeEncrypt(voePayload)),
          ),
        ],
      );
      expect(
        resolution.stream,
        isNotNull,
        reason: 'VOE debe resolverse nativo, no con WebView',
      );
      expect(resolution.safeWebUrl, isNull);
      expect(
        resolution.stream!.url,
        'https://cdn.voe.example/engine/hls2/01/17384/2suzh7well4u_,n,.urlset/master.m3u8?t=TOKEN',
      );
      expect(
        resolution.stream!.headers['Referer'],
        'https://eugenemakedraw.com/',
      );
    });

    test(
      'si el alias tampoco resuelve, safeWebUrl queda como ultimo recurso',
      () {
        final resolution =
            EmbedResolver.debugResolve('https://voe.sx/e/2suzh7well4u', [
              (
                'https://voe.sx/e/2suzh7well4u',
                '<script>window.location.href = '
                    "'https://eugenemakedraw.com/e/2suzh7well4u';</script>",
              ),
              (
                'https://eugenemakedraw.com/e/2suzh7well4u',
                '<html>sin payload util</html>',
              ),
            ]);
        expect(resolution.stream, isNull);
        expect(
          resolution.safeWebUrl,
          'https://eugenemakedraw.com/e/2suzh7well4u',
          reason:
              'Sin resolucion nativa posible, el WebView es el ultimo '
              'recurso y debe recibir el alias verificado',
        );
      },
    );

    test('Barmonrey resuelve nativo directamente (sin redireccion)', () {
      const barmonrey =
          '<script>jwplayer("v").setup({sources: [{file: '
          '"https://spark.9bg.net/x/master.m3u8"}]});</script>';
      final resolution = EmbedResolver.debugResolve(
        'https://barmonrey.com/player/ABC/',
        [('https://barmonrey.com/player/ABC/', barmonrey)],
      );
      expect(resolution.stream, isNotNull);
      expect(resolution.stream!.url, 'https://spark.9bg.net/x/master.m3u8');
      expect(resolution.stream!.headers['Referer'], 'https://barmonrey.com/');
    });

    test('no interpreta application/json de un host generico como VOE', () {
      final genericPayload = jsonEncode({
        'source': 'https://cdn.example/private/master.m3u8',
      });
      final html = '<script type="application/json">$genericPayload</script>';

      expect(
        EmbedResolver.debugVoeSource(html, 'https://example.com/embed/123'),
        isNull,
      );
    });

    test('rechaza fuentes VOE sin HTTPS', () {
      final insecurePayload = jsonEncode({
        'file_code': 'id',
        'source': 'http://cdn.voe.example/master.m3u8',
        'fallback': const [],
      });

      expect(
        EmbedResolver.debugVoeSource(
          _voeScriptTag(_voeEncrypt(insecurePayload)),
        ),
        isNull,
      );
    });
  });
}
