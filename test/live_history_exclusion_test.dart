import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamtv/models/channel.dart';
import 'package:streamtv/services/content_store.dart';
import 'package:streamtv/services/storage_service.dart';

void main() {
  final live = Channel(name: 'Caracol TV', url: 'https://example.test/live/1');
  final movie = Channel(name: 'Película', url: 'vod:movie', forcedType: 'movie')
    ..progressFraction = .4;
  final episode = Channel(
    name: 'Episodio',
    url: 'vod:episode',
    forcedType: 'series',
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
  });

  test('live playback never enters history or watch counts', () async {
    await StorageService.saveRecent(movie);
    await StorageService.saveRecent(live);
    expect(StorageService.loadRecent().map((c) => c.url), [movie.url]);
    expect(StorageService.loadWatchCounts().containsKey(live.url), isFalse);
    expect(live.lastWatched, isNull);
  });

  test(
    'cleans old history for every profile without changing live data',
    () async {
      movie.lastWatched = DateTime.utc(2026, 10, 1);
      final entries = jsonEncode(
        [live, movie, episode].map((c) => c.toJson()).toList(),
      );
      final favorites = jsonEncode([live.toJson()]);
      SharedPreferences.setMockInitialValues({
        'recent_channels': entries,
        'recent_channels.profile.kids': entries,
        'favorites': favorites,
        'settings': jsonEncode({'lastGoodLiveUrlV2': live.url}),
      });
      await StorageService.init();
      expect(StorageService.loadRecent().map((c) => c.url), [
        movie.url,
        episode.url,
      ]);
      expect(StorageService.loadRecentFor('kids').map((c) => c.url), [
        movie.url,
        episode.url,
      ]);
      expect(StorageService.loadRecent().first.progressFraction, .4);
      expect(StorageService.loadRecent().first.lastWatched, movie.lastWatched);
      expect(StorageService.loadFavorites().single.url, live.url);
      expect(StorageService.getSetting('lastGoodLiveUrlV2'), live.url);
      final prefs = await SharedPreferences.getInstance();
      for (final key in ['recent_channels', 'recent_channels.profile.kids']) {
        expect((jsonDecode(prefs.getString(key)!) as List).length, 2);
      }
      await StorageService.init();
      expect(StorageService.loadRecent().length, 2);
    },
  );

  test(
    'sync imports cannot restore channels into any profile history',
    () async {
      for (final id in [StorageService.activeProfileId, 'other-profile']) {
        await StorageService.saveRecentFor(id, [live, movie, episode]);
        expect(StorageService.loadRecentFor(id).map((c) => c.url), [
          movie.url,
          episode.url,
        ]);
      }
    },
  );

  test(
    'history also excludes a saved title resolved as live in catalog',
    () async {
      final store = ContentStore.instance;
      final previous = store.all;
      addTearDown(() => store.all = previous);
      await StorageService.saveRecent(movie);
      store.all = [Channel(name: 'Canal', url: movie.url)];
      expect(store.history, isEmpty);
    },
  );
}
