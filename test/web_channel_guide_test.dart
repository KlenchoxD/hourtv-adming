import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamtv/models/channel.dart';
import 'package:streamtv/new_ui/hourtv_web_channel_guide.dart';

void main() {
  testWidgets('guía busca, filtra categorías, favoritos y selecciona canal', (
    tester,
  ) async {
    final sport = Channel(name: '5Sport', url: 'live:1', genre: 'Deportes');
    final news = Channel(
      name: 'Noticias Uno',
      url: 'live:2',
      genre: 'Noticias',
      isFavorite: true,
    );
    Channel? selected, favorite;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 420,
            child: HourTvWebChannelGuide(
              channels: [sport, news],
              currentUrl: sport.url,
              onSelect: (c) => selected = c,
              onFavorite: (c) => favorite = c,
            ),
          ),
        ),
      ),
    );
    expect(find.text('5Sport'), findsOneWidget);
    expect(find.text('Noticias Uno'), findsOneWidget);
    await tester.tap(find.byTooltip('Añadir a favoritos'));
    expect(favorite, sport);
    expect(selected, isNull);
    await tester.tap(find.text('Noticias Uno'));
    expect(selected, news);
    await tester.tap(find.text('Favoritos'));
    await tester.pumpAndSettle();
    expect(find.text('5Sport'), findsNothing);
    expect(find.text('Noticias Uno'), findsOneWidget);
    await tester.tap(find.text('Todos'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Todas'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Deportes').last);
    await tester.pumpAndSettle();
    expect(find.text('Noticias Uno'), findsNothing);
    await tester.enterText(find.byType(TextField), 'no existe');
    await tester.pumpAndSettle();
    expect(find.text('No hay canales con estos filtros.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
