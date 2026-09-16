import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:streamtv/database/catalog_database.dart';
import 'package:streamtv/database/daos/catalog_dao.dart';
import 'package:streamtv/models/channel.dart';
import 'package:streamtv/services/catalog/catalog_page_source.dart';

class _FtsRow {
  final String titleId;
  final String normalizedTitle;
  final String originalTitle;
  final String plot;

  const _FtsRow({
    required this.titleId,
    required this.normalizedTitle,
    required this.originalTitle,
    required this.plot,
  });
}

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

  group('Catalog Search Scale & Mapping Cache Tests (10,000 Titles)', () {
    test('Búsqueda a escala sobre 10,000 títulos encuentra elementos fuera de la primera página sin reconstrucciones repetidas', () async {
      const totalTitles = 10000;
      const batchSize = 1000;
      final baseDate = DateTime.utc(2026, 1, 1);

      // 1. Inserción de 10,000 títulos en lotes atómicos tanto en tabla principal como en índice FTS5
      for (var b = 0; b < totalTitles ~/ batchSize; b++) {
        final titlesBatch = <LocalTitlesCompanion>[];
        final ftsRows = <_FtsRow>[];

        for (var i = 0; i < batchSize; i++) {
          final index = b * batchSize + i;
          final titleId = 'scale-title-${index.toString().padLeft(6, '0')}';

          String titleName;
          if (index == 7842) {
            titleName = 'Cyberpunk Odyssey Beyond Horizon';
          } else if (index == 9850) {
            titleName = 'Omega Interstellar Quantum Voyage';
          } else if (index % 100 == 0) {
            titleName = 'Starlight Chronicles Episode $index';
          } else {
            titleName = 'Synthetic Media Item $index Adventure';
          }

          final normTitle = titleName.toLowerCase();
          final isMovie = index % 2 == 0;
          final date = baseDate.add(Duration(minutes: index));

          titlesBatch.add(
            LocalTitlesCompanion.insert(
              id: titleId,
              mediaType: isMovie ? 'movie' : 'series',
              title: titleName,
              normalizedTitle: normTitle,
              plot: Value('Synopsis for $titleName in synthetic catalog test.'),
              createdAt: date,
              updatedAt: date,
            ),
          );

          ftsRows.add(_FtsRow(
            titleId: titleId,
            normalizedTitle: normTitle,
            originalTitle: titleName,
            plot: 'Synopsis for $titleName in synthetic catalog test.',
          ));
        }

        await db.batch((batch) {
          batch.insertAll(db.localTitles, titlesBatch, mode: InsertMode.insertOrReplace);
        });

        // Insertar en FTS5 en bloques de 200 filas (800 variables por statement)
        const chunkSize = 200;
        for (var offset = 0; offset < ftsRows.length; offset += chunkSize) {
          final chunk = ftsRows.sublist(offset, (offset + chunkSize).clamp(0, ftsRows.length));
          final placeholders = List.filled(chunk.length, '(?, ?, ?, ?)').join(', ');
          final args = <Object?>[];
          for (final row in chunk) {
            args.addAll([row.titleId, row.normalizedTitle, row.originalTitle, row.plot]);
          }
          await db.customStatement(
            'INSERT INTO local_titles_fts (title_id, normalized_title, original_title, plot) VALUES $placeholders',
            args,
          );
        }
      }

      final count = await dao.countTitles();
      expect(count, equals(totalTitles));

      // 2. Comprobar búsqueda fuera de la primera página
      // La primera página por defecto contiene los títulos más recientes (index 9980 a 9999)
      // Buscaremos un título específico ubicado en index 7842 (página ~390 de 500)
      final pageSource = CatalogPageSource(dao: dao, pageSize: 20);

      final searchSw = Stopwatch()..start();
      await pageSource.search('Cyberpunk Odyssey');
      searchSw.stop();

      expect(pageSource.items, isNotEmpty);
      expect(pageSource.items.first.title, equals('Cyberpunk Odyssey Beyond Horizon'));
      expect(pageSource.items.first.id, equals('scale-title-007842'));

      // 3. Buscar título en el extremo final (index 9850)
      final searchSw2 = Stopwatch()..start();
      await pageSource.search('Omega Interstellar');
      searchSw2.stop();

      expect(pageSource.items, isNotEmpty);
      expect(pageSource.items.first.title, equals('Omega Interstellar Quantum Voyage'));
      expect(pageSource.items.first.id, equals('scale-title-009850'));

      // 4. Verificación de ausencia de mapeos repetidos (Channel Mapping Cache)
      // Simulamos la caché mantenida fuera de build() en la capa UI (HourTvMobileSearch)
      int mappingTransformCount = 0;
      final cachedChannelMap = <String, Channel>{};

      List<Channel> getCachedChannels(List<LocalTitle> titles) {
        return titles.map((t) {
          return cachedChannelMap.putIfAbsent(t.id, () {
            mappingTransformCount++;
            return Channel(
              name: t.title,
              url: 'https://stream.test/${t.id}.m3u8',
              tvgId: t.id,
              logo: t.posterUrl,
            );
          });
        }).toList();
      }

      // Primera resolución de canales para los resultados de búsqueda actuales
      final initialChannels = getCachedChannels(pageSource.items);
      expect(initialChannels, isNotEmpty);
      final initialTransformCalls = mappingTransformCount;
      expect(initialTransformCalls, equals(pageSource.items.length));

      // Simulamos 5 re-renders sucesivos de UI con la misma página/resultados
      for (var r = 0; r < 5; r++) {
        final reaccessedChannels = getCachedChannels(pageSource.items);
        expect(reaccessedChannels.length, equals(initialChannels.length));
        expect(reaccessedChannels.first.tvgId, equals(initialChannels.first.tvgId));
      }

      // El conteo de transformaciones no debe incrementarse en lecturas repetidas
      expect(
        mappingTransformCount,
        equals(initialTransformCalls),
        reason: 'La caché de mapeo fuera de build() no debe repetir transformaciones en lecturas sucesivas',
      );

      // 5. Medición diagnóstica de latencia (sin aserción estricta de milisegundos en CI)
      final benchmarkQueries = [
        'Cyberpunk',
        'Omega',
        'Starlight',
        'Adventure',
        'Voyage',
        'Horizon',
        'Chronicles',
        'Quantum',
      ];

      final queryLatencies = <int>[];
      for (final q in benchmarkQueries) {
        final sw = Stopwatch()..start();
        final res = await dao.searchTitlesFts(rawQuery: q, limit: 20);
        sw.stop();
        queryLatencies.add(sw.elapsedMicroseconds);
        expect(res, isNotEmpty);
      }

      queryLatencies.sort();
      final medianUs = queryLatencies[queryLatencies.length ~/ 2];
      final p95Us = queryLatencies[(queryLatencies.length * 0.95).floor().clamp(0, queryLatencies.length - 1)];

      // ignore: avoid_print
      print('[DIAGNÓSTICO SCALE SEARCH] 10k títulos - Mediana: ${(medianUs / 1000).toStringAsFixed(2)} ms, P95: ${(p95Us / 1000).toStringAsFixed(2)} ms');

      pageSource.dispose();
    });
  });
}
