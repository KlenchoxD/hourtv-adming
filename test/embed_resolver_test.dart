import 'package:flutter_test/flutter_test.dart';
import 'package:streamtv/services/embed_resolver.dart';

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
}
