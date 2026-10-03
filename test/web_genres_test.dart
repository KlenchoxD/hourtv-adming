import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamtv/models/channel.dart';
import 'package:streamtv/new_ui/hourtv_web_genres.dart';

void main() {
  testWidgets('se apilan, se despliegan y seleccionan el género correcto', (
    tester,
  ) async {
    String? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: HourTvWebGenres(
              genres: const ['Terror', 'Misterio', 'Ciencia ficción'],
              onSelect: (g) => selected = g,
            ),
          ),
        ),
      ),
    );
    final target = find.byKey(const ValueKey('genre-Misterio'));
    final before = tester.getTopLeft(target).dx;
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(700, 400));
    await mouse.moveTo(const Offset(20, 20));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(target).dx, greaterThan(before));
    expect(find.text('Misterio'), findsOneWidget);
    await tester.tap(target);
    expect(selected, 'Misterio');
    await mouse.removePointer();
    expect(tester.takeException(), isNull);
  });
  test(
    'los resultados incluyen películas y series y excluyen otros géneros y TV',
    () {
      final movie = Channel(
        name: 'Película',
        url: 'movie:1',
        forcedType: 'movie',
        genre: 'Terror, Misterio',
      );
      final series = Channel(
        name: 'Serie',
        url: 'series:2',
        forcedType: 'series',
        genre: 'Terror',
      );
      final other = Channel(
        name: 'Comedia',
        url: 'movie:3',
        forcedType: 'movie',
        genre: 'Comedia',
      );
      expect(hourTvWebGenreResults([movie, series, other], 'Terror'), [
        movie,
        series,
      ]);
    },
  );
}
