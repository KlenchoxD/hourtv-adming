import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamtv/database/catalog_database.dart';

void main() {
  late CatalogDatabase db;

  setUp(() => db = CatalogDatabase.inMemory());
  tearDown(() => db.close());

  test(
    'new databases persist source health and keep legacy defaults',
    () async {
      await db.catalogDao.upsertTitle(
        LocalTitlesCompanion.insert(
          id: 'movie-1',
          mediaType: 'movie',
          title: 'Movie',
          normalizedTitle: 'movie',
          createdAt: DateTime.utc(2026, 9, 20),
          updatedAt: DateTime.utc(2026, 9, 20),
        ),
      );
      await db.catalogDao.upsertSource(
        LocalSourcesCompanion.insert(
          id: 'legacy-source',
          titleId: const Value('movie-1'),
          name: 'Legacy',
          url: 'https://example.com/legacy',
        ),
      );
      await db.catalogDao.upsertSource(
        LocalSourcesCompanion.insert(
          id: 'health-source',
          titleId: const Value('movie-1'),
          name: 'Health',
          url: 'https://example.com/health',
          healthStatus: const Value('down'),
          healthLastError: const Value('timeout'),
          healthHttpCode: const Value(504),
          healthConsecutiveFailures: const Value(3),
          healthFirstFailureAt: Value(DateTime.utc(2026, 9, 20, 10)),
          healthLastSuccessAt: Value(DateTime.utc(2026, 9, 20, 9)),
          healthLastCheck: Value(DateTime.utc(2026, 9, 20, 10, 5)),
          healthLastCheckRunId: const Value('run-1'),
        ),
      );

      final rows = await db.catalogDao.getSourcesForTitle('movie-1');
      final legacy = rows.singleWhere((row) => row.id == 'legacy-source');
      final health = rows.singleWhere((row) => row.id == 'health-source');

      expect(legacy.healthStatus, 'pending');
      expect(legacy.healthConsecutiveFailures, 0);
      expect(health.healthStatus, 'down');
      expect(health.healthLastError, 'timeout');
      expect(health.healthHttpCode, 504);
      expect(health.healthConsecutiveFailures, 3);
      expect(health.healthLastCheckRunId, 'run-1');
    },
  );
}
