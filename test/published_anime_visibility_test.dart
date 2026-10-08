import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamtv/models/channel.dart';
import 'package:streamtv/mobile_ui/hourtv_mobile_shell.dart';
import 'package:streamtv/services/catalog_parser.dart';
import 'package:streamtv/services/catalog_presentation_index.dart';
import 'package:streamtv/services/content_store.dart';
import 'package:streamtv/services/parental_control_service.dart';
import 'package:streamtv/services/series_channel_projection.dart';
import 'package:streamtv/services/storage_service.dart';
import 'package:streamtv/services/xtream_service.dart';

XtreamSeries anime(String id, {String? name}) => XtreamSeries(
  seriesId: 'catalog:$id',
  name: name ?? 'Anime $id',
  host: '',
  username: '',
  password: '',
  genre: 'Animación, Action & Adventure',
  categories: ['anime', 'aventura'],
);

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    ContentStore.instance.resetForTesting();
  });

  test(
    'published categories survive parsing, projection and the Anime filter',
    () {
      final payload = CatalogParser.parse({
        'version': 1,
        'series': [
          {
            'id': 'new-anime',
            'title': 'Anime publicado',
            'genre': 'Animación, Drama',
            'categories': ['anime', 'drama'],
            'seasons': [
              {
                'number': 1,
                'episodes': [
                  {
                    'number': 1,
                    'servers': [
                      {
                        'name': 'Servidor',
                        'url': 'https://example.test/e1.mp4',
                        'language': 'Español',
                      },
                    ],
                  },
                ],
              },
            ],
          },
        ],
      });
      final content = hourTvMobileCatalogContent(
        payload.channels,
        payload.series,
      );
      final results = CatalogPresentationIndex.build(
        content,
      ).search(const CatalogQuery(type: ContentTypeFilter.anime));
      expect(results.map((c) => c.name), ['Anime publicado']);
      expect(results.single.categories, ['anime', 'drama']);
      expect(payload.series.single.episodes, hasLength(1));
    },
  );

  test('projection copies categories instead of sharing a mutable list', () {
    final source = anime('one');
    final card = hourTvSeriesChannel(source);
    source.categories.add('recomendado');
    expect(card.categories, ['anime', 'aventura']);
    expect(card.url, hourTvSeriesKey(source));
  });

  test(
    'home anime row includes movies and structured series, without duplicates or live TV',
    () {
      final store = ContentStore.instance;
      store.series = [anime('one')];
      store.all = [
        Channel(
          name: 'Anime película',
          url: 'https://example.test/movie',
          forcedType: 'movie',
          categories: ['anime'],
        ),
        Channel(
          name: 'Anime one',
          url: 'https://example.test/duplicate',
          forcedType: 'series',
          categories: ['anime'],
        ),
        Channel(
          name: 'Canal Anime',
          url: 'https://example.test/live',
          categories: ['anime'],
        ),
        Channel(
          name: 'Solo animación',
          url: 'https://example.test/cartoon',
          forcedType: 'movie',
          genre: 'Animación',
        ),
      ];
      expect(store.anime.map((c) => c.name), ['Anime one', 'Anime película']);
      expect(store.all, hasLength(4));
    },
  );

  test('home cache invalidates when only structured series change', () {
    final store = ContentStore.instance;
    store.series = [anime('one')];
    expect(store.anime.single.name, 'Anime one');
    store.series = [anime('two')];
    expect(store.anime.single.name, 'Anime two');
    store.series.add(anime('three'));
    expect(store.anime.map((c) => c.name), ['Anime two', 'Anime three']);
  });

  test('home cache respects parental filtering of structured series', () async {
    final store = ContentStore.instance;
    final adult = anime('adult')..categories.add('adulto');
    store.series = [anime('safe'), adult];
    expect(store.anime, hasLength(2));
    await StorageService.saveSetting(ParentalControlService.enabledKey, true);
    expect(store.anime.map((c) => c.name), ['Anime safe']);
  });

  test(
    'real published anime series are visible in the index and home row',
    () {
      final payload = CatalogParser.parse(
        jsonDecode(
          File(
            Platform.environment['HOURTV_PUBLISHED_CATALOG_TEST_PATH']!,
          ).readAsStringSync(),
        ),
      );
      final published = payload.series
          .where((s) => s.categories.contains('anime'))
          .toList();
      expect(published, isNotEmpty);
      final expectedNames = published.map((s) => s.name).toSet();
      final content = hourTvMobileCatalogContent(
        payload.channels,
        payload.series,
      );
      final filtered = CatalogPresentationIndex.build(
        content,
      ).search(const CatalogQuery(type: ContentTypeFilter.anime));
      expect(filtered.map((c) => c.name).toSet(), containsAll(expectedNames));
      final store = ContentStore.instance;
      store.all = payload.channels;
      store.series = payload.series;
      expect(
        store.anime.map((c) => c.name).toSet(),
        containsAll(expectedNames),
      );
    },
    skip: !Platform.environment.containsKey(
      'HOURTV_PUBLISHED_CATALOG_TEST_PATH',
    ),
  );

  testWidgets(
    'async home warmup includes structured series and matches the direct getter',
    (tester) async {
      final store = ContentStore.instance;
      store.series = [anime('one')];
      final work = store.warmHomeGenreRows();
      await tester.pumpAndSettle();
      await work;
      expect(store.homeGenreRowsReady, isTrue);
      expect(store.anime.map((c) => c.name), ['Anime one']);
      store.series = [anime('two')];
      expect(store.homeGenreRowsReady, isFalse);
      expect(store.anime.single.name, 'Anime two');
    },
  );
}
