import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamtv/models/channel.dart';
import 'package:streamtv/services/content_store.dart';
import 'package:streamtv/services/storage_service.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    ContentStore.instance.resetForTesting();
  });

  group('ContentStore & Catalog Integration Tests', () {
    test('1. ContentStore preserves Live TV channels while VOD delegates to indexed catalog', () async {
      final store = ContentStore.instance;

      final liveChannels = [
        Channel(
          name: 'Caracol HD',
          url: 'https://example.com/caracol.m3u8',
          category: 'Colombia',
          tvgId: 'caracol.co',
        ),
        Channel(
          name: 'RCN HD',
          url: 'https://example.com/rcn.m3u8',
          category: 'Colombia',
          tvgId: 'rcn.co',
        ),
      ];

      await store.load(
        cacheLoader: () async => liveChannels,
        remoteLoader: () async => liveChannels,
      );

      expect(store.isInitialReady, isTrue);
      expect(store.all.length, equals(2));
      expect(store.all.first.name, equals('Caracol HD'));
      expect(store.countries.isNotEmpty, isTrue);
    });

    test('2. ContentStore readiness transitions smoothly to ready', () async {
      final store = ContentStore.instance;

      final readyFuture = store.load(
        cacheLoader: () async => [
          Channel(name: 'Canal TV', url: 'https://example.com/tv.m3u8'),
        ],
        remoteLoader: () async => [
          Channel(name: 'Canal TV', url: 'https://example.com/tv.m3u8'),
        ],
      );

      await readyFuture;
      expect(store.readiness.phase, equals(CatalogLoadPhase.ready));
      expect(store.readiness.canEnterApp, isTrue);
    });
  });
}
