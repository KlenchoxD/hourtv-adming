import 'dart:async';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamtv/database/catalog_database.dart';
import 'package:streamtv/database/daos/catalog_dao.dart';
import 'package:streamtv/mobile_ui/hourtv_mobile_shell.dart';
import 'package:streamtv/models/channel.dart';
import 'package:streamtv/services/catalog/catalog_dtos.dart';
import 'package:streamtv/services/catalog/catalog_page_source.dart';
import 'package:streamtv/services/catalog/catalog_repository.dart';
import 'package:streamtv/services/catalog/catalog_sync_engine.dart';
import 'package:streamtv/services/catalog/supabase_catalog_gateway.dart';
import 'package:streamtv/services/content_store.dart';
import 'package:streamtv/services/storage_service.dart';

class TestFailingCatalogDao extends CatalogDao {
  TestFailingCatalogDao(super.attachedDatabase);
  bool failNext = false;

  @override
  Future<List<LocalTitle>> getPage({
    int limit = 20,
    DateTime? cursorCreatedAt,
    String? cursorId,
    String? mediaType,
    String? genreSlug,
    CatalogSortOrder sort = CatalogSortOrder.recent,
    int? year,
  }) async {
    if (failNext) {
      throw Exception('Simulated database failure');
    }
    return super.getPage(
      limit: limit,
      cursorCreatedAt: cursorCreatedAt,
      cursorId: cursorId,
      mediaType: mediaType,
      genreSlug: genreSlug,
      sort: sort,
      year: year,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
    CatalogRepository.setInstanceForTesting(repository);
  });

  tearDown(() async {
    CatalogRepository.setInstanceForTesting(null);
    await db.close();
  });

  Widget buildTestShell({
    CatalogRepository? repo,
    CatalogPageSource? pageSource,
    HourTvMobileDestination initialDestination = HourTvMobileDestination.home,
  }) {
    return MaterialApp(
      home: HourTvMobileShell(
        catalogRepository: repo ?? repository,
        catalogPageSource: pageSource,
      ),
    );
  }

  group('HourTvMobileShell Catalog Widget Tests', () {
    testWidgets('1. Carga perezosa de catálogo Drift en inicio al hacer scroll', (tester) async {
      final now = DateTime.utc(2026, 9, 10, 12, 0, 0);

      // Insertar 25 títulos de películas
      for (var i = 1; i <= 25; i++) {
        await dao.upsertTitle(
          LocalTitlesCompanion.insert(
            id: 'movie-$i',
            mediaType: 'movie',
            title: 'Drift Movie $i',
            normalizedTitle: 'drift movie $i',
            createdAt: now.add(Duration(minutes: i)),
            updatedAt: now.add(Duration(minutes: i)),
          ),
        );
      }

      final pageSource = CatalogPageSource(dao: dao, mediaType: 'movie', pageSize: 10);
      await pageSource.loadInitialPage();
      expect(pageSource.items.length, equals(10));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HourTvMobileHome(
              movies: const [],
              allContent: const [],
              store: ContentStore.instance,
              onOpen: (_) {},
              onSearch: () {},
              onProfile: () {},
              catalogRepository: repository,
              moviesPageSource: pageSource,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verificar que los primeros items están presentes en la UI
      expect(find.text('Drift Movie 25'), findsOneWidget);

      // Deslizar para activar la paginación perezosa
      final scrollFinder = find.byKey(const PageStorageKey('hourtv-mobile-home'));
      expect(scrollFinder, findsOneWidget);

      await tester.drag(scrollFinder, const Offset(0, -600));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // El scroll activa automáticamente la carga de la siguiente página
      expect(pageSource.items.length, greaterThanOrEqualTo(20));
    });

    testWidgets('2. Búsqueda en Drift con filtro y FTS5', (tester) async {
      final now = DateTime.utc(2026, 9, 10, 12, 0, 0);

      await dao.upsertTitle(
        LocalTitlesCompanion.insert(
          id: 'movie-matrix',
          mediaType: 'movie',
          title: 'Matrix Revolution',
          normalizedTitle: 'matrix revolution',
          plot: const Value('Zion battle'),
          createdAt: now,
          updatedAt: now,
        ),
      );

      await dao.upsertTitle(
        LocalTitlesCompanion.insert(
          id: 'movie-batman',
          mediaType: 'movie',
          title: 'Batman Begins',
          normalizedTitle: 'batman begins',
          plot: const Value('Gotham knight'),
          createdAt: now.add(const Duration(minutes: 1)),
          updatedAt: now.add(const Duration(minutes: 1)),
        ),
      );

      final searchPageSource = CatalogPageSource(dao: dao, pageSize: 20);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HourTvMobileSearch(
              content: const [],
              onOpen: (_) {},
              catalogRepository: repository,
              catalogPageSource: searchPageSource,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Escribir en el buscador
      final searchField = find.byKey(const ValueKey('hourtv-mobile-search-field'));
      expect(searchField, findsOneWidget);

      await tester.enterText(searchField, 'matrix');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      // Verificar que FTS5 encontró 'Matrix Revolution'
      expect(find.text('Matrix Revolution'), findsOneWidget);
      expect(find.text('Batman Begins'), findsNothing);
    });

    testWidgets('3. Visualización de estado de error y acción de reintento', (tester) async {
      final failingDao = TestFailingCatalogDao(db);
      final failingSource = CatalogPageSource(dao: failingDao, pageSize: 10);

      // Forzar fallo en la carga
      failingDao.failNext = true;
      await failingSource.loadInitialPage();
      expect(failingSource.hasError, isTrue);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HourTvMobileHome(
              movies: const [],
              allContent: const [],
              store: ContentStore.instance,
              onOpen: (_) {},
              onSearch: () {},
              onProfile: () {},
              catalogRepository: repository,
              moviesPageSource: failingSource,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verificar que se muestra el banner de error con botón de reintentar
      expect(find.text('Reintentar'), findsOneWidget);

      // Quitar la condición de fallo y pulsar reintentar
      failingDao.failNext = false;
      await tester.tap(find.text('Reintentar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // El error debe haberse limpiado
      expect(failingSource.hasError, isFalse);
    });
  });
}
