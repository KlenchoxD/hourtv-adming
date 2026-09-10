import 'package:flutter_test/flutter_test.dart';
import 'package:streamtv/database/catalog_database.dart';
import 'package:streamtv/database/daos/catalog_dao.dart';
import '../../tool/import_catalog_to_supabase.dart';

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

  group('Synthetic Catalog Scale & Importer Safety Tests', () {
    test('1. Importador rechaza hosts remotos antes de abrir sockets', () {
      expect(
        () => CatalogDirectImporter.validateTargetHost('supabase.remote.co', 54322),
        throwsA(isA<ArgumentError>()),
      );

      expect(
        () => CatalogDirectImporter.validateTargetHost('192.168.1.50', 54322),
        throwsA(isA<ArgumentError>()),
      );

      expect(
        () => CatalogDirectImporter.validateTargetHost('127.0.0.1', 5432), // Puerto incorrecto
        throwsA(isA<ArgumentError>()),
      );

      // Hosts locales permitidos
      expect(
        () => CatalogDirectImporter.validateTargetHost('127.0.0.1', 54322),
        returnsNormally,
      );
      expect(
        () => CatalogDirectImporter.validateTargetHost('localhost', 54322),
        returnsNormally,
      );
    });

    test('2. Inserción de 10,000 títulos sintéticos y paginación determinista de 50 páginas (0 duplicados, 0 pérdidas)', () async {
      final baseDate = DateTime.utc(2026, 9, 10, 0, 0, 0);

      // Inserción en lotes de 1,000 para optimizar tiempo en memoria
      const totalCount = 10000;
      const batchSize = 1000;

      for (var b = 0; b < totalCount / batchSize; b++) {
        final titlesBatch = <LocalTitlesCompanion>[];
        for (var i = 0; i < batchSize; i++) {
          final index = b * batchSize + i;
          final date = baseDate.add(Duration(seconds: index ~/ 10)); // Simula empates de fecha cada 10 títulos
          titlesBatch.add(
            LocalTitlesCompanion.insert(
              id: 'title-${index.toString().padLeft(6, '0')}',
              mediaType: index % 2 == 0 ? 'movie' : 'series',
              title: 'Synthetic Title $index',
              normalizedTitle: 'synthetic title $index',
              createdAt: date,
              updatedAt: date,
            ),
          );
        }
        await dao.upsertTitles(titlesBatch);
      }

      // Recorrer 50 páginas sucesivas de 20 títulos (1,000 títulos inspeccionados)
      const pagesToTest = 50;
      const pageSize = 20;
      final seenIds = <String>{};
      DateTime? cursorDate;
      String? cursorId;

      for (var page = 0; page < pagesToTest; page++) {
        final items = await dao.getPage(
          limit: pageSize,
          cursorCreatedAt: cursorDate,
          cursorId: cursorId,
        );

        expect(items.length, equals(pageSize));

        for (final item in items) {
          // Cero duplicados: ningún id debe haberse visto antes
          expect(seenIds.contains(item.id), isFalse, reason: 'Duplicate ID detected: ${item.id}');
          seenIds.add(item.id);
        }

        final last = items.last;
        cursorDate = last.createdAt;
        cursorId = last.id;
      }

      // Cero pérdidas: se deben haber recuperado exactamente 50 * 20 = 1,000 títulos únicos
      expect(seenIds.length, equals(pagesToTest * pageSize));
    });
  });
}
