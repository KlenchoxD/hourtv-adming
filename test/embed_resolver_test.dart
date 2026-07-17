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
}
