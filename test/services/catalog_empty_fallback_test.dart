import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:streamtv/database/catalog_database.dart';
import 'package:streamtv/models/channel.dart';
import 'package:streamtv/services/catalog/catalog_repository.dart';
import 'package:streamtv/services/catalog_parser.dart';
import 'package:streamtv/services/catalog_presentation_index.dart';

void main() {
  group('Catalog Empty Fallback Policy', () {
    late CatalogDatabase db;

    setUp(() {
      db = CatalogDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('Drift empty keeps JSON fallback covering full catalog', () async {
      // Create empty CatalogRepository
      final repo = CatalogRepository(
        dao: db.catalogDao,
      );

      // Verify Drift starts completely empty
      final driftPage = await repo.getTitlesPage(limit: 20);
      expect(driftPage, isEmpty);

      // In-memory JSON catalog with 50 items
      final jsonCatalog = List.generate(
        50,
        (i) => Channel(
          name: 'Movie $i',
          url: 'https://example.com/movie_$i.mp4',
          logo: 'https://example.com/poster_$i.jpg',
          forcedType: 'movie',
          category: 'peliculas',
        ),
      );

      final index = CatalogPresentationIndex.build(jsonCatalog);
      final searchResults = index.search(const CatalogQuery(text: 'Movie'));

      // The fallback must cover the ENTIRE JSON catalog, not just preview
      expect(searchResults.length, equals(50));
      expect(repo.isReady, isFalse);
    });

    test('Drift transition occurs only when populated and ready', () async {
      final repo = CatalogRepository(
        dao: db.catalogDao,
        fallbackPayloadLoader: () async => CatalogPayload(
          channels: [
            Channel(name: 'Seeded Movie 1', url: 'https://a.com/1.mp4', forcedType: 'movie'),
            Channel(name: 'Seeded Movie 2', url: 'https://a.com/2.mp4', forcedType: 'movie'),
          ],
        ),
      );

      expect(repo.status, equals(CatalogRepositoryStatus.idle));
      expect(repo.isReady, isFalse);

      // Initialize with fallback payload loader
      final status = await repo.initialize();
      expect(status, equals(CatalogRepositoryStatus.offlineReady));
      expect(repo.isReady, isTrue);

      final driftTitles = await repo.getTitlesPage(limit: 10);
      expect(driftTitles.length, equals(2));
      expect(driftTitles.map((t) => t.title), containsAll(['Seeded Movie 1', 'Seeded Movie 2']));
    });
  });
}
