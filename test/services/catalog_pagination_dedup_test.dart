import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:streamtv/database/catalog_database.dart';
import 'package:streamtv/services/catalog/catalog_page_source.dart';

void main() {
  group('Catalog Pagination De-duplication and Concurrency Control', () {
    late CatalogDatabase db;

    setUp(() async {
      db = CatalogDatabase(NativeDatabase.memory());
      // Insert 25 items
      final now = DateTime.now();
      for (int i = 0; i < 25; i++) {
        await db.catalogDao.upsertTitle(
          LocalTitlesCompanion.insert(
            id: 'title_$i',
            mediaType: 'movie',
            title: 'Title $i',
            normalizedTitle: 'title $i',
            createdAt: now.subtract(Duration(minutes: i)),
            updatedAt: now.subtract(Duration(minutes: i)),
          ),
        );
      }
    });

    tearDown(() async {
      await db.close();
    });

    test('loadNextPage does not duplicate items or allow duplicate concurrent fetches', () async {
      final source = CatalogPageSource(dao: db.catalogDao, pageSize: 10);
      await source.loadInitialPage();

      expect(source.items.length, equals(10));

      // Fire two loadNextPage calls simultaneously
      final pageCall1 = source.loadNextPage();
      final pageCall2 = source.loadNextPage();

      await Future.wait([pageCall1, pageCall2]);

      // Because loadNextPage guards against concurrency, page 2 should be loaded once (total 20 items)
      expect(source.items.length, equals(20));

      // Verify no duplicate IDs exist
      final ids = source.items.map((e) => e.id).toList();
      final uniqueIds = ids.toSet();
      expect(ids.length, equals(uniqueIds.length), reason: 'All item IDs must be strictly unique');

      source.dispose();
    });
  });
}
