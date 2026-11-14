import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamtv/models/channel.dart';
import 'package:streamtv/services/anime1v_service.dart';
import 'package:streamtv/services/content_store.dart';
import 'package:streamtv/services/parental_control_service.dart';
import 'package:streamtv/services/playback_source_fallback.dart';
import 'package:streamtv/services/storage_service.dart';
import 'package:streamtv/services/xtream_service.dart';
import 'package:video_player/video_player.dart';

http.Response _jsonResponse(Object payload, [int statusCode = 200]) {
  return http.Response.bytes(
    utf8.encode(jsonEncode(payload)),
    statusCode,
    headers: const {'content-type': 'application/json; charset=utf-8'},
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await StorageService.init();
    ContentStore.instance.resetForTesting();
    Anime1vService.instance.clearCache();
  });

  tearDown(() {
    ContentStore.instance.resetForTesting();
    Anime1vService.instance.clearCache();
  });

  test(
    'normalizeBaseUrl y sourceUrlFromSeriesId normalizan URLs válidas e ignoran inválidas',
    () {
      expect(
        Anime1vService.normalizeBaseUrl('https://mi-anime.vercel.app'),
        'https://mi-anime.vercel.app/api/v1/anime',
      );
      expect(
        Anime1vService.normalizeBaseUrl('https://mi-anime.vercel.app/custom/'),
        'https://mi-anime.vercel.app/custom',
      );
      expect(Anime1vService.normalizeBaseUrl(''), isNull);
      expect(Anime1vService.normalizeBaseUrl('ftp://invalido'), isNull);
      expect(Anime1vService.normalizeBaseUrl('no-es-url'), isNull);

      expect(
        Anime1vService.sourceUrlFromSeriesId('anime1v:animeav1.com:media/naruto'),
        'https://animeav1.com/media/naruto',
      );
      expect(Anime1vService.sourceUrlFromSeriesId('12345'), isNull);
    },
  );

  test(
    '/config actualiza la URL remota solo cuando se usa la URL por defecto',
    () async {
      final requestedUris = <Uri>[];
      final client = MockClient((request) async {
        requestedUris.add(request.url);
        if (request.url.path.endsWith('/config')) {
          return _jsonResponse({
            'publicBaseUrl': 'https://mirror.example.com/api/v1/anime',
          });
        }
        return _jsonResponse({
          'success': true,
          'data': {'results': []},
        });
      });

      final service = Anime1vService.forTesting(client: client);
      await service.fetchCatalog(page: 1, forceRefresh: true);

      expect(requestedUris.length, 2);
      expect(
        requestedUris.first.toString(),
        'https://hourtv-adming.vercel.app/api/v1/anime/config',
      );
      expect(
        requestedUris.last.toString(),
        'https://mirror.example.com/api/v1/anime/catalog?page=1&provider=animeav1',
      );
      expect(service.config.baseUrl, 'https://mirror.example.com/api/v1/anime');
      expect(service.config.usesDefaultBaseUrl, isTrue);
    },
  );

  test(
    'configuración personalizada omite /config y envía x-api-key',
    () async {
      final requestedHeaders = <Map<String, String>>[];
      final requestedUris = <Uri>[];
      final client = MockClient((request) async {
        requestedHeaders.add(request.headers);
        requestedUris.add(request.url);
        return _jsonResponse({
          'success': true,
          'data': {
            'results': [
              {
                'title': 'Frieren',
                'url': 'https://animeav1.com/media/frieren',
                'image': 'https://cdn.animeav1.com/covers/1.jpg',
                'genres': ['Fantasía', 'Aventura'],
                'score': 9.1,
              },
            ],
          },
        });
      });

      final service = Anime1vService.forTesting(client: client);
      await service.saveConfig(
        baseUrl: 'https://custom.hourtv.example/api/anime/',
        apiKey: 'clave-anime-123',
      );

      final items = await service.fetchCatalog(page: 1, forceRefresh: true);
      expect(items.length, 1);
      expect(
        requestedUris.single.toString(),
        'https://custom.hourtv.example/api/anime/catalog?page=1&provider=animeav1',
      );
      expect(requestedHeaders.single['x-api-key'], 'clave-anime-123');
      expect(service.config.usesDefaultBaseUrl, isFalse);
    },
  );

  test(
    'fetchInitialCatalog deduplica resultados y searchAnime respeta longitud mínima',
    () async {
      var httpCalls = 0;
      final client = MockClient((request) async {
        httpCalls++;
        if (request.url.path.endsWith('/catalog')) {
          final page = request.url.queryParameters['page'];
          final results = page == '1'
              ? [
                  {
                    'title': 'Dandadan',
                    'url': 'https://animeav1.com/media/dandadan',
                    'image': 'https://cdn.animeav1.com/covers/10.jpg',
                    'genres': ['Acción'],
                    'year': '2024',
                  },
                  {
                    'title': 'Naruto',
                    'url': 'https://animeav1.com/media/naruto',
                    'image': 'https://cdn.animeav1.com/covers/11.jpg',
                  },
                ]
              : [
                  // Duplicado de página 1 debe filtrarse.
                  {
                    'title': 'Naruto',
                    'url': 'https://animeav1.com/media/naruto',
                    'image': 'https://cdn.animeav1.com/covers/11.jpg',
                  },
                  {
                    'title': 'Bleach',
                    'url': 'https://animeav1.com/media/bleach',
                    'image': 'https://cdn.animeav1.com/covers/12.jpg',
                  },
                ];
          return _jsonResponse({'success': true, 'data': {'results': results}});
        }
        if (request.url.path.endsWith('/search')) {
          return _jsonResponse({
            'success': true,
            'data': {
              'results': [
                {
                  'title': 'Naruto Shippuden',
                  'url': 'https://tioanime.com/anime/naruto-shippuden',
                  'provider': 'tioanime',
                  'image': 'https://tioanime.com/uploads/portadas/2.jpg',
                },
              ],
            },
          });
        }
        return _jsonResponse({}, 404);
      });

      final service = Anime1vService.forTesting(
        client: client,
        baseUrlReader: () => 'https://api.example/v1',
      );

      final catalog = await service.fetchInitialCatalog(
        pages: 2,
        forceRefresh: true,
      );
      expect(catalog.map((s) => s.name), ['Dandadan', 'Naruto', 'Bleach']);
      expect(catalog.every(Anime1vService.isAnime1vSeries), isTrue);
      expect(catalog.first.categories, contains('Anime'));
      expect(catalog.first.year, '2024');

      final tooShort = await service.searchAnime('a');
      expect(tooShort, isEmpty);
      expect(httpCalls, 2); // Solo 2 páginas del catálogo; 'a' no llama HTTP.

      final search = await service.searchAnime('naruto');
      expect(search.single.seriesId, 'anime1v:tioanime.com:anime/naruto-shippuden');
      expect(httpCalls, 3);
    },
  );

  test(
    'fetchSeriesDetails, hydrateEpisodeChannel y resolveEmbed priorizan servidores y devuelven HLS con Referer',
    () async {
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/info')) {
          expect(
            request.url.queryParameters['url'],
            'https://animeav1.com/media/naruto',
          );
          return _jsonResponse({
            'success': true,
            'data': {
              'title': 'Naruto',
              'description': 'Un ninja joven.',
              'image': 'https://cdn.animeav1.com/covers/naruto.jpg',
              'genres': ['Shounen', 'Acción'],
              'year': '2002',
              'score': 8.3,
              'episodes': [
                {
                  'number': 1,
                  'title': 'Entra Naruto Uzumaki',
                  'url': 'https://animeav1.com/media/naruto/1',
                },
              ],
            },
          });
        }
        if (request.url.path.endsWith('/episode')) {
          expect(
            request.url.queryParameters['url'],
            'https://animeav1.com/media/naruto/1',
          );
          return _jsonResponse({
            'success': true,
            'data': {
              'servers': {
                'sub': [
                  {'server': 'Mega', 'url': 'https://mega.nz/embed/abc'},
                  {
                    'server': 'MP4Upload',
                    'url': 'https://www.mp4upload.com/embed-123.html',
                  },
                  {
                    'server': 'HLS',
                    'url': 'https://player.zilla-networks.com/play/999',
                  },
                ],
                'dub': [
                  {
                    'server': 'HLS',
                    'url': 'https://player.zilla-networks.com/play/dub999',
                  },
                ],
              },
              'streamLinks': {
                'SUB': [
                  {
                    'server': 'YourUpload',
                    'url': 'https://www.yourupload.com/embed/777',
                  },
                ],
              },
            },
          });
        }
        if (request.url.path.endsWith('/resolve')) {
          return _jsonResponse({
            'success': true,
            'server': 'zilla',
            'mediaType': 'hls',
            'streamUrl': 'https://player.zilla-networks.com/m3u8/999',
            'headers': {'Referer': 'https://player.zilla-networks.com/'},
          });
        }
        return _jsonResponse({}, 404);
      });

      final service = Anime1vService.forTesting(
        client: client,
        baseUrlReader: () => 'https://api.example/v1',
      );

      final base = XtreamSeries(
        seriesId: 'anime1v:animeav1.com:media/naruto',
        name: 'Naruto',
        host: Anime1vService.sourceHostTag,
        username: '',
        password: '',
      );

      final detailed = await service.fetchSeriesDetails(base, forceRefresh: true);
      expect(detailed, isNotNull);
      expect(detailed!.plot, 'Un ninja joven.');
      expect(detailed.episodes, hasLength(1));

      final ep = detailed.episodes!.single;
      expect(Anime1vService.isAnime1vEpisodeUrl(ep.url), isTrue);
      expect(Anime1vService.isAnime1vChannel(ep), isTrue);
      expect(ep.forcedType, 'series');

      final hydrated = await service.hydrateEpisodeChannel(ep, forceRefresh: true);
      expect(hydrated.url, ep.url);
      expect(
        hydrated.servers.map((s) => s.name).toList(),
        [
          'HLS (SUB)',
          'HLS (DUB)',
          'MP4Upload (SUB)',
          'YourUpload (SUB)',
          'Mega (SUB)',
        ],
      );

      // PlaybackSourcePlan debe omitir el ticket virtual anime1v://ep?...
      final plan = PlaybackSourcePlan.forChannel(hydrated);
      expect(
        plan.sources.any((s) => s.startsWith('anime1v://')),
        isFalse,
      );
      expect(
        plan.sources.first,
        'https://player.zilla-networks.com/play/999',
      );

      // Ticket virtual no debe resolverse directo en /resolve.
      expect(await service.resolveEmbed(ep.url), isNull);

      final resolved = await service.resolveEmbed(hydrated.servers.first.url);
      expect(resolved, isNotNull);
      expect(resolved!.url, 'https://player.zilla-networks.com/m3u8/999');
      expect(resolved.formatHint, VideoFormat.hls);
      expect(resolved.headers['Referer'], 'https://player.zilla-networks.com/');
    },
  );

  test(
    'ContentStore mantiene los animes de anime1v aislados de Películas, Series, K-Drama y Tendencia',
    () async {
      final store = ContentStore.instance;
      final regularSeries = XtreamSeries(
        seriesId: 'serie-demo-1',
        name: 'Serie Regular',
        host: 'xtream.demo',
        username: '',
        password: '',
        categories: ['Series', 'Drama'],
      );
      final regularMovie = Channel(
        name: 'Película Regular',
        url: 'https://cdn.example/pelicula.mp4',
        forcedType: 'movie',
        category: 'Acción',
      );
      store.all = [regularMovie];
      store.series = [regularSeries];

      final client = MockClient((request) async {
        if (request.url.path.endsWith('/catalog')) {
          final page = request.url.queryParameters['page'];
          final results = page == '1'
              ? [
                  {
                    'title': 'Jujutsu Kaisen',
                    'url': 'https://animeav1.com/media/jujutsu-kaisen',
                    'image': 'https://cdn.animeav1.com/covers/jk.jpg',
                    'genres': ['Acción', 'Sobrenatural'],
                  },
                  {
                    'title': 'Anime Adulto Terror',
                    'url': 'https://animeav1.com/media/tokyo-gore',
                    'image': 'https://cdn.animeav1.com/covers/tg.jpg',
                    'genres': ['Adulto', 'Acción'],
                  },
                ]
              : const <Map<String, dynamic>>[];
          return _jsonResponse({'success': true, 'data': {'results': results}});
        }
        return _jsonResponse({}, 404);
      });

      final service = Anime1vService.forTesting(
        client: client,
        baseUrlReader: () => 'https://api.example/v1',
      );

      await store.loadAnimeCatalog(refresh: true, service: service);
      store.warmHomeGenreRows();

      expect(
        store.visibleAnimeApiSeries.map((s) => s.name),
        ['Jujutsu Kaisen', 'Anime Adulto Terror'],
      );
      expect(
        store.anime.map((c) => c.name),
        ['Jujutsu Kaisen', 'Anime Adulto Terror'],
      );

      // Aislamiento estricto: Películas, Series, K-Drama y Tendencia intactas.
      expect(store.visibleSeries.map((s) => s.name), ['Serie Regular']);
      expect(store.all.map((c) => c.name), ['Película Regular']);
      expect(store.kDramas, isEmpty);
      expect(store.trending, isEmpty);

      // Episodios de anime1v se conservan en Continuar viendo si la serie está en store.
      final detailedJjk = XtreamSeries(
        seriesId: store.animeApiSeries.first.seriesId,
        name: 'Jujutsu Kaisen',
        host: Anime1vService.sourceHostTag,
        username: '',
        password: '',
        categories: ['Anime', 'Acción'],
        episodes: [
          Channel(
            name: 'Episodio 1',
            url: Anime1vService.encodeEpisodeTicketUrl(
              'https://animeav1.com/media/jujutsu-kaisen/1',
            ),
            forcedType: 'series',
            category: Anime1vService.sourceHostTag,
            catalogTitleId: store.animeApiSeries.first.seriesId,
            tvgId: 'anime1v:${store.animeApiSeries.first.seriesId}:1',
          ),
        ],
      );
      store.rememberAnimeApiSeries(detailedJjk);
      final ep = detailedJjk.episodes!.single;
      await StorageService.saveRecent(ep);
      await store.updatePlaybackProgress(ep, 0.45);
      expect(store.continueWatching.map((c) => c.url), [ep.url]);

      // Control parental filtra títulos no aptos en anime sin romper el resto.
      await ParentalControlService.enable('1234');
      expect(
        store.visibleAnimeApiSeries.map((s) => s.name),
        ['Jujutsu Kaisen'],
      );
    },
  );
}
