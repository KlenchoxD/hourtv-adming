import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:streamtv/services/subtitles/hourtv_subtitle_track.dart';
import 'package:streamtv/services/subtitles/opensubtitles_repository.dart';

void main() {
  const testApiKey = 'mock-test-key-12345';

  const validSrtContent = '''1
00:00:01,000 --> 00:00:04,000
Hola mundo en español

2
00:00:05,000 --> 00:00:08,000
Segunda línea de diálogo
''';

  const validVttContent = '''WEBVTT

00:00:01.000 --> 00:00:03.000
Hello world in English
''';

  Map<String, dynamic> sampleSearchResponse({
    int fileId = 101,
    String lang = 'es',
    String fileName = 'movie.srt',
  }) => {
        'total_count': 1,
        'data': [
          {
            'id': 'sub-1',
            'type': 'subtitle',
            'attributes': {
              'subtitle_id': 'sub-attr-1',
              'language': lang,
              'download_count': 500,
              'files': [
                {
                  'file_id': fileId,
                  'cd_number': 1,
                  'file_name': fileName,
                }
              ]
            }
          }
        ]
      };

  group('OpenSubtitlesRepository', () {
    test('No configurado: retorna lista vacía sin invocar HTTP', () async {
      var httpCalls = 0;
      final mockClient = MockClient((request) async {
        httpCalls++;
        return http.Response('{}', 200);
      });

      final repo = OpenSubtitlesRepository(apiKey: '', client: mockClient);
      final tracks = await repo.searchSubtitles(title: 'Inception');

      expect(tracks, isEmpty);
      expect(httpCalls, 0);
    });

    test('Película: búsqueda por título y año descarga SRT oficial y valida', () async {
      final mockClient = MockClient((request) async {
        // 1. Endpoint de búsqueda
        if (request.url.path.endsWith('/subtitles')) {
          expect(request.method, 'GET');
          expect(request.headers['Api-Key'], testApiKey);
          expect(request.url.queryParameters['query'], 'The Matrix');
          expect(request.url.queryParameters['year'], '1999');
          expect(request.url.queryParameters['type'], 'movie');
          return http.Response(
            jsonEncode(sampleSearchResponse(fileId: 201, lang: 'es')),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        // 2. Endpoint de descarga oficial
        if (request.url.path.endsWith('/download')) {
          expect(request.method, 'POST');
          expect(request.headers['Api-Key'], testApiKey);
          final body = jsonDecode(request.body) as Map;
          expect(body['file_id'], 201);
          return http.Response(
            jsonEncode({'link': 'https://dl.opensubtitles.org/sub/201.srt'}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        // 3. Descarga del archivo
        if (request.url.toString() == 'https://dl.opensubtitles.org/sub/201.srt') {
          return http.Response(validSrtContent, 200);
        }

        return http.Response('Not Found', 404);
      });

      final repo = OpenSubtitlesRepository(apiKey: testApiKey, client: mockClient);
      final tracks = await repo.searchSubtitles(
        title: 'The Matrix',
        year: '1999',
      );

      expect(tracks.length, 1);
      final track = tracks.first;
      expect(track.id, 'os-es-201');
      expect(track.languageCode, 'es');
      expect(track.format, SubtitleFormat.srt);
      expect(track.url, 'https://dl.opensubtitles.org/sub/201.srt');
      expect(repo.getDownloadedContent(track.id), contains('Hola mundo en español'));
    });

    test('Serie: búsqueda con temporada y episodio descarga y valida VTT', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path.endsWith('/subtitles')) {
          expect(request.url.queryParameters['season_number'], '2');
          expect(request.url.queryParameters['episode_number'], '5');
          expect(request.url.queryParameters['type'], 'episode');
          return http.Response(
            jsonEncode(sampleSearchResponse(fileId: 305, lang: 'en', fileName: 'show.vtt')),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        if (request.url.path.endsWith('/download')) {
          return http.Response(
            jsonEncode({'link': 'https://dl.opensubtitles.org/sub/305.vtt'}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        if (request.url.toString() == 'https://dl.opensubtitles.org/sub/305.vtt') {
          return http.Response(validVttContent, 200);
        }

        return http.Response('Not Found', 404);
      });

      final repo = OpenSubtitlesRepository(apiKey: testApiKey, client: mockClient);
      final tracks = await repo.searchSubtitles(
        title: 'Breaking Bad',
        season: 2,
        episode: 5,
        languages: ['en'],
      );

      expect(tracks.length, 1);
      final track = tracks.first;
      expect(track.id, 'os-en-305');
      expect(track.format, SubtitleFormat.vtt);
      expect(track.label, contains('S02E05'));
    });

    test('Búsqueda por tmdb_id e imdb_id sanitizado', () async {
      String? capturedTmdb;
      String? capturedImdb;

      final mockClient = MockClient((request) async {
        if (request.url.path.endsWith('/subtitles')) {
          capturedTmdb = request.url.queryParameters['tmdb_id'];
          capturedImdb = request.url.queryParameters['imdb_id'];
          return http.Response(
            jsonEncode({'total_count': 0, 'data': []}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final repo = OpenSubtitlesRepository(apiKey: testApiKey, client: mockClient);
      await repo.searchSubtitles(
        title: 'Fight Club',
        tmdbId: '550',
        imdbId: 'tt0137523',
      );

      expect(capturedTmdb, '550');
      expect(capturedImdb, '0137523'); // Sanitizado sin prefijo 'tt'
    });

    test('Idiomas: procesa subtítulos tanto en español como en inglés', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path.endsWith('/subtitles')) {
          expect(request.url.queryParameters['languages'], 'es,en');
          return http.Response(
            jsonEncode({
              'total_count': 2,
              'data': [
                {
                  'attributes': {
                    'language': 'es',
                    'files': [{'file_id': 401}]
                  }
                },
                {
                  'attributes': {
                    'language': 'en',
                    'files': [{'file_id': 402}]
                  }
                }
              ]
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        if (request.url.path.endsWith('/download')) {
          final body = jsonDecode(request.body) as Map;
          final fid = body['file_id'];
          return http.Response(
            jsonEncode({'link': 'https://dl.opensubtitles.org/sub/$fid.srt'}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        if (request.url.path.endsWith('401.srt')) {
          return http.Response(validSrtContent, 200);
        }
        if (request.url.path.endsWith('402.srt')) {
          return http.Response(validVttContent, 200);
        }

        return http.Response('Not Found', 404);
      });

      final repo = OpenSubtitlesRepository(apiKey: testApiKey, client: mockClient);
      final tracks = await repo.searchSubtitles(
        title: 'Interstellar',
        languages: ['es', 'en'],
      );

      expect(tracks.length, 2);
      expect(tracks.any((t) => t.languageCode == 'es'), isTrue);
      expect(tracks.any((t) => t.languageCode == 'en'), isTrue);
    });

    test('Caché local: segunda llamada no invoca peticiones HTTP', () async {
      var searchCalls = 0;
      final mockClient = MockClient((request) async {
        if (request.url.path.endsWith('/subtitles')) {
          searchCalls++;
          return http.Response(
            jsonEncode(sampleSearchResponse(fileId: 501, lang: 'es')),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path.endsWith('/download')) {
          return http.Response(
            jsonEncode({'link': 'https://dl.opensubtitles.org/sub/501.srt'}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response(validSrtContent, 200);
      });

      final repo = OpenSubtitlesRepository(apiKey: testApiKey, client: mockClient);

      // Primera llamada
      final first = await repo.searchSubtitles(title: 'Gladiator', year: '2000');
      expect(first.length, 1);
      expect(searchCalls, 1);

      // Segunda llamada con mismos parámetros
      final second = await repo.searchSubtitles(title: 'Gladiator', year: '2000');
      expect(second.length, 1);
      expect(second.first.id, first.first.id);
      expect(searchCalls, 1); // Cero llamadas HTTP adicionales
    });

    test('Error 401 (Unauthorized): manejo controlado y lista vacía', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'message': 'Invalid API Key'}),
          401,
          headers: {'content-type': 'application/json'},
        );
      });

      final repo = OpenSubtitlesRepository(apiKey: 'invalid-key', client: mockClient);
      final tracks = await repo.searchSubtitles(title: 'Avatar');

      expect(tracks, isEmpty);
    });

    test('Rate limit 429: manejo controlado y lista vacía', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'message': 'Too many requests'}),
          429,
          headers: {'content-type': 'application/json'},
        );
      });

      final repo = OpenSubtitlesRepository(apiKey: testApiKey, client: mockClient);
      final tracks = await repo.searchSubtitles(title: 'Oppenheimer');

      expect(tracks, isEmpty);
    });

    test('Timeout: captura TimeoutException y devuelve lista vacía', () async {
      // Se inyecta un mock client pero con timeout forzado
      final completerClient = MockClient((request) async {
        final completer = Completer<http.Response>();
        // Nunca completa dentro del plazo
        return completer.future.timeout(const Duration(milliseconds: 10));
      });

      final repo = OpenSubtitlesRepository(apiKey: testApiKey, client: completerClient);
      final tracks = await repo.searchSubtitles(title: 'Slow Connection');

      expect(tracks, isEmpty);
    });

    test('Rechazo de HTML, JSON de error y archivos mayores de 1 MB', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path.endsWith('/subtitles')) {
          return http.Response(
            jsonEncode({
              'total_count': 3,
              'data': [
                {'attributes': {'language': 'es', 'files': [{'file_id': 601}]}},
                {'attributes': {'language': 'en', 'files': [{'file_id': 602}]}},
                {'attributes': {'language': 'es', 'files': [{'file_id': 603}]}},
              ]
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        if (request.url.path.endsWith('/download')) {
          final fid = jsonDecode(request.body)['file_id'];
          return http.Response(
            jsonEncode({'link': 'https://dl.opensubtitles.org/sub/$fid.file'}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        // 601: Devuelve HTML (ej. Cloudflare / 404)
        if (request.url.path.endsWith('601.file')) {
          return http.Response('<!DOCTYPE html><html><body>Error 404 Not Found</body></html>', 200);
        }

        // 602: Devuelve JSON de error
        if (request.url.path.endsWith('602.file')) {
          return http.Response('{"error": "Download limit reached", "status": 403}', 200);
        }

        // 603: Devuelve archivo mayor a 1 MB
        if (request.url.path.endsWith('603.file')) {
          final hugeBytes = List<int>.filled(1024 * 1024 + 50, 65); // > 1 MB
          return http.Response.bytes(hugeBytes, 200);
        }

        return http.Response('Not Found', 404);
      });

      final repo = OpenSubtitlesRepository(apiKey: testApiKey, client: mockClient);
      final tracks = await repo.searchSubtitles(title: 'Corrupted Stream');

      // Todas las pistas deben ser rechazadas
      expect(tracks, isEmpty);
    });
  });
}
