import 'package:flutter_test/flutter_test.dart';
import 'package:streamtv/models/channel.dart';
import 'package:streamtv/services/likes_service.dart';

void main() {
  test('clave estable: no depende del servidor del video', () {
    final a = Channel(name: 'Coco', url: 'https://a/movie/1.mp4', tvgId: '42');
    final b = Channel(name: 'Coco', url: 'https://b/movie/2.mp4', tvgId: '42');
    expect(LikesService.keyFor(a), LikesService.keyFor(b));
    expect(LikesService.keyFor(a), 'movie:42');

    final series = Channel(
      name: 'Miraculous',
      url: 'hourtv-series:https%3A%2F%2Fhost:serie-7',
      forcedType: 'series',
    );
    expect(LikesService.keyFor(series), 'series:serie-7');
  });

  test('formato corto del total', () {
    expect(LikesService.format(0), '0');
    expect(LikesService.format(12), '12');
    expect(LikesService.format(1200), '1,2 mil');
    expect(LikesService.format(15000), '15 mil');
    expect(LikesService.format(3400000), '3,4 M');
  });
}
