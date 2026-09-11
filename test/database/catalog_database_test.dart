import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:streamtv/database/catalog_database.dart';
import 'package:streamtv/database/daos/catalog_dao.dart';
import 'package:streamtv/services/catalog/catalog_dtos.dart';

void main() {
  late CatalogDatabase db;
  late CatalogDao dao;

  setUp(() {
    db = CatalogDatabase.inMemory();
    dao = db.catalogDao;
  });

  tearDown(() async {
    await db.close();
  });

  group('CatalogDatabase & CatalogDao Tests', () {
    test('1. Soporta revisiones de 64 bits mayores a 2^31 en catalog_sync_state', () async {
      const largeRevision = 5000000000; // 5 mil millones (> 2^31 - 1 = 2,147,483,647)
      await dao.setLastCatalogRevision(largeRevision);

      final rev = await dao.getLastCatalogRevision();
      expect(rev, equals(largeRevision));
    });

    test('2. Paginación determinista desempata títulos con el mismo timestamp', () async {
      final tieDate = DateTime.utc(2026, 9, 10, 10, 0, 0);

      await dao.upsertTitle(
        LocalTitlesCompanion.insert(
          id: 'title-2',
          mediaType: 'movie',
          title: 'Movie Beta',
          normalizedTitle: 'movie beta',
          createdAt: tieDate,
          updatedAt: tieDate,
        ),
      );

      await dao.upsertTitle(
        LocalTitlesCompanion.insert(
          id: 'title-1',
          mediaType: 'movie',
          title: 'Movie Alpha',
          normalizedTitle: 'movie alpha',
          createdAt: tieDate,
          updatedAt: tieDate,
        ),
      );

      // Primera página con limit = 1
      final page1 = await dao.getPage(limit: 1);
      expect(page1.length, equals(1));
      expect(page1.first.id, equals('title-2'));

      // Segunda página usando cursor de la primera
      final page2 = await dao.getPage(
        limit: 1,
        cursorCreatedAt: page1.first.createdAt,
        cursorId: page1.first.id,
      );
      expect(page2.length, equals(1));
      expect(page2.first.id, equals('title-1'));
    });

    test('3. Sanitización FTS5: caracteres especiales, operadores booleanos, emojis y cadenas vacías', () async {
      final now = DateTime.utc(2026, 9, 10, 12, 0, 0);

      await dao.upsertTitle(
        LocalTitlesCompanion.insert(
          id: 'title-batman',
          mediaType: 'movie',
          title: 'The Batman: Dark Knight',
          normalizedTitle: 'the batman dark knight',
          plot: const Value('A hero in Gotham City fighting villains'),
          createdAt: now,
          updatedAt: now,
        ),
      );

      // Consulta limpia
      final clean = await dao.searchTitlesFts(rawQuery: 'batman');
      expect(clean.length, equals(1));
      expect(clean.first.id, equals('title-batman'));

      // Cadena con operadores booleanos reservados y caracteres de escape FTS5
      final complex = await dao.searchTitlesFts(rawQuery: 'batman" * :() - ^ ~ 😀 OR NEAR AND NOT');
      expect(complex.length, equals(1));
      expect(complex.first.id, equals('title-batman'));

      // Cadena vacía o solo símbolos
      final emptyResults = await dao.searchTitlesFts(rawQuery: '  "" ** --- :::  ');
      expect(emptyResults, isEmpty);
    });

    test('4. Búsqueda FTS5 con acentos y mayúsculas (Árbol -> arbol*)', () async {
      final now = DateTime.utc(2026, 9, 10, 12, 0, 0);

      await dao.upsertTitle(
        LocalTitlesCompanion.insert(
          id: 'title-arbol',
          mediaType: 'movie',
          title: 'El Árbol de la Vida',
          normalizedTitle: 'el arbol de la vida',
          plot: const Value('Una conmovedora historia sobre la existencia humana'),
          createdAt: now,
          updatedAt: now,
        ),
      );

      // Búsqueda en minúsculas y sin acentos
      final matchLower = await dao.searchTitlesFts(rawQuery: 'arbol');
      expect(matchLower.length, equals(1));
      expect(matchLower.first.id, equals('title-arbol'));

      // Búsqueda con mayúsculas y acentos
      final matchAccents = await dao.searchTitlesFts(rawQuery: 'ÁRBOL');
      expect(matchAccents.length, equals(1));
      expect(matchAccents.first.id, equals('title-arbol'));
    });

    test('5. Sincronización automática de FTS5 al actualizar o borrar títulos', () async {
      final now = DateTime.utc(2026, 9, 10, 12, 0, 0);

      await dao.upsertTitle(
        LocalTitlesCompanion.insert(
          id: 'title-sync',
          mediaType: 'movie',
          title: 'Initial Title Alpha',
          normalizedTitle: 'initial title alpha',
          createdAt: now,
          updatedAt: now,
        ),
      );

      expect((await dao.searchTitlesFts(rawQuery: 'Alpha')).length, equals(1));
      expect((await dao.searchTitlesFts(rawQuery: 'Omega')).length, equals(0));

      // Actualizar título a Omega
      await dao.upsertTitle(
        LocalTitlesCompanion.insert(
          id: 'title-sync',
          mediaType: 'movie',
          title: 'Updated Title Omega',
          normalizedTitle: 'updated title omega',
          createdAt: now,
          updatedAt: now,
        ),
      );

      expect((await dao.searchTitlesFts(rawQuery: 'Alpha')).length, equals(0));
      expect((await dao.searchTitlesFts(rawQuery: 'Omega')).length, equals(1));

      // Borrar título
      await dao.markTitleDeleted('title-sync');
      expect((await dao.searchTitlesFts(rawQuery: 'Omega')).length, equals(0));
    });

    test('6. Lápidas compuestas (title_genre) y eliminación local', () async {
      await dao.upsertTitle(LocalTitlesCompanion.insert(
        id: 'title-x',
        title: 'Title X',
        normalizedTitle: 'title x',
        mediaType: 'movie',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      await dao.upsertGenre(const LocalGenresCompanion(
        id: Value('genre-action'),
        name: Value('Action'),
        slug: Value('action'),
      ));

      await dao.linkTitleGenres([
        const LocalTitleGenresCompanion(
          titleId: Value('title-x'),
          genreId: Value('genre-action'),
        ),
      ]);

      var genres = await dao.getGenresForTitle('title-x');
      expect(genres.length, equals(1));
      expect(genres.first.id, equals('genre-action'));

      // Aplicar lápida para relación compuesta title_genre
      await dao.applyTombstone('title_genre', 'title-x:genre-action');

      genres = await dao.getGenresForTitle('title-x');
      expect(genres, isEmpty);
    });

    test('7. Transacción atómica de lote: simular fallo a mitad del proceso no avanza el checkpoint', () async {
      const initialRev = 100;
      await dao.setLastCatalogRevision(initialRev);

      // Simular intento de lote con fallo forzado
      expect(
        () async => await dao.applySyncBatchAtomic(
          operations: (tx) async {
            await tx.upsertGenre(const LocalGenresCompanion(
              id: Value('g-fail'),
              name: Value('Fail Genre'),
              slug: Value('fail-genre'),
            ));
            throw Exception('Fallo simulado de red o parsing a mitad del lote');
          },
          newRevision: 150,
          timestamp: DateTime.now(),
        ),
        throwsA(isA<Exception>()),
      );

      // Comprobar que la revisión NO avanzó
      final revAfterFail = await dao.getLastCatalogRevision();
      expect(revAfterFail, equals(initialRev));

      // Comprobar que los cambios del lote se revirtieron por completo
      final genres = await dao.getAllGenres();
      expect(genres.any((g) => g.id == 'g-fail'), isFalse);

      // Ahora simular lote exitoso
      await dao.applySyncBatchAtomic(
        operations: (tx) async {
          await tx.upsertGenre(const LocalGenresCompanion(
            id: Value('g-success'),
            name: Value('Success Genre'),
            slug: Value('success-genre'),
          ));
        },
        newRevision: 150,
        timestamp: DateTime.now(),
      );

      final revAfterSuccess = await dao.getLastCatalogRevision();
      expect(revAfterSuccess, equals(150));
      final genresSuccess = await dao.getAllGenres();
      expect(genresSuccess.any((g) => g.id == 'g-success'), isTrue);
    });

    test('8. EXPLAIN QUERY PLAN confirma el uso de índices reales en consultas críticas', () async {
      // 1. Cursor general
      final planCursor = await db.customSelect(
        'EXPLAIN QUERY PLAN SELECT * FROM local_titles WHERE is_deleted = 0 ORDER BY created_at DESC, id DESC LIMIT 20;',
      ).get();
      final planCursorDetail = planCursor.map((r) => r.data['detail'].toString()).join(' ');
      expect(planCursorDetail.contains('idx_titles_cursor') || planCursorDetail.contains('COVERING INDEX'), isTrue);

      // 2. Cursor por media_type
      final planMedia = await db.customSelect(
        "EXPLAIN QUERY PLAN SELECT * FROM local_titles WHERE is_deleted = 0 AND media_type = 'movie' ORDER BY created_at DESC, id DESC LIMIT 20;",
      ).get();
      final planMediaDetail = planMedia.map((r) => r.data['detail'].toString()).join(' ');
      expect(planMediaDetail.contains('idx_titles_media_cursor') || planMediaDetail.contains('COVERING INDEX') || planMediaDetail.contains('USING INDEX'), isTrue);

      // 3. Índice en seasons por title_id
      final planSeasons = await db.customSelect(
        "EXPLAIN QUERY PLAN SELECT * FROM local_seasons WHERE title_id = 't-test';",
      ).get();
      final planSeasonsDetail = planSeasons.map((r) => r.data['detail'].toString()).join(' ');
      expect(planSeasonsDetail.contains('idx_seasons_title') || planSeasonsDetail.contains('USING INDEX'), isTrue);

      // 4. Índice en episodes por season_id
      final planEpisodes = await db.customSelect(
        "EXPLAIN QUERY PLAN SELECT * FROM local_episodes WHERE season_id = 's-test';",
      ).get();
      final planEpisodesDetail = planEpisodes.map((r) => r.data['detail'].toString()).join(' ');
      expect(planEpisodesDetail.contains('idx_episodes_season') || planEpisodesDetail.contains('USING INDEX'), isTrue);

      // 5. Índice en sources por title_id
      final planSources = await db.customSelect(
        "EXPLAIN QUERY PLAN SELECT * FROM local_sources WHERE title_id = 't-test';",
      ).get();
      final planSourcesDetail = planSources.map((r) => r.data['detail'].toString()).join(' ');
      expect(planSourcesDetail.contains('idx_sources_title') || planSourcesDetail.contains('USING INDEX'), isTrue);
    });

    test('9. Matriz de Búsqueda FTS5: texto + mediaType + genreSlug + sort order', () async {
      final now = DateTime.utc(2026, 9, 10, 12, 0, 0);

      // Insertar géneros
      await dao.upsertGenre(const LocalGenresCompanion(
        id: Value('genre-sci-fi'),
        name: Value('Sci-Fi'),
        slug: Value('sci-fi'),
      ));
      await dao.upsertGenre(const LocalGenresCompanion(
        id: Value('genre-drama'),
        name: Value('Drama'),
        slug: Value('drama'),
      ));

      // Título 1: Película Sci-Fi Matrix, rating 9.0
      await dao.upsertTitle(LocalTitlesCompanion.insert(
        id: 'matrix-movie',
        mediaType: 'movie',
        title: 'Matrix Movie',
        normalizedTitle: 'matrix movie',
        rating: const Value(9.0),
        createdAt: now.subtract(const Duration(days: 2)),
        updatedAt: now,
      ));
      await dao.linkTitleGenres([
        const LocalTitleGenresCompanion(titleId: Value('matrix-movie'), genreId: Value('genre-sci-fi')),
      ]);

      // Título 2: Serie Sci-Fi Matrix, rating 8.0
      await dao.upsertTitle(LocalTitlesCompanion.insert(
        id: 'matrix-series',
        mediaType: 'series',
        title: 'Matrix Series',
        normalizedTitle: 'matrix series',
        rating: const Value(8.0),
        createdAt: now.subtract(const Duration(days: 1)),
        updatedAt: now,
      ));
      await dao.linkTitleGenres([
        const LocalTitleGenresCompanion(titleId: Value('matrix-series'), genreId: Value('genre-sci-fi')),
      ]);

      // Título 3: Película Drama Matrix, rating 7.0
      await dao.upsertTitle(LocalTitlesCompanion.insert(
        id: 'matrix-drama',
        mediaType: 'movie',
        title: 'Matrix Drama',
        normalizedTitle: 'matrix drama',
        rating: const Value(7.0),
        createdAt: now,
        updatedAt: now,
      ));
      await dao.linkTitleGenres([
        const LocalTitleGenresCompanion(titleId: Value('matrix-drama'), genreId: Value('genre-drama')),
      ]);

      // 1. Filtrar solo texto -> devuelve los 3
      final allMatrix = await dao.searchTitlesFts(rawQuery: 'matrix');
      expect(allMatrix.length, equals(3));

      // 2. Filtrar texto + mediaType = 'movie' -> devuelve 2 películas
      final movieMatrix = await dao.searchTitlesFts(rawQuery: 'matrix', mediaType: 'movie');
      expect(movieMatrix.length, equals(2));
      expect(movieMatrix.every((t) => t.mediaType == 'movie'), isTrue);

      // 3. Filtrar texto + genreSlug = 'sci-fi' -> devuelve 2 títulos sci-fi
      final sciFiMatrix = await dao.searchTitlesFts(rawQuery: 'matrix', genreSlug: 'sci-fi');
      expect(sciFiMatrix.length, equals(2));
      expect(sciFiMatrix.map((t) => t.id).toSet(), equals({'matrix-movie', 'matrix-series'}));

      // 4. Filtrar texto + mediaType = 'movie' + genreSlug = 'sci-fi' -> devuelve exactamente 1
      final movieSciFi = await dao.searchTitlesFts(
        rawQuery: 'matrix',
        mediaType: 'movie',
        genreSlug: 'sci-fi',
      );
      expect(movieSciFi.length, equals(1));
      expect(movieSciFi.first.id, equals('matrix-movie'));

      // 5. Ordenamiento por ratingDesc
      final sortedByRating = await dao.searchTitlesFts(
        rawQuery: 'matrix',
        sort: CatalogSortOrder.ratingDesc,
      );
      expect(sortedByRating.map((t) => t.id).toList(), equals(['matrix-movie', 'matrix-series', 'matrix-drama']));

      // 6. Ordenamiento por titleAsc
      final sortedByTitle = await dao.searchTitlesFts(
        rawQuery: 'matrix',
        sort: CatalogSortOrder.titleAsc,
      );
      expect(sortedByTitle.first.id, equals('matrix-drama'));
      expect(sortedByTitle.last.id, equals('matrix-series'));
    });

    test('10. getPage soporta CatalogSortOrder (ratingDesc, titleAsc)', () async {
      final now = DateTime.utc(2026, 9, 10, 12, 0, 0);

      await dao.upsertTitle(LocalTitlesCompanion.insert(
        id: 't-c',
        mediaType: 'movie',
        title: 'Title Charlie',
        normalizedTitle: 'title charlie',
        rating: const Value(6.5),
        createdAt: now,
        updatedAt: now,
      ));
      await dao.upsertTitle(LocalTitlesCompanion.insert(
        id: 't-a',
        mediaType: 'movie',
        title: 'Title Alpha',
        normalizedTitle: 'title alpha',
        rating: const Value(9.5),
        createdAt: now.subtract(const Duration(minutes: 5)),
        updatedAt: now,
      ));
      await dao.upsertTitle(LocalTitlesCompanion.insert(
        id: 't-b',
        mediaType: 'movie',
        title: 'Title Bravo',
        normalizedTitle: 'title bravo',
        rating: const Value(8.0),
        createdAt: now.subtract(const Duration(minutes: 10)),
        updatedAt: now,
      ));

      // Rating Descendente: Alpha (9.5) -> Bravo (8.0) -> Charlie (6.5)
      final byRating = await dao.getPage(sort: CatalogSortOrder.ratingDesc);
      expect(byRating.map((t) => t.id).toList(), equals(['t-a', 't-b', 't-c']));

      // Título Ascendente: Alpha -> Bravo -> Charlie
      final byTitle = await dao.getPage(sort: CatalogSortOrder.titleAsc);
      expect(byTitle.map((t) => t.id).toList(), equals(['t-a', 't-b', 't-c']));
    });
  });
}
