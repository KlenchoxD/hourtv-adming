import 'package:flutter_test/flutter_test.dart';
import 'package:video_player/video_player.dart';
import 'package:streamtv/services/subtitles/subtitle_controller.dart';
import 'package:streamtv/models/channel.dart';
import 'package:streamtv/services/xtream_service.dart';
import 'package:streamtv/services/subtitles/subtitle_identity.dart';

void main() {
  test(
    'retrasar subtítulos no adelanta los cues ni cambia posición del vídeo',
    () async {
      final controller = VideoPlayerController.networkUrl(
        Uri.parse('https://example.test/video.mp4'),
      );
      await controller.setClosedCaptionFile(
        Future.value(
          SubRipCaptionFile(
            '1\n00:00:01,000 --> 00:00:02,000\nFrase de prueba\n\n',
          ),
        ),
      );
      controller.value = controller.value.copyWith(
        position: const Duration(milliseconds: 1500),
      );
      SubtitleController.applyCaptionDelay(controller, Duration.zero);
      expect(controller.value.caption.text, 'Frase de prueba');
      SubtitleController.applyCaptionDelay(
        controller,
        const Duration(milliseconds: 1000),
      );
      expect(controller.value.caption.text, isEmpty);
      expect(controller.value.position, const Duration(milliseconds: 1500));
      controller.value = controller.value.copyWith(
        position: const Duration(milliseconds: 2500),
      );
      SubtitleController.applyCaptionDelay(
        controller,
        const Duration(milliseconds: 1000),
      );
      expect(controller.value.caption.text, 'Frase de prueba');
      await controller.dispose();
    },
  );
  test('episodio genérico usa título, temporada, episodio y TMDB reales', () {
    final episode = Channel(
      name: 'Episodio 12',
      url: 'https://example.test/12',
      tvgId: 'catalog:breaking-bad:3:12',
      group: 'T3',
      forcedType: 'series',
      tmdbId: 1396,
    );
    final series = XtreamSeries(
      seriesId: 'catalog:breaking-bad',
      name: 'Breaking Bad',
      host: '',
      username: '',
      password: '',
      episodes: [episode],
    );
    final result = subtitleIdentity(episode, [series]);
    expect(result.title, 'Breaking Bad');
    expect(result.season, 3);
    expect(result.episode, 12);
    expect(result.tmdbId, '1396');
  });
  test('Drift conserva S3:E12 y recupera padre por URL', () {
    final episode = Channel(
      name: 'Un título sin número',
      url: 'https://example.test/12',
      tvgId: 'S3:E12',
      forcedType: 'series',
    );
    final series = XtreamSeries(
      seriesId: 'catalog:bb',
      name: 'Breaking Bad',
      host: '',
      username: '',
      password: '',
      episodes: [episode.copyWith(tmdbId: 1396)],
    );
    final result = subtitleIdentity(episode, [series]);
    expect(
      (result.title, result.season, result.episode, result.tmdbId),
      ('Breaking Bad', 3, 12, '1396'),
    );
  });
  test('película usa tmdbId explícito y no confunde el ID de catálogo', () {
    final result = subtitleIdentity(
      Channel(
        name: 'Película',
        url: 'https://example.test/movie.mp4',
        tvgId: 'catalog:movie:12',
        tmdbId: 998,
        forcedType: 'movie',
      ),
      const [],
    );
    expect(result.tmdbId, '998');
    expect(result.season, isNull);
    expect(result.episode, isNull);
  });
}
