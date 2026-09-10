import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamtv/database/catalog_database.dart';
import 'package:streamtv/database/daos/catalog_dao.dart';
import 'package:streamtv/services/catalog/catalog_page_source.dart';
import 'package:streamtv/services/catalog/catalog_repository.dart';
import 'package:streamtv/services/catalog/catalog_sync_engine.dart';
import 'package:streamtv/services/catalog/supabase_catalog_gateway.dart';
import 'package:streamtv/services/storage_service.dart';

void main() {
  late CatalogDatabase db;
  late CatalogDao dao;
  late CatalogRepository repository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();

    db = CatalogDatabase.inMemory();
    dao = db.catalogDao;
    repository = CatalogRepository(
      dao: dao,
      gateway: SupabaseCatalogGateway(),
      syncEngine: CatalogSyncEngine(gateway: SupabaseCatalogGateway(), dao: dao),
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('HourTV Paginated Shell & UI Tests', () {
    test('1. CatalogPageSource: paginación perezosa por cursor sin duplicados', () async {
      final now = DateTime.utc(2026, 9, 10, 12, 0, 0);

      // Insertar 5 títulos con timestamps escalonados
      for (var i = 1; i <= 5; i++) {
        await dao.upsertTitle(
          LocalTitlesCompanion.insert(
            id: 'title-$i',
            mediaType: 'movie',
            title: 'Movie $i',
            normalizedTitle: 'movie $i',
            createdAt: now.add(Duration(minutes: i)),
            updatedAt: now.add(Duration(minutes: i)),
          ),
        );
      }

      final source = CatalogPageSource(dao: dao, pageSize: 2);
      expect(source.items, isEmpty);

      // Cargar página 1 (debe traer 2 items)
      await source.loadInitialPage();
      expect(source.items.length, equals(2));
      expect(source.hasMore, isTrue);
      expect(source.items.map((t) => t.id).toList(), equals(['title-5', 'title-4']));

      // Cargar página 2 (debe añadir 2 items sin duplicar los anteriores)
      await source.loadNextPage();
      expect(source.items.length, equals(4));
      expect(source.hasMore, isTrue);
      expect(source.items.map((t) => t.id).toList(), equals(['title-5', 'title-4', 'title-3', 'title-2']));

      // Cargar página 3 (último item restante)
      await source.loadNextPage();
      expect(source.items.length, equals(5));
      expect(source.hasMore, isFalse);
    });

    test('2. Búsqueda reactiva con FTS5 en CatalogPageSource', () async {
      final now = DateTime.utc(2026, 9, 10, 12, 0, 0);

      await dao.upsertTitle(
        LocalTitlesCompanion.insert(
          id: 'movie-matrix',
          mediaType: 'movie',
          title: 'The Matrix Reloaded',
          normalizedTitle: 'the matrix reloaded',
          plot: const Value('Neo and Trinity fight for Zion'),
          createdAt: now,
          updatedAt: now,
        ),
      );

      final source = CatalogPageSource(dao: dao);
      await source.search('matrix');
      expect(source.items.length, equals(1));
      expect(source.items.first.id, equals('movie-matrix'));

      // Búsqueda con caracteres de sintaxis y escape FTS5
      await source.search('matrix" * :() - ^ ~ 😀 OR NEAR AND NOT');
      expect(source.items.length, equals(1));
      expect(source.items.first.id, equals('movie-matrix'));
    });

    test('3. Hero destaca exclusivamente títulos destacados calificados', () async {
      final now = DateTime.utc(2026, 9, 10, 12, 0, 0);

      // Título no destacado
      await dao.upsertTitle(
        LocalTitlesCompanion.insert(
          id: 'movie-regular',
          mediaType: 'movie',
          title: 'Regular Movie',
          normalizedTitle: 'regular movie',
          isFeatured: const Value(false),
          createdAt: now,
          updatedAt: now,
        ),
      );

      // Título destacado calificado
      await dao.upsertTitle(
        LocalTitlesCompanion.insert(
          id: 'movie-hero',
          mediaType: 'movie',
          title: 'Hero Featured Movie',
          normalizedTitle: 'hero featured movie',
          backdropUrl: const Value('https://image.tmdb.org/backdrop.jpg'),
          isFeatured: const Value(true),
          createdAt: now,
          updatedAt: now,
        ),
      );

      final featured = await dao.getFeatured();
      expect(featured.length, equals(1));
      expect(featured.first.id, equals('movie-hero'));
      expect(featured.first.isFeatured, isTrue);
    });

    test('4. Resolución de favoritos y continuar viendo desde Drift', () async {
      await dao.upsertTitle(
        LocalTitlesCompanion.insert(
          id: 'fav-1',
          mediaType: 'movie',
          title: 'Favorite 1',
          normalizedTitle: 'favorite 1',
          createdAt: DateTime.utc(2026, 9, 10, 10, 0, 0),
          updatedAt: DateTime.utc(2026, 9, 10, 10, 0, 0),
        ),
      );

      final channels = await repository.resolveChannelsByIds(['fav-1']);
      expect(channels.length, equals(1));
      expect(channels.first.name, equals('Favorite 1'));
    });
  });
}
