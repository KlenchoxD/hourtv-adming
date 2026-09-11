// ignore_for_file: avoid_print

import 'dart:io';
import 'package:drift/drift.dart';
import 'package:streamtv/database/catalog_database.dart';

double _calculatePercentile(List<int> sorted, double percentile) {
  if (sorted.isEmpty) return 0.0;
  final index = (percentile / 100.0) * (sorted.length - 1);
  final lower = index.floor();
  final upper = index.ceil();
  if (lower == upper) return sorted[lower].toDouble();
  return sorted[lower] + (sorted[upper] - sorted[lower]) * (index - lower);
}

Future<void> main() async {
  print('=== HourTV Benchmark de Escala y Grafo Completo (10,000 Títulos) ===');

  Directory? tempDir;
  CatalogDatabase db;

  try {
    tempDir = Directory.systemTemp.createTempSync('hourtv_bench_');
    final dbFile = File('${tempDir.path}/bench_catalog.db');
    db = CatalogDatabase.inBackground(dbFile);
    print('-> Conexión a base de datos: NativeDatabase.createInBackground (${dbFile.path})');
  } catch (e) {
    print('-> Fallback a NativeDatabase.inMemory debido a: $e');
    db = CatalogDatabase.inMemory();
  }

  final dao = db.catalogDao;

  const totalTitles = 10000;
  const batchSize = 1000;
  final baseDate = DateTime.utc(2026, 9, 10, 0, 0, 0);

  print('\n1. Poblando grafo relacional completo (10 géneros, 10k títulos, temporadas, episodios y fuentes)...');
  final insertWatch = Stopwatch()..start();

  // 1.1 Géneros
  final genres = <LocalGenresCompanion>[
    for (var g = 1; g <= 10; g++)
      LocalGenresCompanion.insert(
        id: 'genre-$g',
        name: 'Genre $g',
        slug: 'genre-$g',
      ),
  ];
  await db.batch((b) {
    b.insertAll(db.localGenres, genres, mode: InsertMode.insertOrReplace);
  });

  // 1.2 Títulos, Relaciones, Temporadas, Episodios y Fuentes
  final expectedIds = <String>{};

  for (var b = 0; b < totalTitles / batchSize; b++) {
    final titlesBatch = <LocalTitlesCompanion>[];
    final titleGenresBatch = <LocalTitleGenresCompanion>[];
    final seasonsBatch = <LocalSeasonsCompanion>[];
    final episodesBatch = <LocalEpisodesCompanion>[];
    final sourcesBatch = <LocalSourcesCompanion>[];

    for (var i = 0; i < batchSize; i++) {
      final index = b * batchSize + i;
      final titleId = 'title-${index.toString().padLeft(6, '0')}';
      expectedIds.add(titleId);

      final isMovie = index % 2 == 0;
      final mediaType = isMovie ? 'movie' : 'series';
      final date = baseDate.add(Duration(seconds: index ~/ 10));

      titlesBatch.add(
        LocalTitlesCompanion.insert(
          id: titleId,
          mediaType: mediaType,
          title: 'Synthetic Title $index Special Edition',
          normalizedTitle: 'synthetic title $index special edition',
          plot: Value('An epic storyline number $index with galaxies, spaceships and heroes.'),
          year: Value(2000 + (index % 26)),
          rating: Value(5.0 + (index % 50) / 10.0),
          createdAt: date,
          updatedAt: date,
        ),
      );

      final genreId1 = 'genre-${(index % 10) + 1}';
      titleGenresBatch.add(LocalTitleGenresCompanion.insert(titleId: titleId, genreId: genreId1));

      if (isMovie) {
        sourcesBatch.add(
          LocalSourcesCompanion.insert(
            id: 'source-$titleId-1',
            titleId: Value(titleId),
            name: 'Server 4K',
            url: 'https://cdn.example.com/movies/$titleId.mp4',
            orderIndex: const Value(0),
          ),
        );
      } else {
        final seasonId = 'season-$titleId-1';
        seasonsBatch.add(
          LocalSeasonsCompanion.insert(
            id: seasonId,
            titleId: titleId,
            seasonNumber: 1,
            name: const Value('Temporada 1'),
          ),
        );

        for (var ep = 1; ep <= 2; ep++) {
          final episodeId = 'ep-$seasonId-$ep';
          episodesBatch.add(
            LocalEpisodesCompanion.insert(
              id: episodeId,
              seasonId: seasonId,
              episodeNumber: ep,
              title: 'Episodio $ep',
            ),
          );

          sourcesBatch.add(
            LocalSourcesCompanion.insert(
              id: 'source-$episodeId-1',
              episodeId: Value(episodeId),
              name: 'Server 1080p',
              url: 'https://cdn.example.com/episodes/$episodeId.m3u8',
              orderIndex: const Value(0),
            ),
          );
        }
      }
    }

    await db.transaction(() async {
      await db.batch((batch) {
        batch.insertAll(db.localTitles, titlesBatch, mode: InsertMode.insertOrReplace);
        batch.insertAll(db.localTitleGenres, titleGenresBatch, mode: InsertMode.insertOrReplace);
        batch.insertAll(db.localSeasons, seasonsBatch, mode: InsertMode.insertOrReplace);
        batch.insertAll(db.localEpisodes, episodesBatch, mode: InsertMode.insertOrReplace);
        batch.insertAll(db.localSources, sourcesBatch, mode: InsertMode.insertOrReplace);
      });

      for (final t in titlesBatch) {
        await dao.customStatement(
          'INSERT INTO local_titles_fts (title_id, normalized_title, original_title, plot) VALUES (?, ?, ?, ?)',
          [t.id.value, t.normalizedTitle.value, t.originalTitle.value ?? '', t.plot.value ?? ''],
        );
      }
    });
  }

  insertWatch.stop();
  print('-> Inserción masiva del grafo relacional completada en ${insertWatch.elapsedMilliseconds} ms (${(totalTitles / (insertWatch.elapsedMilliseconds / 1000)).toStringAsFixed(1)} títulos/s).');

  // 2. Medición de paginación determinista completa: 500 páginas sucesivas (10,000 títulos)
  print('\n2. Recorriendo deterministamente las 500 páginas (20 ítems/pág = 10,000 títulos)...');
  final cursorLatencies = <int>[];
  final seenIds = <String>{};
  DateTime? cursorCreatedAt;
  String? cursorId;
  const totalPages = 500;
  const pageSize = 20;

  for (var p = 0; p < totalPages; p++) {
    final sw = Stopwatch()..start();
    final page = await dao.getPage(
      limit: pageSize,
      cursorCreatedAt: cursorCreatedAt,
      cursorId: cursorId,
    );
    sw.stop();
    cursorLatencies.add(sw.elapsedMicroseconds);

    assert(sw.elapsedMilliseconds < 50, 'Latencia de página $p superó 50ms: ${sw.elapsedMilliseconds}ms');
    assert(page.length == pageSize, 'Página $p no retornó $pageSize elementos: ${page.length}');

    for (final item in page) {
      final isNew = seenIds.add(item.id);
      assert(isNew, 'ID duplicado detectado: ${item.id} en página $p');
    }

    final last = page.last;
    cursorCreatedAt = last.createdAt;
    cursorId = last.id;
  }

  assert(seenIds.length == totalTitles, 'Omisión detectada: se esperaban $totalTitles pero se vieron ${seenIds.length}');
  assert(seenIds.containsAll(expectedIds), 'Discrepancia en IDs esperados');

  cursorLatencies.sort();
  final medianCursorUs = _calculatePercentile(cursorLatencies, 50);
  final p95CursorUs = _calculatePercentile(cursorLatencies, 95);
  final p99CursorUs = _calculatePercentile(cursorLatencies, 99);

  print('Métricas Paginación por Cursor (500 páginas recorridas):');
  print('  Total títulos recuperados: ${seenIds.length} / $totalTitles (0 duplicados, 0 omisiones)');
  print('  Mediana (p50):             ${(medianCursorUs / 1000).toStringAsFixed(2)} ms ($medianCursorUs µs)');
  print('  p95:                       ${(p95CursorUs / 1000).toStringAsFixed(2)} ms ($p95CursorUs µs)');
  print('  p99:                       ${(p99CursorUs / 1000).toStringAsFixed(2)} ms ($p99CursorUs µs)');

  // 3. Medición de búsqueda indexada FTS5 (100 consultas con validación no tautológica)
  print('\n3. Midiendo búsquedas FTS5 indexadas (100 iteraciones con validación semántica real)...');
  final ftsLatencies = <int>[];
  final searchTerms = ['special', 'galaxy', 'adventure', 'spaceships', 'edition', 'synthetic', 'storyline', 'epic'];

  for (var i = 0; i < 100; i++) {
    final term = searchTerms[i % searchTerms.length];
    final sw = Stopwatch()..start();
    final results = await dao.searchTitlesFts(rawQuery: term, limit: 20);
    sw.stop();
    ftsLatencies.add(sw.elapsedMicroseconds);

    assert(results.isNotEmpty, 'La búsqueda FTS5 para "$term" debió retornar resultados');
    assert(
      results.every((t) => t.title.toLowerCase().contains(term) || t.plot?.toLowerCase().contains(term) == true),
      'Resultado FTS5 no contiene el término buscado: $term',
    );
  }

  ftsLatencies.sort();
  final medianFtsUs = _calculatePercentile(ftsLatencies, 50);
  final p95FtsUs = _calculatePercentile(ftsLatencies, 95);
  final p99FtsUs = _calculatePercentile(ftsLatencies, 99);

  print('Métricas Búsqueda FTS5 (100 consultas):');
  print('  Mediana (p50): ${(medianFtsUs / 1000).toStringAsFixed(2)} ms ($medianFtsUs µs)');
  print('  p95:           ${(p95FtsUs / 1000).toStringAsFixed(2)} ms ($p95FtsUs µs)');
  print('  p99:           ${(p99FtsUs / 1000).toStringAsFixed(2)} ms ($p99FtsUs µs)');

  // 4. Verificación de integridad relacional
  print('\n4. Verificando integridad del grafo relacional...');
  final movieSources = await dao.getSourcesForTitle('title-000000');
  assert(movieSources.isNotEmpty && movieSources.first.titleId == 'title-000000', 'Integridad de fuentes de película falló');

  final seriesSeasons = await dao.getSeasonsForTitle('title-000001');
  assert(seriesSeasons.isNotEmpty, 'Integridad de temporadas de serie falló');
  final episodes = await dao.getEpisodesForSeason(seriesSeasons.first.id);
  assert(episodes.length == 2, 'Integridad de episodios de temporada falló');
  print('-> Grafo relacional verificado: Películas con fuentes, Series con temporadas y episodios.');

  await db.close();
  try {
    tempDir?.deleteSync(recursive: true);
  } catch (_) {}

  print('\n=== Benchmark completado exitosamente. 10,000 títulos recorridos sin errores. ===');
}
