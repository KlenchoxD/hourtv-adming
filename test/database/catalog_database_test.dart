import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:streamtv/database/catalog_database.dart';
import 'package:streamtv/database/daos/catalog_dao.dart';

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
  });
}
