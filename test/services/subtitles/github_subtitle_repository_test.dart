import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamtv/services/storage_service.dart';
import 'package:streamtv/services/subtitles/github_subtitle_repository.dart';
import 'package:streamtv/services/subtitles/hourtv_subtitle_track.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'settings': jsonEncode({
        'subtitleRepositoryEnabled': true,
        'subtitleRepositoryBaseUrl': 'https://raw.githubusercontent.com/example/subs/main',
      }),
    });
    await StorageService.init();
  });

  group('GithubSubtitleRepository', () {
    test('devuelve lista vacía si el repositorio no está configurado o está deshabilitado', () async {
      final repoDisabled = GithubSubtitleRepository(
        baseUrl: 'https://raw.githubusercontent.com/example/subs/main',
        enabled: false,
      );
      final tracksDisabled = await repoDisabled.searchSubtitles(title: 'Inception');
      expect(tracksDisabled, isEmpty);

      final repoNoUrl = GithubSubtitleRepository(
        baseUrl: '',
        enabled: true,
      );
      final tracksNoUrl = await repoNoUrl.searchSubtitles(title: 'Inception');
      expect(tracksNoUrl, isEmpty);
    });

    test('búsqueda por película con respuesta SRT válida', () async {
      const validSrt = '''1
00:01:20,000 --> 00:01:23,000
Hola mundo desde subtítulo.
''';

      final mockClient = MockClient((request) async {
        if (request.url.path.contains('inception') && request.url.path.endsWith('.srt')) {
          return http.Response(validSrt, 200, headers: {'content-type': 'text/plain'});
        }
        return http.Response('Not found', 404);
      });

      final repo = GithubSubtitleRepository(
        baseUrl: 'https://raw.githubusercontent.com/example/subs/main',
        enabled: true,
        client: mockClient,
      );

      final tracks = await repo.searchSubtitles(
        title: 'Inception',
        year: '2010',
        language: 'es',
      );

      expect(tracks, isNotEmpty);
      expect(tracks.first.format, SubtitleFormat.srt);
      expect(tracks.first.languageCode, 'es');
      expect(tracks.first.label, contains('Español (GitHub)'));
      expect(tracks.first.url, contains('inception'));
    });

    test('búsqueda por serie, temporada y episodio con respuesta VTT válida', () async {
      const validVtt = '''WEBVTT

00:00:05.000 --> 00:00:08.000
Breaking Bad temporada 1 episodio 1.
''';

      final mockClient = MockClient((request) async {
        if (request.url.path.contains('breaking-bad') && request.url.path.contains('S01E01')) {
          return http.Response(validVtt, 200, headers: {'content-type': 'text/vtt'});
        }
        return http.Response('Not found', 404);
      });

      final repo = GithubSubtitleRepository(
        baseUrl: 'https://raw.githubusercontent.com/example/subs/main',
        enabled: true,
        client: mockClient,
      );

      final tracks = await repo.searchSubtitles(
        title: 'Breaking Bad',
        season: 1,
        episode: 1,
        language: 'es',
      );

      expect(tracks, isNotEmpty);
      expect(tracks.first.format, SubtitleFormat.vtt);
      expect(tracks.first.url, contains('S01E01'));
    });

    test('rechaza respuestas HTML o páginas de error 404/bloqueo de GitHub', () async {
      const htmlError = '''<!DOCTYPE html>
<html>
<head><title>404 Not Found</title></head>
<body><h1>File not found</h1></body>
</html>
''';

      final mockClient = MockClient((request) async {
        return http.Response(htmlError, 200, headers: {'content-type': 'text/html'});
      });

      final repo = GithubSubtitleRepository(
        baseUrl: 'https://raw.githubusercontent.com/example/subs/main',
        enabled: true,
        client: mockClient,
      );

      final tracks = await repo.searchSubtitles(title: 'Unknown Title');
      expect(tracks, isEmpty);
    });

    test('maneja timeout sin lanzar excepción', () async {
      final mockClient = MockClient((request) async {
        await Future<void>.delayed(const Duration(milliseconds: 200));
        return http.Response('content', 200);
      });

      final repo = GithubSubtitleRepository(
        baseUrl: 'https://raw.githubusercontent.com/example/subs/main',
        enabled: true,
        client: mockClient,
      );

      // Usando un client que simule TimeoutException
      final timeoutClient = MockClient((request) async {
        throw TimeoutException('Request timed out');
      });

      final tracks = await repo.searchSubtitles(
        title: 'Slow Movie',
        httpClient: timeoutClient,
      );
      expect(tracks, isEmpty);
    });

    test('mantiene caché en memoria de consultas previas', () async {
      var callCount = 0;
      const validSrt = '''1
00:00:10,000 --> 00:00:15,000
Prueba de caché.
''';

      final mockClient = MockClient((request) async {
        callCount++;
        return http.Response(validSrt, 200);
      });

      final repo = GithubSubtitleRepository(
        baseUrl: 'https://raw.githubusercontent.com/example/subs/main',
        enabled: true,
        client: mockClient,
      );

      final tracks1 = await repo.searchSubtitles(title: 'Cached Movie', year: '2022');
      expect(tracks1, isNotEmpty);
      expect(callCount, greaterThan(0));

      final prevCount = callCount;
      final tracks2 = await repo.searchSubtitles(title: 'Cached Movie', year: '2022');
      expect(tracks2, isNotEmpty);
      expect(callCount, equals(prevCount)); // No volvió a llamar por la red
    });

    test('deduplicación con pistas HLS existentes', () {
      final hlsTrack = const HourTvSubtitleTrack(
        id: 'hls-es-1',
        label: 'Español',
        languageCode: 'es',
        url: 'https://example.com/subs/es.vtt',
        provenance: SubtitleProvenance.hlsEmbedded,
      );

      final githubTrackSameUrl = const HourTvSubtitleTrack(
        id: 'gh-vtt-es-1',
        label: 'Español (GitHub)',
        languageCode: 'es',
        url: 'https://example.com/subs/es.vtt',
        provenance: SubtitleProvenance.sidecar,
      );

      final githubTrackOtherUrl = const HourTvSubtitleTrack(
        id: 'gh-srt-es-2',
        label: 'Español (GitHub)',
        languageCode: 'es',
        url: 'https://raw.githubusercontent.com/example/subs/main/movies/matrix.es.srt',
        provenance: SubtitleProvenance.sidecar,
      );

      final combined = <HourTvSubtitleTrack>[hlsTrack];
      final uniqueUrls = combined.map((t) => t.url?.trim().toLowerCase()).toSet();

      for (final candidate in [githubTrackSameUrl, githubTrackOtherUrl]) {
        final clean = candidate.url?.trim().toLowerCase();
        if (clean != null && !uniqueUrls.contains(clean)) {
          uniqueUrls.add(clean);
          combined.add(candidate);
        }
      }

      expect(combined.length, equals(2));
      expect(combined.first.id, 'hls-es-1');
      expect(combined.last.id, 'gh-srt-es-2');
    });

    test('valida formatos de subtítulos correctamente', () {
      expect(GithubSubtitleRepository.validateSubtitleContent('WEBVTT\n1\n00:00.000 --> 00:01.000\nHola'), SubtitleFormat.vtt);
      expect(GithubSubtitleRepository.validateSubtitleContent('1\n00:00:01,000 --> 00:00:04,000\nHola'), SubtitleFormat.srt);
      expect(GithubSubtitleRepository.validateSubtitleContent('<!doctype html><html>404</html>'), SubtitleFormat.unsupported);
      expect(GithubSubtitleRepository.validateSubtitleContent('{"message": "Not Found"}'), SubtitleFormat.unsupported);
      expect(GithubSubtitleRepository.validateSubtitleContent('Random non subtitle text'), SubtitleFormat.unsupported);
    });
  });
}
