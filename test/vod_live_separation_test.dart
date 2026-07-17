import 'package:flutter_test/flutter_test.dart';
import 'package:streamtv/models/channel.dart';
import 'package:streamtv/services/catalog_parser.dart';
import 'package:streamtv/services/content_store.dart';

void main() {
  test('las listas temáticas de IPTV-org siguen siendo En Vivo', () {
    final payload = CatalogParser.parse([
      {
        'name': 'Películas IPTV-org',
        'url': 'https://iptv-org.github.io/iptv/categories/movies.m3u',
        'type': 'movie',
      },
      {
        'name': 'Series IPTV-org',
        'url': 'https://iptv-org.github.io/iptv/categories/series.m3u',
        'type': 'series',
      },
    ]);

    expect(payload.lists, hasLength(2));
    expect(payload.lists.every((source) => source.mediaType == null), isTrue);
    expect(payload.lists.first.category, 'cine');
    expect(payload.lists.last.category, 'series');
  });

  test('movieGenres no expone fuentes y conserva Anime', () {
    final store = ContentStore.instance;
    final previous = store.all;
    addTearDown(() => store.all = previous);

    store.all = [
      Channel(
        name: 'Canal lineal',
        url: 'https://example.test/live.m3u8',
        genre: 'Películas IPTV-org',
      ),
      Channel(
        name: 'Película anime',
        url: 'https://example.test/anime.mp4',
        forcedType: 'movie',
        genre: 'Anime',
      ),
    ];

    expect(store.movies, hasLength(1));
    expect(store.movieGenres, ['Películas', 'Anime']);
    expect(store.movieGenres, isNot(contains('Películas IPTV-org')));
  });
}
