import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamtv/mobile_ui/hourtv_anime_calendar_page.dart';
import 'package:streamtv/services/anime_schedule_service.dart';
import 'package:streamtv/services/content_store.dart';
import 'package:streamtv/services/storage_service.dart';
import 'package:streamtv/services/xtream_service.dart';

void main() {
  final store = ContentStore.instance;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    store.resetForTesting();
  });
  tearDown(store.resetForTesting);
  for (final size in [const Size(360, 800), const Size(800, 360)]) {
    testWidgets(
      'calendar filters dates and opens only matched anime at $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final item = XtreamSeries(
          seriesId: 'blue',
          name: 'Blue Period',
          host: '',
          username: '',
          password: '',
          categories: ['anime'],
        );
        store.series = [item];
        final today = DateTime(2026, 10, 7, 12);
        final client = MockClient(
          (request) async => http.Response(
            jsonEncode({
              'data': {
                'Page': {
                  'pageInfo': {'hasNextPage': false},
                  'airingSchedules': [
                    for (final row in [
                      (1, 'Blue Period', 7),
                      (2, 'Future Anime', 8),
                    ])
                      {
                        'episode': 2,
                        'airingAt':
                            DateTime(
                              2026,
                              10,
                              row.$3,
                              10,
                            ).millisecondsSinceEpoch ~/
                            1000,
                        'media': {
                          'id': row.$1,
                          'status': 'RELEASING',
                          'title': {'romaji': row.$2},
                          'synonyms': [],
                          'isAdult': false,
                          'coverImage': {},
                        },
                      },
                  ],
                },
              },
            }),
            200,
          ),
        );
        XtreamSeries? opened;
        await tester.pumpWidget(
          MaterialApp(
            home: HourTvAnimeCalendarPage(
              store: store,
              onOpenAnime: (v) => opened = v,
              now: () => today,
              service: AnimeScheduleService(client: client, now: () => today),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Blue Period'), findsOneWidget);
        expect(find.text('Future Anime'), findsNothing);
        await tester.ensureVisible(find.text('Blue Period'));
        await tester.tap(find.text('Blue Period'));
        await tester.pump();
        expect(opened, same(item));
        await tester.tap(find.text('Jue'));
        await tester.pump();
        expect(find.text('Future Anime'), findsOneWidget);
        expect(find.text('Aún no está en HourTV'), findsOneWidget);
        await tester.tap(find.text('En HourTV'));
        await tester.pump();
        expect(find.text('No hay emisiones de tu catálogo'), findsOneWidget);
        await tester.tap(find.text('Últimos estrenos'));
        await tester.pump();
        expect(find.text('Blue Period'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
