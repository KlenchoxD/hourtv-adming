import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamtv/models/channel.dart';
import 'package:streamtv/services/content_store.dart';
import 'package:streamtv/services/storage_service.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await StorageService.init();
  });

  test(
    'continueWatching solo incluye VOD empezado y no terminado',
    () async {
      final store = ContentStore.instance;
      final previous = store.all;
      addTearDown(() => store.all = previous);

      final movie = Channel(
        name: 'Empezada',
        url: 'vod:empezada',
        forcedType: 'movie',
        duration: '120',
      );
      final finished = Channel(
        name: 'Terminada',
        url: 'vod:terminada',
        forcedType: 'movie',
      );
      final untouched = Channel(
        name: 'Sin ver',
        url: 'vod:sinver',
        forcedType: 'movie',
      );
      final live = Channel(name: 'Canal en vivo', url: 'live:1');
      store.all = [movie, finished, untouched, live];

      await StorageService.saveRecent(movie);
      await StorageService.saveRecent(finished);
      await StorageService.saveRecent(live);

      await store.updatePlaybackProgress(movie, 0.4);
      await store.updatePlaybackProgress(finished, 0.99);
      await store.updatePlaybackProgress(live, 0.5);

      expect(
        store.continueWatching.map((item) => item.url),
        ['vod:empezada'],
      );
      expect(store.history.map((item) => item.url), [
        'live:1',
        'vod:terminada',
        'vod:empezada',
      ]);
    },
  );

  test(
    'updatePlaybackProgress con notify:false no avisa a los listeners',
    () async {
      final store = ContentStore.instance;
      final previous = store.all;
      addTearDown(() => store.all = previous);

      final movie = Channel(
        name: 'En progreso',
        url: 'vod:progreso',
        forcedType: 'movie',
      );
      store.all = [movie];
      await StorageService.saveRecent(movie);

      var notifications = 0;
      void listener() => notifications++;
      store.addListener(listener);
      addTearDown(() => store.removeListener(listener));

      // Ticks periodicos durante la reproduccion: no deben reconstruir toda
      // la app de fondo mientras el usuario esta viendo un video.
      await store.updatePlaybackProgress(movie, 0.2, notify: false);
      await store.updatePlaybackProgress(movie, 0.4, notify: false);
      expect(notifications, 0);
      expect(movie.progressFraction, 0.4);

      // Guardado final al salir del reproductor: este si debe notificar.
      await store.updatePlaybackProgress(movie, 0.5);
      expect(notifications, 1);
    },
  );
}
