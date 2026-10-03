import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamtv/new_ui/hourtv_genre_symbols.dart';

void main() {
  testWidgets('los 22 símbolos se dibujan a tamaño pequeño y en hover', (
    tester,
  ) async {
    const genres = [
      'Acción',
      'Aventura',
      'Animación',
      'Comedia',
      'Drama',
      'Terror',
      'Suspenso',
      'Ciencia ficción',
      'Fantasía',
      'Crimen',
      'Misterio',
      'Documental',
      'Romance',
      'Familiar',
      'Bélica',
      'Historia',
      'Musical',
      'Western',
      'Policial',
      'Biografía',
      'Deportes',
      'Noticias',
    ];
    for (final bright in [false, true]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Wrap(
              children: [
                for (final genre in genres)
                  CustomPaint(
                    size: const Size(22, 22),
                    painter: HourTvGenreSymbol(genre, bright: bright),
                  ),
              ],
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    }
    expect(hourTvGenreSymbolKey('Infantil'), 'familiar');
    expect(hourTvGenreSymbolKey('Guerra'), 'belica');
  });
}
