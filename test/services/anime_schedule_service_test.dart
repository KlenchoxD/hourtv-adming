import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamtv/services/anime_schedule_service.dart';
import 'package:streamtv/services/xtream_service.dart';

Map<String, dynamic> media(
  int id, {
  String name = 'Blue Period',
  bool adult = false,
}) => {
  'id': id,
  'status': 'RELEASING',
  'title': {'romaji': name, 'english': null, 'native': null},
  'synonyms': <String>[],
  'isAdult': adult,
  'coverImage': {'large': null},
};
XtreamSeries series({
  int? id,
  String name = 'Periodo azul',
  bool anime = true,
}) => XtreamSeries(
  seriesId: 'blue',
  name: name,
  host: '',
  username: '',
  password: '',
  anilistId: id,
  sourceUrl: anime ? 'https://tokianime.tv/anime/blue-period' : null,
  categories: anime ? ['anime'] : [],
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'explicit different AniList id cannot be overridden by a similar title',
    () {
      final index = AnimeCatalogIndex([series(id: 999)]);
      expect(index.match(AnimeAiringMedia.fromJson(media(1))), isNull);
    },
  );
  test(
    'source alias identifies localized title; ordinary series and ambiguous matches are excluded',
    () {
      final item = series();
      final anime = AnimeAiringMedia.fromJson(media(1));
      expect(AnimeCatalogIndex([item]).match(anime), same(item));
      expect(
        AnimeCatalogIndex([
          series(name: 'Blue Period', anime: false),
        ]).match(anime),
        isNull,
      );
      expect(AnimeCatalogIndex([item, series()]).match(anime), isNull);
      expect(
        AnimeCatalogIndex([item]).match(
          AnimeAiringMedia.fromJson(media(2, name: 'Blue Period Season 2')),
        ),
        isNull,
      );
      final restored = XtreamSeries.fromJson(series(id: 1).toJson());
      expect(AnimeCatalogIndex([restored]).match(anime), same(restored));
    },
  );
  test(
    'weekly pagination filters adult content, deduplicates and survives offline refresh',
    () async {
      final start = DateTime(2026, 10, 5);
      var fail = false;
      final client = MockClient((request) async {
        if (fail) return http.Response('unavailable', 503);
        final v = jsonDecode(request.body)['variables'];
        final page = v['page'];
        Map<String, dynamic> entry(int id, {bool adult = false}) => {
          'episode': 2,
          'airingAt': DateTime(2026, 10, 6, 10).millisecondsSinceEpoch ~/ 1000,
          'media': media(id, adult: adult),
        };
        return http.Response(
          jsonEncode({
            'data': {
              'Page': {
                'pageInfo': {'hasNextPage': page == 1},
                'airingSchedules': page == 1
                    ? [entry(1), entry(2, adult: true)]
                    : [entry(1), entry(3)],
              },
            },
          }),
          200,
        );
      });
      final service = AnimeScheduleService(
        client: client,
        now: () => DateTime(2026, 10, 7),
      );
      final online = await service.loadWeek(start);
      expect(online.entries.map((e) => e.media.id), [1, 3]);
      final cached = await service.loadWeek(start);
      expect(cached.entries.map((e) => e.media.id), [1, 3]);
      fail = true;
      final offline = await service.loadWeek(start, refresh: true);
      expect(offline.stale, isTrue);
      expect(offline.entries.map((e) => e.media.id), [1, 3]);
    },
  );
  test(
    'API failure without cache is an error, not a fabricated empty calendar',
    () async {
      final service = AnimeScheduleService(
        client: MockClient((_) async => http.Response('{}', 429)),
      );
      await expectLater(
        service.loadWeek(DateTime(2026, 10, 5)),
        throwsA(isA<AnimeScheduleException>()),
      );
    },
  );
}
