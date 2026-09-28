import 'package:flutter_test/flutter_test.dart';
import 'package:streamtv/models/channel.dart';
import 'package:streamtv/services/likes_service.dart';

void main() {
  Channel movie(String id) => Channel(
    name: 'Película $id',
    url: 'https://cdn.test/$id.mp4',
    tvgId: id,
    forcedType: 'movie',
  );

  test('ordena el catálogo visible según el ranking de Me gusta', () {
    final a = movie('a'), b = movie('b'), c = movie('c');
    final ranked = LikesService.rank(
      [
        ('movie:c', 9),
        ('movie:fuera-del-catalogo', 7), // p. ej. oculto en perfil infantil
        ('movie:a', 3),
        ('movie:b', 0),
      ],
      [a, b, c],
    );
    expect(ranked, [c, a]);
  });

  test('reconoce Me gusta antiguos guardados por URL', () {
    final a = movie('a');
    expect(LikesService.rank([(a.url, 2)], [a]), [a]);
  });

  test('sin ranking no hay fila', () {
    expect(LikesService.rank(const [], [movie('a')]), isEmpty);
  });
}
