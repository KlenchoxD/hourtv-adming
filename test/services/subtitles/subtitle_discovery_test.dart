import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:streamtv/models/channel.dart';
import 'package:streamtv/services/subtitles/hourtv_subtitle_track.dart';
import 'package:streamtv/services/subtitles/subtitle_discovery_service.dart';

void main() {
  group('SubtitleDiscoveryService', () {
    test('conserva pistas explícitas al serializar un Channel', () {
      const track = HourTvSubtitleTrack(
        id: 'movie-es',
        label: 'Español',
        languageCode: 'es',
        url: 'https://cdn.example/subtitles/movie-es.vtt',
        format: SubtitleFormat.vtt,
        isDefault: true,
      );
      final original = Channel(
        name: 'Película',
        url: 'https://cdn.example/movie.m3u8',
        forcedType: 'movie',
        subtitleTracks: const [track],
      );

      final restored = Channel.fromJson(original.toJson());

      expect(restored.subtitleTracks, hasLength(1));
      expect(restored.subtitleTracks.single.id, 'movie-es');
      expect(restored.subtitleTracks.single.isDefault, isTrue);
    });

    test(
      'descubre EXT-X-MEDIA, resuelve URI y no pierde pistas explícitas',
      () async {
        const manifest = '''#EXTM3U
#EXT-X-VERSION:6
#EXT-X-MEDIA:TYPE=SUBTITLES,GROUP-ID="subs",NAME="Español",LANGUAGE="es",DEFAULT=YES,AUTOSELECT=YES,FORCED=NO,URI="subs/es/prog_index.m3u8"
#EXT-X-MEDIA:TYPE=SUBTITLES,GROUP-ID="subs",NAME="English CC",LANGUAGE="en",DEFAULT=NO,AUTOSELECT=YES,FORCED=NO,CHARACTERISTICS="public.accessibility.transcribes-spoken-dialog",URI="https://captions.example/en.vtt"
#EXT-X-STREAM-INF:BANDWIDTH=2500000,SUBTITLES="subs"
video/main.m3u8
''';
        Uri? requestedUri;
        final client = MockClient((request) async {
          requestedUri = request.url;
          return http.Response(
            manifest,
            200,
            headers: {'content-type': 'application/vnd.apple.mpegurl'},
          );
        });
        const explicit = HourTvSubtitleTrack(
          id: 'manual',
          label: 'Manual',
          languageCode: 'es',
          url: 'https://video.example/manual.srt',
          format: SubtitleFormat.srt,
        );
        final channel = Channel(
          name: 'Película',
          url: 'https://video.example/master.m3u8',
          forcedType: 'movie',
          subtitleTracks: const [explicit],
        );

        final parsed = SubtitleDiscoveryService.parseMasterManifest(
          manifest,
          baseUri: Uri.parse(channel.url),
        );
        expect(parsed, hasLength(2));

        final tracks = await SubtitleDiscoveryService().discover(
          channel: channel,
          activeUrl: Uri.parse(channel.url),
          activeHeaders: const {'User-Agent': 'HourTV'},
          httpClient: client,
        );

        expect(requestedUri.toString(), 'https://video.example/master.m3u8');
        expect(tracks.map((track) => track.id), contains('manual'));
        final spanish = tracks.firstWhere(
          (track) => track.languageCode == 'es' && track.id != 'manual',
        );
        expect(spanish.url, 'https://video.example/subs/es/prog_index.m3u8');
        expect(spanish.isHlsMediaPlaylist, isTrue);
        expect(spanish.isDefault, isTrue);
        final english = tracks.firstWhere(
          (track) => track.languageCode == 'en',
        );
        expect(english.format, SubtitleFormat.vtt);
        expect(english.hearingImpaired, isTrue);
      },
    );

    test(
      'rechaza manifiestos HTML y no duplica la misma URL explícita',
      () async {
        final client = MockClient(
          (_) async => http.Response(
            '<html>blocked</html>',
            200,
            headers: {'content-type': 'text/html'},
          ),
        );
        const track = HourTvSubtitleTrack(
          id: 'one',
          label: 'Español',
          languageCode: 'es',
          url: 'https://video.example/es.vtt',
        );
        final channel = Channel(
          name: 'Película',
          url: 'https://video.example/master.m3u8',
          subtitleTracks: const [track, track],
        );

        final tracks = await SubtitleDiscoveryService().discover(
          channel: channel,
          activeUrl: Uri.parse(channel.url),
          httpClient: client,
        );

        expect(tracks, hasLength(1));
        expect(tracks.single.id, 'one');
      },
    );
  });
}
