import 'package:flutter_test/flutter_test.dart';
import 'package:streamtv/widgets/vod_detail_widgets.dart';

void main() {
  group('ficha VOD compartida', () {
    test('oculta actores cuando repiten la sinopsis', () {
      expect(
        isDistinctDetailCast(
          'Una aventura épica, en el espacio.',
          'Una aventura épica en el espacio',
        ),
        isFalse,
      );
      expect(
        isDistinctDetailCast('Ana Pérez, Luis Díaz', 'Una aventura épica'),
        isTrue,
      );
      expect(isDistinctDetailCast('', 'Sinopsis'), isFalse);
    });

    test('normaliza y elimina géneros duplicados', () {
      expect(splitDetailGenres('Acción, Drama / acción | Infantil'), [
        'Acción',
        'Drama',
        'Infantil',
      ]);
    });
  });
}
