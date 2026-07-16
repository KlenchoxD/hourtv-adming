import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamtv/models/channel.dart';
import 'package:streamtv/services/storage_service.dart';
import 'package:streamtv/services/xtream_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'persiste canales parseados y series para el arranque inmediato',
    () async {
      SharedPreferences.setMockInitialValues({});
      await StorageService.init();

      final channels = [
        Channel(
          name: 'Canal cacheado',
          url: 'https://live.test/channel.m3u8',
          category: 'live',
        ),
        Channel(
          name: 'Película cacheada',
          url: 'https://vod.test/movie.mp4',
          forcedType: 'movie',
          writer: 'Guionista',
          releaseDate: '2025-06-20',
          servers: const [
            ChannelServer(
              name: 'Principal',
              url: 'https://vod.test/movie.mp4',
              language: 'Español',
            ),
          ],
        ),
      ];
      final series = [
        XtreamSeries(
          seriesId: 'catalog:series',
          name: 'Serie cacheada',
          host: '',
          username: '',
          password: '',
          writer: 'Guionista de serie',
          releaseDate: '2024-01-01',
          episodes: [channels.last],
        ),
      ];

      await StorageService.saveChannels(channels);
      await StorageService.saveSeries(series);

      final restoredChannels = await StorageService.loadChannels();
      final restoredSeries = await StorageService.loadSeries();

      expect(restoredChannels, hasLength(2));
      expect(restoredChannels.last.servers.single.language, 'Español');
      expect(restoredChannels.last.releaseDate, '2025-06-20');
      expect(restoredSeries.single.writer, 'Guionista de serie');
      expect(restoredSeries.single.episodes, hasLength(1));
    },
  );
}
