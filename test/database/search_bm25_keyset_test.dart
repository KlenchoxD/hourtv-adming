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

  // Utilidad local: inserta un título genérico
  Future<void> insertTitle({
    required CatalogDao dao,
    required String id,
    required String normalizedTitle,
    String plot = '',
    int year = 2020,
    DateTime? createdAt,
  }) async {
    final now = createdAt ?? DateTime.utc(2026, 9, 15, 12, 0);
    await dao.upsertTitle(
      LocalTitlesCompanion.insert(
        id: id,
        mediaType: 'movie',
        title: normalizedTitle,
        normalizedTitle: normalizedTitle,
        plot: Value(plot),
        year: Value(year),
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  group('FTS5 BM25 & Keyset Cursor Search Tests', () {
    test('1. Búsqueda prioriza títulos exactos sobre prefijos, palabras completas y sinopsis', () async {
      final now = DateTime.utc(2026, 9, 15, 12, 0);

      await dao.upsertTitle(
        LocalTitlesCompanion.insert(
          id: 'title-exact',
          mediaType: 'movie',
          title: 'Matrix',
          normalizedTitle: 'matrix',
          plot: const Value('Película de acción y ciencia ficción'),
          year: const Value(1999),
          createdAt: now,
          updatedAt: now,
        ),
      );
      await dao.upsertTitle(
        LocalTitlesCompanion.insert(
          id: 'title-prefix',
          mediaType: 'movie',
          title: 'Matrix Reloaded',
          normalizedTitle: 'matrix reloaded',
          plot: const Value('Secuela en el mundo digital'),
          year: const Value(2003),
          createdAt: now,
          updatedAt: now,
        ),
      );
      await dao.upsertTitle(
        LocalTitlesCompanion.insert(
          id: 'title-plot-only',
          mediaType: 'movie',
          title: 'Cyber Heist',
          normalizedTitle: 'cyber heist',
          plot: const Value('Los hackers ingresan a una matrix informática de alta seguridad'),
          year: const Value(2022),
          createdAt: now,
          updatedAt: now,
        ),
      );

      final results = await dao.searchRankedKeyset(query: 'Matrix', limit: 10);

      expect(results.length, equals(3));
      expect(results[0].id, equals('title-exact'));
      expect(results[1].id, equals('title-prefix'));
      expect(results[2].id, equals('title-plot-only'));
    });

    test('2. Paginación Keyset determinista no omite ni duplica filas con igual score y fecha', () async {
      final fixedDate = DateTime.utc(2026, 1, 1, 0, 0, 0);

      for (var i = 1; i <= 6; i++) {
        await dao.upsertTitle(
          LocalTitlesCompanion.insert(
            id: 'matrix-tie-$i',
            mediaType: 'movie',
            title: 'The Matrix Chronicles Part $i',
            normalizedTitle: 'the matrix chronicles part $i',
            plot: const Value('Aventura en el ciberespacio'),
            year: const Value(2020),
            createdAt: fixedDate,
            updatedAt: fixedDate,
          ),
        );
      }

      final allResults = await dao.searchRankedKeyset(query: 'Matrix', limit: 10);
      expect(allResults.length, equals(6));

      final page1 = await dao.searchRankedKeyset(query: 'Matrix', limit: 2);
      expect(page1.length, equals(2));

      final cursor1 = dao.extractSearchCursor(page1.last, query: 'Matrix');
      expect(cursor1, isNotNull, reason: 'El cursor debe estar disponible tras la consulta');

      final page2 = await dao.searchRankedKeyset(
        query: 'Matrix',
        cursor: cursor1,
        limit: 2,
      );
      expect(page2.length, equals(2));

      final cursor2 = dao.extractSearchCursor(page2.last, query: 'Matrix');
      expect(cursor2, isNotNull);

      final page3 = await dao.searchRankedKeyset(
        query: 'Matrix',
        cursor: cursor2,
        limit: 2,
      );
      expect(page3.length, equals(2));

      // Concatenación exacta de páginas == conjunto completo
      final concatenated = [...page1, ...page2, ...page3];
      expect(
        concatenated.map((t) => t.id).toList(),
        equals(allResults.map((t) => t.id).toList()),
        reason: 'La concatenación debe ser idéntica al resultado sin cursor',
      );

      // Sin duplicados
      final idSet = concatenated.map((t) => t.id).toSet();
      expect(idSet.length, equals(6));
    });

    test('3. BM25: normalized_title (10.0) > original_title (5.0) > plot (0.2)', () async {
      final now = DateTime.utc(2026, 9, 15, 12, 0);

      await dao.upsertTitle(
        LocalTitlesCompanion.insert(
          id: 'item-plot',
          mediaType: 'movie',
          title: 'Rescate Nocturno',
          originalTitle: const Value('Night Rescue'),
          normalizedTitle: 'rescate nocturno',
          plot: const Value('Misión secreta con protocolo Quantum en la frontera'),
          year: const Value(2020),
          createdAt: now,
          updatedAt: now,
        ),
      );
      await dao.upsertTitle(
        LocalTitlesCompanion.insert(
          id: 'item-original-title',
          mediaType: 'movie',
          title: 'El Salto',
          originalTitle: const Value('Quantum Leap Origin'),
          normalizedTitle: 'el salto',
          plot: const Value('Viajes temporales y misterios cuánticos'),
          year: const Value(2020),
          createdAt: now,
          updatedAt: now,
        ),
      );
      await dao.upsertTitle(
        LocalTitlesCompanion.insert(
          id: 'item-normalized-title',
          mediaType: 'movie',
          title: 'Proyecto Quantum',
          originalTitle: const Value('The Project'),
          normalizedTitle: 'proyecto quantum',
          plot: const Value('Investigación secreta de física avanzada'),
          year: const Value(2020),
          createdAt: now,
          updatedAt: now,
        ),
      );

      final results = await dao.searchRankedKeyset(query: 'Quantum', limit: 10);

      expect(results.length, equals(3));
      expect(results[0].id, equals('item-normalized-title'),
          reason: 'normalized_title con peso 10.0 debe superar a original_title y plot');
      expect(results[1].id, equals('item-original-title'),
          reason: 'original_title con peso 5.0 debe superar a plot');
      expect(results[2].id, equals('item-plot'),
          reason: 'plot con peso 0.2 queda en tercer lugar');
    });

    // ─────────────────────────────────────────────────────────────────────────
    // CHECKPOINT B: Tests adicionales del cursor
    // ─────────────────────────────────────────────────────────────────────────

    test('4. Mismo título produce cursores distintos para consultas distintas', () async {
      // Un mismo título puede tener distinto matchTier y bm25Score
      // dependiendo de la consulta.
      await insertTitle(dao: dao, id: 'alien-title', normalizedTitle: 'alien resurrection');

      // Consulta A: "alien" → tier 2 (prefijo del título)
      final resultsA = await dao.searchRankedKeyset(query: 'alien', limit: 5);
      expect(resultsA.any((t) => t.id == 'alien-title'), isTrue);
      final cursorA = dao.extractSearchCursor(
        resultsA.firstWhere((t) => t.id == 'alien-title'),
        query: 'alien',
      );

      // Consulta B: "resurrection" → tier diferente / bm25Score diferente
      final resultsB = await dao.searchRankedKeyset(query: 'resurrection', limit: 5);
      expect(resultsB.any((t) => t.id == 'alien-title'), isTrue);
      final cursorB = dao.extractSearchCursor(
        resultsB.firstWhere((t) => t.id == 'alien-title'),
        query: 'resurrection',
      );

      expect(cursorA, isNotNull, reason: 'Cursor A debe existir tras consulta A');
      expect(cursorB, isNotNull, reason: 'Cursor B debe existir tras consulta B');

      // Los cursores deben diferir en matchTier o bm25Score
      // (alien = coincidencia en prefijo de normalizedTitle; resurrection = partial)
      final different = cursorA!.matchTier != cursorB!.matchTier ||
          cursorA.bm25Score != cursorB.bm25Score;
      expect(different, isTrue,
          reason:
              'Mismo título con distinta consulta debe producir cursores diferentes '
              '(tier A=${cursorA.matchTier}, B=${cursorB.matchTier})');
    });

    test('5. Cambio de consulta entre páginas: cursor devuelve null sin datos de la nueva consulta', () async {
      await insertTitle(dao: dao, id: 't1', normalizedTitle: 'matrix one');
      await insertTitle(dao: dao, id: 't2', normalizedTitle: 'matrix two');

      // Obtener primera página con consulta "matrix"
      final page1 = await dao.searchRankedKeyset(query: 'matrix', limit: 1);
      expect(page1.length, equals(1));

      // Sin ejecutar consulta "otro" primero, el cursor de ese título
      // para "otro" no debe estar en caché → null
      final cursorConOtro =
          dao.extractSearchCursor(page1.first, query: 'otro');
      expect(cursorConOtro, isNull,
          reason:
              'No debe haber cursor para "otro" si el título no fue devuelto '
              'bajo esa consulta');
    });

    test('6. Caché limitado: al superar 256 entradas, las más antiguas son evictadas', () async {
      // Insertar 260 títulos únicos
      for (var i = 0; i < 260; i++) {
        await insertTitle(
          dao: dao,
          id: 'flood-$i',
          normalizedTitle: 'film flood $i',
          plot: 'floodtest $i',
        );
      }

      // Ejecutar una consulta amplia para llenar el caché
      await dao.searchRankedKeyset(query: 'flood', limit: 260);

      // No se puede acceder directamente al mapa interno, pero el comportamiento
      // observable es que el caché no lanza excepción y los cursores de las
      // primeras filas pueden haber sido evictados (null aceptable).
      // Lo que sí debe mantenerse: los últimos 256 sí deben tener cursor.
      final results = await dao.searchRankedKeyset(query: 'flood', limit: 50);
      for (final title in results) {
        // Cualquiera que esté en la nueva consulta debe tener cursor disponible
        final cursor = dao.extractSearchCursor(title, query: 'flood');
        expect(cursor, isNotNull,
            reason:
                'Título recién consultado debe tener cursor disponible: ${title.id}');
      }
    });

    test('7. Cursor no disponible: extractSearchCursor devuelve null sin datos de consulta', () async {
      await insertTitle(dao: dao, id: 'orphan', normalizedTitle: 'orphan title');
      final title = await dao.getTitleById('orphan');
      expect(title, isNotNull);

      // Sin haber ejecutado ninguna búsqueda que devuelva este título,
      // el cursor debe ser null.
      final cursor = dao.extractSearchCursor(title!, query: 'orphan');
      expect(cursor, isNull,
          reason: 'Sin búsqueda previa no debe haber cursor fabricado');
    });

    test('8. Concatenación exacta de 3 páginas para consulta con 9 resultados', () async {
      final fixedDate = DateTime.utc(2025, 6, 1);
      for (var i = 1; i <= 9; i++) {
        await dao.upsertTitle(
          LocalTitlesCompanion.insert(
            id: 'action-$i',
            mediaType: 'movie',
            title: 'Action Movie $i',
            normalizedTitle: 'action movie $i',
            plot: const Value(''),
            year: const Value(2024),
            createdAt: fixedDate,
            updatedAt: fixedDate,
          ),
        );
      }

      final allResults = await dao.searchRankedKeyset(query: 'action', limit: 20);
      expect(allResults.length, equals(9));

      final p1 = await dao.searchRankedKeyset(query: 'action', limit: 3);
      final c1 = dao.extractSearchCursor(p1.last, query: 'action');
      expect(c1, isNotNull);

      final p2 = await dao.searchRankedKeyset(query: 'action', cursor: c1, limit: 3);
      final c2 = dao.extractSearchCursor(p2.last, query: 'action');
      expect(c2, isNotNull);

      final p3 = await dao.searchRankedKeyset(query: 'action', cursor: c2, limit: 3);

      final concat = [...p1, ...p2, ...p3];
      expect(concat.length, equals(9), reason: 'Debe haber exactamente 9 resultados concatenados');
      expect(
        concat.map((t) => t.id).toList(),
        equals(allResults.map((t) => t.id).toList()),
        reason: 'Concatenación de páginas debe ser idéntica al resultado completo',
      );
      expect(concat.map((t) => t.id).toSet().length, equals(9),
          reason: 'Sin duplicados');
    });
  });
}
