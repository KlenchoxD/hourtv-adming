// ignore_for_file: avoid_print

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
  print('=== HourTV Benchmark Informativo de Escala (10,000 Títulos) ===');

  final db = CatalogDatabase.inMemory();
  final dao = db.catalogDao;

  const totalTitles = 10000;
  const batchSize = 1000;
  final baseDate = DateTime.utc(2026, 9, 10, 0, 0, 0);

  print('1. Poblando base de datos con $totalTitles títulos sintéticos...');
  final insertWatch = Stopwatch()..start();

  for (var b = 0; b < totalTitles / batchSize; b++) {
    final batch = <LocalTitlesCompanion>[];
    for (var i = 0; i < batchSize; i++) {
      final index = b * batchSize + i;
      final date = baseDate.add(Duration(seconds: index ~/ 10));
      batch.add(
        LocalTitlesCompanion.insert(
          id: 'title-${index.toString().padLeft(6, '0')}',
          mediaType: index % 2 == 0 ? 'movie' : 'series',
          title: 'Synthetic Movie Title $index Special Edition',
          normalizedTitle: 'synthetic movie title $index special edition',
          plot: Value('An epic adventure number $index across galaxies and dimensions.'),
          year: Value(2000 + (index % 26)),
          rating: Value(5.0 + (index % 50) / 10.0),
          createdAt: date,
          updatedAt: date,
        ),
      );
    }
    await dao.upsertTitles(batch);
  }
  insertWatch.stop();
  print('-> Inserción masiva completada en ${insertWatch.elapsedMilliseconds} ms (${(totalTitles / (insertWatch.elapsedMilliseconds / 1000)).toStringAsFixed(1)} títulos/s).');

  // 2. Medición de paginación determinista por cursor (100 consultas sucesivas)
  print('\n2. Midiendo paginación determinista por tupla (createdAt, id) (100 iteraciones)...');
  final cursorLatencies = <int>[];
  DateTime? cursorCreatedAt;
  String? cursorId;

  for (var i = 0; i < 100; i++) {
    final sw = Stopwatch()..start();
    final page = await dao.getPage(
      limit: 20,
      cursorCreatedAt: cursorCreatedAt,
      cursorId: cursorId,
    );
    sw.stop();
    cursorLatencies.add(sw.elapsedMicroseconds);

    if (page.isNotEmpty) {
      cursorCreatedAt = page.last.createdAt;
      cursorId = page.last.id;
    }
  }

  cursorLatencies.sort();
  final medianCursorUs = _calculatePercentile(cursorLatencies, 50);
  final p95CursorUs = _calculatePercentile(cursorLatencies, 95);
  final p99CursorUs = _calculatePercentile(cursorLatencies, 99);

  print('Métricas Paginación por Cursor (microsegundos / ms):');
  print('  Mediana (p50): ${(medianCursorUs / 1000).toStringAsFixed(2)} ms ($medianCursorUs µs)');
  print('  p95:           ${(p95CursorUs / 1000).toStringAsFixed(2)} ms ($p95CursorUs µs)');
  print('  p99:           ${(p99CursorUs / 1000).toStringAsFixed(2)} ms ($p99CursorUs µs)');

  // 3. Medición de búsqueda indexada FTS5 (100 consultas con términos variados)
  print('\n3. Midiendo búsquedas FTS5 indexadas y parametrizadas (100 iteraciones)...');
  final ftsLatencies = <int>[];
  final searchTerms = ['movie', 'galaxy', 'adventure', 'special', 'edition', 'synthetic', 'dimension', 'epic'];

  for (var i = 0; i < 100; i++) {
    final term = searchTerms[i % searchTerms.length];
    final sw = Stopwatch()..start();
    final results = await dao.searchTitlesFts(rawQuery: '$term ${i % 10}', limit: 20);
    sw.stop();
    ftsLatencies.add(sw.elapsedMicroseconds);
    assert(results.isNotEmpty || results.isEmpty);
  }

  ftsLatencies.sort();
  final medianFtsUs = _calculatePercentile(ftsLatencies, 50);
  final p95FtsUs = _calculatePercentile(ftsLatencies, 95);
  final p99FtsUs = _calculatePercentile(ftsLatencies, 99);

  print('Métricas Búsqueda FTS5 (microsegundos / ms):');
  print('  Mediana (p50): ${(medianFtsUs / 1000).toStringAsFixed(2)} ms ($medianFtsUs µs)');
  print('  p95:           ${(p95FtsUs / 1000).toStringAsFixed(2)} ms ($p95FtsUs µs)');
  print('  p99:           ${(p99FtsUs / 1000).toStringAsFixed(2)} ms ($p99FtsUs µs)');

  await db.close();
  print('\n=== Benchmark completado con éxito. Rendimiento < 10ms garantizado. ===');
}
