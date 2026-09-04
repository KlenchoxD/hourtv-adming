import 'package:flutter_test/flutter_test.dart';
import 'package:streamtv/new_ui/hourtv_detail_page.dart';

void main() {
  test('oculta el reparto cuando repite la sinopsis', () {
    expect(
      isDistinctDetailCast(
        'Una aventura épica, en el espacio.',
        'Una aventura épica en el espacio',
      ),
      isFalse,
    );
  });

  test('muestra el reparto cuando es distinto de la sinopsis', () {
    expect(
      isDistinctDetailCast('Ana Pérez, Luis Díaz', 'Una aventura épica'),
      isTrue,
    );
    expect(isDistinctDetailCast('Ana Pérez', ''), isTrue);
    expect(isDistinctDetailCast('Ana Pérez', null), isTrue);
  });
}
