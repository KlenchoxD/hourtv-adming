import 'dart:convert';
import 'dart:io';
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

  test('persiste "Me gusta" por canal, separado de favoritos', () async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();

    const url = 'https://vod.test/liked-movie.mp4';
    expect(StorageService.loadLikedUrls(), isNot(contains(url)));

    expect(await StorageService.toggleLiked(url), isTrue);
    expect(StorageService.loadLikedUrls(), contains(url));

    expect(await StorageService.toggleLiked(url), isFalse);
    expect(StorageService.loadLikedUrls(), isNot(contains(url)));
  });

  test('mueve catálogo/canales/series fuera de SharedPreferences sin perderlos', () async {
    final legacyChannels = jsonEncode([
      Channel(name: 'Viejo', url: 'https://old.test/a.m3u8').toJson(),
    ]);
    SharedPreferences.setMockInitialValues({
      'channels': legacyChannels,
      'settings': jsonEncode({'remoteSourcesCache': '{"catalog":1}', 'x': 1}),
    });
    await StorageService.init(
      blobDir: Directory.systemTemp.createTempSync('hourtv_blobs_test'),
    );

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey('channels'), isFalse);
    expect(prefs.getString('settings'), isNot(contains('remoteSourcesCache')));
    expect((await StorageService.loadChannels()).single.name, 'Viejo');
    expect(await StorageService.loadRemoteSourcesCache(), '{"catalog":1}');
    expect(StorageService.getSetting('x'), 1);
  });
}
