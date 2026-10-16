import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamtv/models/channel.dart';
import 'package:streamtv/services/content_store.dart';
import 'package:streamtv/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'las peliculas de Internet Archive (esquema archive:) ya no se muestran, '
    'ni siquiera si quedaron guardadas de una version anterior',
    () async {
      SharedPreferences.setMockInitialValues({});
      await StorageService.init();

      final fromPanel = Channel(
        name: 'Del panel',
        url: 'https://cdn.test/panel-movie.mp4',
        forcedType: 'movie',
      );
      final fromArchive = Channel(
        name: 'De Internet Archive',
        url: 'archive:some-old-id',
        forcedType: 'movie',
      );
      final curatedResidentEvil = Channel(
        name: 'Resident Evil III. Extinción',
        url: 'https://catalog.test/resident-evil-3',
        logo: 'https://image.tmdb.org/t/p/w500/resident-evil.jpg',
        year: '2007',
        tmdbId: 7737,
        forcedType: 'movie',
      );
      final legacyResidentEvil = Channel(
        name: 'Resident Evil 3: Extinción',
        url: 'https://mp4.nu/resident-evil-3',
        category: 'peliculas',
        year: '2007',
        forcedType: 'movie',
      );
      await StorageService.saveChannels([
        fromPanel,
        fromArchive,
        curatedResidentEvil,
        legacyResidentEvil,
      ]);

      final store = ContentStore.instance;
      final previous = store.all;
      addTearDown(() => store.all = previous);
      store.all = [];

      await store.load();

      expect(
        store.all.map((c) => c.url),
        isNot(contains('archive:some-old-id')),
      );
      expect(
        store.all.map((c) => c.url),
        contains('https://cdn.test/panel-movie.mp4'),
      );
      expect(
        store.all.map((c) => c.url),
        contains('https://catalog.test/resident-evil-3'),
      );
      expect(
        store.all.map((c) => c.url),
        isNot(contains('https://mp4.nu/resident-evil-3')),
      );
    },
  );
}
