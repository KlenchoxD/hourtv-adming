import 'package:flutter_test/flutter_test.dart';
import 'package:streamtv/database/catalog_database.dart';
import 'package:streamtv/database/daos/catalog_dao.dart';
import 'package:streamtv/services/catalog/catalog_cursor.dart';
import 'package:streamtv/services/catalog/catalog_dtos.dart';
import 'package:streamtv/services/catalog/catalog_sync_engine.dart';
import 'package:streamtv/services/catalog/supabase_catalog_gateway.dart';

/// Fake Gateway para simular respuestas y fallas controladas de Supabase
class FakeCatalogGateway implements SupabaseCatalogGateway {
  CatalogSyncMetadataDto metadata = const CatalogSyncMetadataDto(
    minimumAvailableRevision: 1,
    latestRevision: 100,
  );

  List<CatalogChangeDto> changesToReturn = [];
  Map<String, CatalogDetailDto> titlesOnServer = {};
  List<CatalogSummaryDto> snapshotTitles = [];

  bool throwOnFetchChanges = false;
  bool throwOnFetchTitleDetails = false;

  @override
  Future<CatalogSyncMetadataDto> fetchSyncMetadata() async => metadata;

  @override
  Future<List<CatalogChangeDto>> fetchChanges({
    required int sinceRevision,
    int limit = 200,
  }) async {
    if (throwOnFetchChanges) {
      throw const CatalogNetworkException('Simulated network failure on fetchChanges');
    }
    return changesToReturn
        .where((c) => c.revision > sinceRevision)
        .take(limit)
        .toList();
  }

  @override
  Future<CatalogDetailDto?> fetchTitleDetails(String titleId) async {
    if (throwOnFetchTitleDetails) {
      throw const CatalogNetworkException('Simulated network failure on fetchTitleDetails');
    }
    return titlesOnServer[titleId];
  }

  @override
  Future<List<CatalogSummaryDto>> fetchCompleteSnapshot({
    int offset = 0,
    int limit = 500,
  }) async {
    return snapshotTitles.skip(offset).take(limit).toList();
  }

  @override
  Future<CatalogPageResult<CatalogSummaryDto>> fetchTitlesPage({
    CatalogCursor? cursor,
    int limit = 20,
    String? mediaType,
    String? genreSlug,
    CatalogSortOrder sort = CatalogSortOrder.recent,
  }) async {
    return const CatalogPageResult(items: [], hasMore: false);
  }

  @override
  Future<List<CatalogSourceDto>> fetchTitleSources(String titleId) async => [];

  @override
  Future<List<CatalogSeasonDto>> fetchSeriesEpisodes(String titleId) async => [];
}

void main() {
  late CatalogDatabase db;
  late CatalogDao dao;
  late FakeCatalogGateway gateway;
  late CatalogSyncEngine engine;

  setUp(() {
    db = CatalogDatabase.inMemory();
    dao = db.catalogDao;
    gateway = FakeCatalogGateway();
    engine = CatalogSyncEngine(gateway: gateway, dao: dao);
  });

  tearDown(() async {
    await db.close();
  });

  group('CatalogSyncEngine Incremental & Resync Tests', () {
    test('1. Falla en medio de un lote: el checkpoint de revisión no se mueve', () async {
      await dao.setLastCatalogRevision(10);

      // Preparamos cambios en la revisión 20
      gateway.changesToReturn = [
        CatalogChangeDto(
          revision: 20,
          entityType: 'title',
          entityId: 't-fail',
          operation: 'upsert',
          changedAt: DateTime.utc(2026, 9, 10, 10, 0, 0),
        ),
      ];
      // Simulamos que la consulta del detalle falla
      gateway.throwOnFetchTitleDetails = true;

      expect(
        () async => await engine.syncCatalog(),
        throwsA(isA<CatalogNetworkException>()),
      );

      // Verificamos que la revisión se mantuvo en 10
      final rev = await dao.getLastCatalogRevision();
      expect(rev, equals(10));
    });

    test('2. Entidad con upsert borrada concurrentemente en el backend: tratada idempotentemente como lápida', () async {
      await dao.setLastCatalogRevision(10);

      // Título previamente existente en caché local
      await dao.upsertTitle(
        LocalTitlesCompanion.insert(
          id: 'title-concurrent',
          mediaType: 'movie',
          title: 'Concurrent Movie',
          normalizedTitle: 'concurrent movie',
          createdAt: DateTime.utc(2026, 9, 10, 10, 0, 0),
          updatedAt: DateTime.utc(2026, 9, 10, 10, 0, 0),
        ),
      );

      // Servidor emitió upsert, pero al consultarlo ya no existe (null)
      gateway.changesToReturn = [
        CatalogChangeDto(
          revision: 15,
          entityType: 'title',
          entityId: 'title-concurrent',
          operation: 'upsert',
          changedAt: DateTime.utc(2026, 9, 10, 11, 0, 0),
        ),
      ];
      // titlesOnServer NO contiene 'title-concurrent' (devuelve null)

      final result = await engine.syncCatalog();
      expect(result.finalRevision, equals(15));

      // Debe haber sido eliminado localmente (marcado como lápida)
      final local = await dao.getTitleById('title-concurrent');
      expect(local, isNull);
    });

    test('3. Repetición de un lote previo: idempotencia verificada sin duplicados', () async {
      await dao.setLastCatalogRevision(10);

      const titleId = 'title-repeat';
      gateway.titlesOnServer[titleId] = CatalogDetailDto(
        id: titleId,
        title: 'Repeat Title',
        normalizedTitle: 'repeat title',
        mediaType: 'movie',
        isFeatured: false,
        createdAt: DateTime.utc(2026, 9, 10, 12, 0, 0),
      );

      gateway.changesToReturn = [
        CatalogChangeDto(
          revision: 20,
          entityType: 'title',
          entityId: titleId,
          operation: 'upsert',
          changedAt: DateTime.utc(2026, 9, 10, 12, 0, 0),
        ),
      ];

      // Primera ejecución
      final res1 = await engine.syncCatalog();
      expect(res1.finalRevision, equals(20));

      // Re-ejecución forzando la misma revisión
      await dao.setLastCatalogRevision(10);
      final res2 = await engine.syncCatalog();
      expect(res2.finalRevision, equals(20));

      final count = (await dao.getPage()).where((t) => t.id == titleId).length;
      expect(count, equals(1));
    });

    test('4. Cliente con revisión compactada (lastCatalogRevision < minimumAvailableRevision): dispara Full Resync', () async {
      // Cliente tiene revisión local 50, pero el servidor compactó hasta la 100
      await dao.setLastCatalogRevision(50);

      gateway.metadata = const CatalogSyncMetadataDto(
        minimumAvailableRevision: 100,
        latestRevision: 250,
      );

      // Snapshot disponible en el servidor
      gateway.snapshotTitles = [
        CatalogSummaryDto(
          id: 'snapshot-1',
          title: 'Snapshot Movie 1',
          normalizedTitle: 'snapshot movie 1',
          mediaType: 'movie',
          isFeatured: true,
          createdAt: DateTime.utc(2026, 9, 10, 14, 0, 0),
        ),
        CatalogSummaryDto(
          id: 'snapshot-2',
          title: 'Snapshot Movie 2',
          normalizedTitle: 'snapshot movie 2',
          mediaType: 'movie',
          isFeatured: false,
          createdAt: DateTime.utc(2026, 9, 10, 14, 30, 0),
        ),
      ];

      final result = await engine.syncCatalog();
      expect(result.fullResyncPerformed, isTrue);
      expect(result.finalRevision, equals(250));

      // Verificamos que los títulos del snapshot están en la base local
      final titles = await dao.getPage();
      expect(titles.length, equals(2));
      expect(titles.any((t) => t.id == 'snapshot-1'), isTrue);
      expect(titles.any((t) => t.id == 'snapshot-2'), isTrue);

      final rev = await dao.getLastCatalogRevision();
      expect(rev, equals(250));
    });
  });
}
