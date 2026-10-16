import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamtv/models/channel.dart';
import 'package:streamtv/services/xtream_service.dart';
import 'package:streamtv/services/content_store.dart';
import 'package:streamtv/services/storage_service.dart';
import 'package:streamtv/services/catalog_parser.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    ContentStore.instance.resetForTesting();
  });

  test(
    'native startup waits for fresh snapshot before exposing cached movies',
    () async {
      final store = ContentStore.instance;
      final snapshot = Completer<CatalogPayload>();
      final load = store.load(
        cacheLoader: () async => [
          Channel(
            name: 'Old film',
            url: 'https://test/old.mp4',
            forcedType: 'movie',
          ),
        ],
        seriesCacheLoader: () async => [],
        startupSnapshotLoader: () => snapshot.future,
      );
      await pumpEventQueue();
      expect(store.readiness.canEnterApp, isFalse);
      snapshot.complete(
        CatalogPayload(
          lists: [],
          epgUrls: [],
          channels: [
            Channel(
              name: 'New film',
              url: 'https://test/new.mp4',
              forcedType: 'movie',
            ),
          ],
          series: [],
        ),
      );
      await load;
      expect(store.all.map((item) => item.name), ['New film']);
      expect(store.readiness.canEnterApp, isTrue);
    },
  );

  test(
    'an authoritative empty admin snapshot removes stale cached VOD but keeps live channels',
    () async {
      final store = ContentStore.instance;
      final oldSeries = XtreamSeries(
        seriesId: 'catalog:old-series',
        name: 'Old prototype series',
        host: '',
        username: '',
        password: '',
      );

      await store.load(
        cacheLoader: () async => [
          Channel(
            name: 'Old prototype movie',
            url: 'https://test/old-movie.mp4',
            forcedType: 'movie',
          ),
          Channel(name: 'User live channel', url: 'https://test/live.m3u8'),
        ],
        seriesCacheLoader: () async => [oldSeries],
        startupSnapshotLoader: () async =>
            CatalogPayload(lists: [], epgUrls: [], channels: [], series: []),
      );

      expect(store.all.map((item) => item.name), ['User live channel']);
      expect(store.series, isEmpty);
      expect(store.readiness.phase, CatalogLoadPhase.ready);
    },
  );

  test('startup network failure preserves complete cached catalog', () async {
    final old = Channel(
      name: 'Offline film',
      url: 'https://test/offline.mp4',
      forcedType: 'movie',
    );
    await ContentStore.instance.load(
      cacheLoader: () async => [old],
      seriesCacheLoader: () async => [],
      startupSnapshotLoader: () =>
          Future<CatalogPayload>.error(TimeoutException('offline')),
    );
    expect(ContentStore.instance.all.map((item) => item.name), [
      'Offline film',
    ]);
    expect(ContentStore.instance.readiness.canEnterApp, isTrue);
  });

  test(
    'bundled prototype VOD is never used as an admin catalog fallback',
    () async {
      final store = ContentStore.instance;
      await StorageService.saveSetting(
        'remoteSourcesUrl',
        'http://127.0.0.1:1/catalog.json',
      );
      await StorageService.saveRemoteSourcesCache('');
      await store.load(
        cacheLoader: () async => [],
        seriesCacheLoader: () async => [],
      );

      expect(store.movies, isEmpty);
      expect(store.series, isEmpty);
    },
  );

  test(
    'cached data does not finish initial readiness while remote sync is pending',
    () async {
      final store = ContentStore.instance;
      final cacheCompleter = Completer<List<Channel>>();
      final remoteCompleter = Completer<List<Channel>>();

      final cachedCatalog = [
        Channel(name: 'Canal Cache', url: 'https://example.com/cache.m3u8'),
      ];
      final remoteCatalog = [
        Channel(name: 'Canal Remoto', url: 'https://example.com/remote.m3u8'),
      ];

      final loadFuture = store.load(
        cacheLoader: () => cacheCompleter.future,
        seriesCacheLoader: () async => <XtreamSeries>[],
        remoteLoader: () => remoteCompleter.future,
      );

      // Initial state: restoring / opening cache
      expect(
        store.readiness.phase,
        isIn([
          CatalogLoadPhase.restoringSession,
          CatalogLoadPhase.openingCache,
        ]),
      );
      expect(store.isInitialReady, isFalse);

      // Cache resolves: must be in syncingCatalog, but initialReady must NOT complete yet
      cacheCompleter.complete(cachedCatalog);
      await pumpEventQueue();

      expect(store.readiness.phase, CatalogLoadPhase.syncingCatalog);
      expect(store.all.map((c) => c.name), contains('Canal Cache'));
      expect(store.isInitialReady, isFalse);

      // Remote resolves: readiness transitions to ready and initialReady completes
      remoteCompleter.complete(remoteCatalog);
      await expectLater(store.initialReady, completes);
      expect(store.isInitialReady, isTrue);
      expect(store.readiness.phase, CatalogLoadPhase.ready);
      expect(store.readiness.canEnterApp, isTrue);
      expect(store.all.map((c) => c.name), contains('Canal Remoto'));

      await loadFuture;
    },
  );

  test(
    'first install with no cache waits for remote and completes ready',
    () async {
      final store = ContentStore.instance;
      final remoteCompleter = Completer<List<Channel>>();

      final loadFuture = store.load(
        cacheLoader: () async => <Channel>[],
        seriesCacheLoader: () async => <XtreamSeries>[],
        remoteLoader: () => remoteCompleter.future,
      );

      await pumpEventQueue();
      expect(store.readiness.phase, CatalogLoadPhase.syncingCatalog);
      expect(store.isInitialReady, isFalse);

      remoteCompleter.complete([
        Channel(name: 'Canal Nuevo', url: 'https://example.com/nuevo.m3u8'),
      ]);

      await expectLater(store.initialReady, completes);
      expect(store.readiness.phase, CatalogLoadPhase.ready);
      expect(store.readiness.canEnterApp, isTrue);

      await loadFuture;
    },
  );

  test(
    'remote failure or timeout with valid cache falls back to offlineReady',
    () async {
      final store = ContentStore.instance;
      final cachedCatalog = [
        Channel(name: 'Canal Offline', url: 'https://example.com/offline.m3u8'),
      ];

      await store.load(
        cacheLoader: () async => cachedCatalog,
        seriesCacheLoader: () async => <XtreamSeries>[],
        remoteLoader: () =>
            Future<List<Channel>>.error(Exception('Network timeout')),
      );

      await expectLater(store.initialReady, completes);
      expect(store.readiness.phase, CatalogLoadPhase.offlineReady);
      expect(store.readiness.canEnterApp, isTrue);
      expect(store.all.isNotEmpty, isTrue);
    },
  );

  test(
    'remote failure without cache results in actionable failed state with retry',
    () async {
      final store = ContentStore.instance;

      await store.load(
        cacheLoader: () async => <Channel>[],
        seriesCacheLoader: () async => <XtreamSeries>[],
        remoteLoader: () =>
            Future<List<Channel>>.error(Exception('No internet')),
      );

      await expectLater(store.initialReady, completes);
      expect(store.readiness.phase, CatalogLoadPhase.failed);
      expect(store.readiness.canEnterApp, isFalse);
      expect(store.readiness.canRetry, isTrue);
      expect(store.readiness.message, isNotNull);

      // Now test retry with successful remote
      final retryFuture = store.retry(
        cacheLoader: () async => <Channel>[],
        seriesCacheLoader: () async => <XtreamSeries>[],
        remoteLoader: () async => [
          Channel(name: 'Canal Recuperado', url: 'https://example.com/ok.m3u8'),
        ],
      );

      await expectLater(store.initialReady, completes);
      expect(store.readiness.phase, CatalogLoadPhase.ready);
      expect(store.readiness.canEnterApp, isTrue);
      await retryFuture;
    },
  );
}
