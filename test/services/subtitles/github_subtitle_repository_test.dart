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
    const srt = '1\n00:00:01,000 --> 00:00:04,000\nHola\n';

    test('película: movie/<tmdb>.es.srt', () async {
      final requested = <String>[];
      final repo = GithubSubtitleRepository(
        baseUrl: 'https://raw.test/subs',
        client: MockClient((req) async {
          requested.add(req.url.toString());
          return http.Response(srt, 200);
        }),
      );
      final tracks = await repo.find(tmdbId: 808);
      expect(requested, ['https://raw.test/subs/movie/808.es.srt']);
      expect(tracks.single.format, SubtitleFormat.srt);
      expect(tracks.single.languageCode, 'es');
      expect(tracks.single.label, 'Español');
    });

    test('episodio: tv/<tmdb>/S01E02.es.srt', () async {
      final repo = GithubSubtitleRepository(
        baseUrl: 'https://raw.test/subs',
        client: MockClient((_) async => http.Response(srt, 200)),
      );
      final tracks = await repo.find(tmdbId: 197067, season: 1, episode: 2);
      expect(tracks.single.url, 'https://raw.test/subs/tv/197067/S01E02.es.srt');
    });

    test('sin subtítulo (404 o HTML) no hay pista y no se vuelve a pedir', () async {
      var calls = 0;
      final repo = GithubSubtitleRepository(
        client: MockClient((_) async {
          calls++;
          return http.Response('404: Not Found', 404);
        }),
      );
      expect(await repo.find(tmdbId: 1), isEmpty);
      expect(await repo.find(tmdbId: 1), isEmpty);
      expect(calls, 1);

      final html = GithubSubtitleRepository(
        client: MockClient((_) async => http.Response('<html>x</html>', 200)),
      );
      expect(await html.find(tmdbId: 2), isEmpty);
    });

    test('timeout no lanza excepción', () async {
      final repo = GithubSubtitleRepository(
        client: MockClient((_) async {
          await Future<void>.delayed(const Duration(seconds: 6));
          return http.Response(srt, 200);
        }),
      );
      expect(await repo.find(tmdbId: 3), isEmpty);
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
