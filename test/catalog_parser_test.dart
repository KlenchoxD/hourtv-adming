import 'package:flutter_test/flutter_test.dart';
import 'package:streamtv/models/channel.dart';
import 'package:streamtv/services/catalog_parser.dart';

void main() {
  group('CatalogParser', () {
    test('maps the rich admin catalog', () {
      final payload = CatalogParser.parse({
        'version': 1,
        'movies': [
          {
            'id': 'movie-1',
            'title': 'Movie One',
            'poster': 'https://img.test/poster.jpg',
            'backdrop': 'https://img.test/backdrop.jpg',
            'year': 2026,
            'rating': 8.4,
            'duration': '120 min',
            'genre': 'Drama',
            'plot': 'Plot',
            'cast': 'Actor One',
            'director': 'Director One',
            'categories': ['estrenos', 'drama'],
            'featured': true,
            'servers': [
              {'name': 'Servidor 1', 'url': 'https://video.test/one.m3u8'},
              {'name': 'Servidor 2', 'url': 'https://video.test/two.m3u8'},
            ],
          },
        ],
        'series': [
          {
            'id': 'series-1',
            'title': 'Series One',
            'poster': 'https://img.test/series.jpg',
            'plot': 'Series plot',
            'seasons': [
              {
                'number': 2,
                'episodes': [
                  {
                    'number': 3,
                    'title': 'Episode Three',
                    'servers': [
                      {
                        'name': 'Servidor 1',
                        'url': 'https://video.test/s02e03.m3u8',
                      },
                      {
                        'name': 'Servidor 2',
                        'url': 'https://backup.test/s02e03.m3u8',
                      },
                    ],
                  },
                ],
              },
            ],
          },
        ],
        'liveChannels': [
          {
            'name': 'Live One',
            'logo': 'https://img.test/live.png',
            'group': 'News',
            'url': 'https://video.test/live.m3u8',
            'userAgent': 'HourTV Test',
          },
        ],
        'sources': [
          {
            'name': 'Movies M3U',
            'url': 'https://list.test/movies.m3u',
            'type': 'movie',
          },
        ],
      });

      expect(payload.channels, hasLength(2));
      final movie = payload.channels.first;
      expect(movie.type, MediaType.movie);
      expect(movie.url, 'https://video.test/one.m3u8');
      expect(movie.servers, hasLength(2));
      expect(movie.categories, ['estrenos', 'drama']);
      expect(movie.isFeatured, isTrue);
      expect(movie.year, '2026');
      expect(movie.rating, '8.4');

      final live = payload.channels.last;
      expect(live.type, MediaType.live);
      expect(live.userAgent, 'HourTV Test');

      expect(payload.series, hasLength(1));
      final series = payload.series.single;
      expect(series.episodes, hasLength(1));
      expect(series.episodes!.single.group, 'T2');
      expect(series.episodes!.single.type, MediaType.series);
      expect(series.episodes!.single.servers, hasLength(2));
      expect(payload.lists.single.mediaType, 'movie');
    });

    test('keeps the legacy flat source format', () {
      final payload = CatalogParser.parse([
        {
          'name': 'Legacy movies',
          'url': 'https://list.test/legacy.m3u',
          'type': 'movie',
          'userAgent': 'Legacy UA',
        },
        {'name': 'Guide', 'url': 'https://list.test/guide.xml', 'type': 'epg'},
      ]);

      expect(payload.channels, isEmpty);
      expect(payload.series, isEmpty);
      expect(payload.lists, hasLength(1));
      expect(payload.lists.single.mediaType, 'movie');
      expect(payload.lists.single.userAgent, 'Legacy UA');
      expect(payload.epgUrls, ['https://list.test/guide.xml']);
    });

    test('persists alternate servers in Channel JSON', () {
      final channel = Channel(
        name: 'Movie',
        url: 'https://video.test/one.m3u8',
        forcedType: 'movie',
        categories: const ['featured'],
        isFeatured: true,
        servers: const [
          ChannelServer(name: 'Servidor 1', url: 'https://video.test/one.m3u8'),
          ChannelServer(name: 'Servidor 2', url: 'https://video.test/two.m3u8'),
        ],
      );

      final restored = Channel.fromJson(channel.toJson());
      expect(restored.servers, hasLength(2));
      expect(restored.servers.last.url, 'https://video.test/two.m3u8');
      expect(restored.categories, ['featured']);
      expect(restored.isFeatured, isTrue);
    });
  });
}
