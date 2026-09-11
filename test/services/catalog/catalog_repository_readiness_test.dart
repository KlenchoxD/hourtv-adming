import 'dart:async';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:streamtv/database/catalog_database.dart';
import 'package:streamtv/database/daos/catalog_dao.dart';
import 'package:streamtv/models/channel.dart';
import 'package:streamtv/services/catalog/catalog_cursor.dart';
import 'package:streamtv/services/catalog/catalog_dtos.dart';
import 'package:streamtv/services/catalog/catalog_page_source.dart';
import 'package:streamtv/services/catalog/catalog_repository.dart';
import 'package:streamtv/services/catalog/catalog_sync_engine.dart';
import 'package:streamtv/services/catalog/supabase_catalog_gateway.dart';

class DelayedMockGateway extends SupabaseCatalogGateway {
  final Completer<void> syncCompleter = Completer<void>();
  bool failSync = false;

  @override
  Future<CatalogSyncMetadataDto> fetchSyncMetadata() async {
    await syncCompleter.future;
    if (failSync) throw const CatalogNetworkException('Supabase offline');
    return const CatalogSyncMetadataDto(
      minimumAvailableRevision: 0,
      latestRevision: 10,
    );
  }

  List<CatalogChangeDto> changesToReturn = [];

  @override
  Future<List<CatalogChangeDto>> fetchChanges({required int sinceRevision, int limit = 200}) async {
    await syncCompleter.future;
    if (failSync) throw const CatalogNetworkException('Supabase offline');
    return changesToReturn;
  }

  @override
  Future<CatalogDetailDto?> fetchTitleDetails(String titleId) async {
    return CatalogDetailDto(
      id: titleId,
      mediaType: 'movie',
      title: 'Película Sincronizada',
      normalizedTitle: 'pelicula sincronizada',
      isFeatured: false,
      createdAt: DateTime.utc(2026, 9, 10),
    );
  }

  @override
  Future<List<CatalogSummaryDto>> fetchCompleteSnapshot({int offset = 0, int limit = 500}) async => [];

  @override
  Future<CatalogPageResult<CatalogSummaryDto>> fetchTitlesPage({
    CatalogCursor? cursor,
    int limit = 20,
    String? mediaType,
    String? genreSlug,
    CatalogSortOrder sort = CatalogSortOrder.recent,
  }) async => const CatalogPageResult(items: [], hasMore: false);

  @override
  Future<List<CatalogSourceDto>> fetchTitleSources(String titleId) async => [];

  @override
  Future<List<CatalogSeasonDto>> fetchSeriesEpisodes(String titleId) async => [];
}

void main() {
  late CatalogDatabase db;
  late CatalogDao dao;
  late DelayedMockGateway gateway;
  late CatalogSyncEngine syncEngine;
  late CatalogRepository repository;

  setUp(() {
    db = CatalogDatabase.inMemory();
    dao = db.catalogDao;
    gateway = DelayedMockGateway();
    syncEngine = CatalogSyncEngine(gateway: gateway, dao: dao);
    repository = CatalogRepository(
      dao: dao,
      gateway: gateway,
      syncEngine: syncEngine,
    );
    CatalogRepository.setInstanceForTesting(repository);
  });

  tearDown(() async {
    CatalogRepository.setInstanceForTesting(null);
    await db.close();
  });

  group('CatalogRepository & CatalogPageSource Observable Readiness', () {
    test('1. CatalogRepository emite notificaciones observables en cambios de estado', () async {
      final statusesObserved = <CatalogRepositoryStatus>[];
      repository.addListener(() {
        statusesObserved.add(repository.status);
      });

      expect(repository.status, equals(CatalogRepositoryStatus.idle));
      expect(repository.isReady, isFalse);

      gateway.changesToReturn = [
        CatalogChangeDto(
          revision: 1,
          entityType: 'title',
          entityId: 'movie-synced-1',
          operation: 'upsert',
          changedAt: DateTime.utc(2026, 9, 10),
        ),
      ];

      final initFuture = repository.initialize();
      // Esperar que dao.getPage termine la verificación inicial asíncrona de caché
      await Future<void>.delayed(Duration.zero);
      expect(repository.status, equals(CatalogRepositoryStatus.syncing));
      expect(statusesObserved, contains(CatalogRepositoryStatus.syncing));

      // Liberar sync retardado
      gateway.syncCompleter.complete();
      final finalStatus = await initFuture;

      expect(finalStatus, equals(CatalogRepositoryStatus.ready));
      expect(repository.isReady, isTrue);
      expect(statusesObserved.last, equals(CatalogRepositoryStatus.ready));
    });

    test('2. Arranque con datos locales válidos emite offlineReady de inmediato sin esperar sync', () async {
      await dao.upsertTitle(
        LocalTitlesCompanion.insert(
          id: 'movie-cached-1',
          mediaType: 'movie',
          title: 'Película en Caché',
          normalizedTitle: 'pelicula en cache',
          createdAt: DateTime.utc(2026, 9, 10),
          updatedAt: DateTime.utc(2026, 9, 10),
        ),
      );

      final statusesObserved = <CatalogRepositoryStatus>[];
      repository.addListener(() {
        statusesObserved.add(repository.status);
      });

      // gateway.syncCompleter NO está completado (sync remoto bloqueado)
      final status = await repository.initialize();

      // Debe estar inmediatamente en offlineReady
      expect(status, equals(CatalogRepositoryStatus.offlineReady));
      expect(repository.isReady, isTrue);
      expect(statusesObserved.first, equals(CatalogRepositoryStatus.offlineReady));

      // Desbloquear background sync para terminar limpiamente
      gateway.syncCompleter.complete();
      await Future<void>.delayed(const Duration(milliseconds: 10));
    });

    test('3. CatalogPageSource se suscribe a CatalogRepository y recarga automáticamente cuando sync termina', () async {
      final pageSource = CatalogPageSource(dao: dao, repository: repository);
      await pageSource.loadInitialPage();

      // Inicialmente vacío
      expect(pageSource.items, isEmpty);

      // Simular que el sync o fallback inserta datos en Drift
      await dao.upsertTitle(
        LocalTitlesCompanion.insert(
          id: 'movie-synced-1',
          mediaType: 'movie',
          title: 'Película Sincronizada',
          normalizedTitle: 'pelicula sincronizada',
          createdAt: DateTime.utc(2026, 9, 10),
          updatedAt: DateTime.utc(2026, 9, 10),
        ),
      );

      // Repositorio notifica a sus observadores
      repository.setStatusForTesting(CatalogRepositoryStatus.ready);

      // Esperar microtask / async reload de CatalogPageSource
      await Future<void>.delayed(const Duration(milliseconds: 20));

      // pageSource se recargó automáticamente sin llamar loadInitialPage a mano
      expect(pageSource.items.length, equals(1));
      expect(pageSource.items.first.title, equals('Película Sincronizada'));

      pageSource.dispose();
    });

    test('4. Fallback puebla Drift y notifica a CatalogPageSource', () async {
      final pageSource = CatalogPageSource(dao: dao, repository: repository);
      await pageSource.loadInitialPage();
      expect(pageSource.items, isEmpty);

      repository.fallbackJsonLoader = () async => [
        Channel(
          name: 'Peli Fallback',
          url: 'https://cdn.example.com/stream.m3u8',
          tvgId: 'fb-1',
          forcedType: 'movie',
        ),
      ];

      gateway.failSync = true;
      gateway.syncCompleter.complete();

      await repository.initialize();
      expect(repository.status, equals(CatalogRepositoryStatus.offlineReady));

      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(pageSource.items.length, equals(1));
      expect(pageSource.items.first.title, equals('Peli Fallback'));

      pageSource.dispose();
    });
  });
}
