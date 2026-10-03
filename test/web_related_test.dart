import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamtv/models/channel.dart';
import 'package:streamtv/new_ui/hourtv_web_related.dart';

void main() {
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
