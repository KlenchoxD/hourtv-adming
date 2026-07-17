import 'package:flutter_test/flutter_test.dart';
import 'package:streamtv/services/m3u_parser_service.dart';

void main() {
  test('el nombre no se corta por comas dentro del user-agent', () {
    // El user-agent tiene una coma interna en "(KHTML, like Gecko)". El nombre
    // real ("Caracol HD") va tras la coma que cierra los atributos.
    const m3u =
        '#EXTM3U\n'
        '#EXTINF:-1 tvg-id="Caracol.co" '
        'user-agent="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36" '
        'tvg-logo="http://logo/caracol.png",Caracol HD\n'
        'http://stream/caracol.m3u8\n';

    final channels = M3UParserService.parseM3U(m3u);

    expect(channels, hasLength(1));
    expect(channels.first.name, 'Caracol HD');
    expect(channels.first.url, 'http://stream/caracol.m3u8');
    expect(channels.first.logo, 'http://logo/caracol.png');
  });

  test('nombre simple sin atributos con comas sigue funcionando', () {
    const m3u =
        '#EXTM3U\n'
        '#EXTINF:-1 tvg-id="RCN.co",RCN Television\n'
        'http://stream/rcn.m3u8\n';

    final channels = M3UParserService.parseM3U(m3u);

    expect(channels, hasLength(1));
    expect(channels.first.name, 'RCN Television');
  });
}
