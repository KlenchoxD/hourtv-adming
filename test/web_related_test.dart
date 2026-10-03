import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamtv/models/channel.dart';
import 'package:streamtv/new_ui/hourtv_web_related.dart';

void main() {
  testWidgets('seis tarjetas ocupan la fila hasta el margen derecho', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: HourTvWebRelated(
              channels: List.generate(
                6,
                (i) => Channel(
                  name: 'Título $i',
                  url: 'https://example.com/$i',
                  forcedType: 'movie',
                ),
              ),
              onOpen: (_) {},
            ),
          ),
        ),
      ),
    );
    final cards = find.byType(InkWell);
    expect(cards, findsNWidgets(6));
    expect(tester.getTopLeft(cards.first).dx, closeTo(32, 0.1));
    expect(tester.getBottomRight(cards.last).dx, closeTo(1408, 0.1));
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'Relacionado muestra metadatos reales y abre la ficha seleccionada',
    (tester) async {
      final movie = Channel(
        name: 'Película relacionada',
        url: 'https://example.com/movie',
        year: '2024',
        rating: '8.4',
        genre: 'Misterio, Aventura',
        forcedType: 'movie',
      );
      Channel? opened;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HourTvWebRelated(
              channels: [movie],
              onOpen: (c) => opened = c,
            ),
          ),
        ),
      );
      expect(find.text('También te puede gustar'), findsOneWidget);
      expect(find.text('8.4'), findsOneWidget);
      expect(find.text('2024 · Misterio'), findsOneWidget);
      await tester.tap(find.text('Película relacionada'));
      expect(opened, same(movie));
      expect(tester.takeException(), isNull);
    },
  );
}
