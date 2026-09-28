import 'package:flutter_test/flutter_test.dart';
import 'package:streamtv/models/channel.dart';
import 'package:streamtv/services/catalog/catalog_detail_navigator.dart';

void main() {
  Channel movie(String id, String url) =>
      Channel(name: 'Orgullo', url: url, tvgId: id, forcedType: 'movie');

  test('Biblioteca abre la versión actual del catálogo, no la guardada', () {
    final saved = movie('m1', 'https://barmonrey.com/v/viejo');
    final fresh = movie('m1', 'https://paulinito.com/player/nuevo/');
    final other = movie('m2', 'https://x.test/otra');
    expect(current(saved, [other, fresh]), same(fresh));
  });

  test('si ya no está en el catálogo, se usa la copia guardada', () {
    final saved = movie('m1', 'https://barmonrey.com/v/viejo');
    expect(current(saved, [movie('m2', 'https://x.test')]), same(saved));
  });

  test('los canales en vivo no se reemplazan', () {
    final live = Channel(name: 'Canal', url: 'https://l.test/1.m3u8', tvgId: 'c1');
    final other = Channel(name: 'Canal', url: 'https://l.test/2.m3u8', tvgId: 'c1');
    expect(current(live, [other]), same(live));
  });
}
