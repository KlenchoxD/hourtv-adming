import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:streamtv/database/catalog_database.dart';
import 'package:streamtv/services/catalog/catalog_page_source.dart';

void main() {
  group('Search Race Conditions and Dispose Safety', () {
    late CatalogDatabase db;

    setUp(() async {
      db = CatalogDatabase(NativeDatabase.memory());
      // Insert mock titles into FTS
      await db.catalogDao.upsertTitle(
        LocalTitlesCompanion.insert(
          id: 'movie_batman',
          mediaType: 'movie',
          title: 'The Batman',
          normalizedTitle: 'the batman',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      await db.catalogDao.upsertTitle(
        LocalTitlesCompanion.insert(
          id: 'movie_superman',
          mediaType: 'movie',
          title: 'Superman',
          normalizedTitle: 'superman',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('Rapid consecutive search calls only apply the latest query', () async {
      final source = CatalogPageSource(dao: db.catalogDao);

      // Trigger two searches concurrently
      final search1 = source.search('Batman');
      final search2 = source.search('Superman');

      await Future.wait([search1, search2]);

      // Superman was the last query executed, items must reflect Superman only
      expect(source.items.length, equals(1));
      expect(source.items.first.id, equals('movie_superman'));

      source.dispose();
    });

    test('Dispose during active query does not throw or notify', () async {
      final source = CatalogPageSource(dao: db.catalogDao);
      var notificationsAfterDispose = 0;

      // Attach listener BEFORE dispose
      source.addListener(() {
        if (source.isDisposed) {
          notificationsAfterDispose++;
        }
      });

      // Start an async search
      final searchFuture = source.search('Batman');

      // Dispose immediately
      source.dispose();

      await searchFuture;

      expect(notificationsAfterDispose, equals(0));
    });
  });
}
