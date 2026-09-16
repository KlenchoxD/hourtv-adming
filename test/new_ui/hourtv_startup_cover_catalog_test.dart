import 'dart:async';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamtv/database/catalog_database.dart';
import 'package:streamtv/database/daos/catalog_dao.dart';
import 'package:streamtv/models/channel.dart';
import 'package:streamtv/new_ui/hourtv_startup_cover.dart';
import 'package:streamtv/services/catalog/catalog_dtos.dart';
import 'package:streamtv/services/catalog/catalog_repository.dart';
import 'package:streamtv/services/catalog/catalog_sync_engine.dart';
import 'package:streamtv/services/catalog/supabase_catalog_gateway.dart';
import 'package:streamtv/services/content_store.dart';
import 'package:streamtv/services/storage_service.dart';
import 'package:streamtv/services/xtream_service.dart';

class SimpleMockGateway extends SupabaseCatalogGateway {
  @override
  Future<CatalogSyncMetadataDto> fetchSyncMetadata() async =>
      const CatalogSyncMetadataDto(
        minimumAvailableRevision: 0,
        latestRevision: 1,
      );

  @override
  Future<List<CatalogChangeDto>> fetchChanges({
    required int sinceRevision,
    int limit = 200,
  }) async => [];

  @override
  Future<CatalogDetailDto?> fetchTitleDetails(String titleId) async => null;

  @override
  Future<List<CatalogSummaryDto>> fetchCompleteSnapshot({
    int offset = 0,
    int limit = 500,
  }) async => [];

  @override
  Future<List<CatalogSourceDto>> fetchTitleSources(String titleId) async => [];

  @override
  Future<List<CatalogSeasonDto>> fetchSeriesEpisodes(String titleId) async =>
      [];
}

void main() {
  late CatalogDatabase db;
  late CatalogDao dao;
  late SimpleMockGateway gateway;
  late CatalogSyncEngine syncEngine;
  late CatalogRepository repository;

  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    ContentStore.instance.resetForTesting();

    db = CatalogDatabase.inMemory();
    dao = db.catalogDao;
    gateway = SimpleMockGateway();
    syncEngine = CatalogSyncEngine(gateway: gateway, dao: dao);
    repository = CatalogRepository(
      dao: dao,
      gateway: gateway,
      syncEngine: syncEngine,
    );
    CatalogRepository.setInstanceForTesting(repository);

    // ContentStore listo con canales en vivo
    await ContentStore.instance.load(
      cacheLoader: () async => [
        Channel(name: 'Canal Live', url: 'https://example.com/live.m3u8'),
      ],
      seriesCacheLoader: () async => <XtreamSeries>[],
      remoteLoader: () async => [
        Channel(name: 'Canal Live', url: 'https://example.com/live.m3u8'),
      ],
    );
  });

  tearDown(() async {
    CatalogRepository.setInstanceForTesting(null);
    await db.close();
  });

  group('HourTvStartupCover & CatalogRepository Race Condition Tests', () {
    testWidgets(
      '1. Primera instalación con BD vacía y sincronización retardada: cover no se oculta antes de tiempo',
      (tester) async {
        // Estado de sincronización en curso
        repository.setStatusForTesting(CatalogRepositoryStatus.syncing);

        await tester.pumpWidget(
          MaterialApp(
            home: HourTvStartupCover(
              store: ContentStore.instance,
              catalogRepository: repository,
              child: const Scaffold(
                body: Center(child: Text('APP_CONTENT_REVEALED')),
              ),
            ),
          ),
        );

        // El cover DEBE seguir visible con título de sincronización inicial
        expect(find.text('Sincronizando catálogo inicial'), findsOneWidget);
        // El contenido de la app NO debe estar revelado aún
        expect(find.text('APP_CONTENT_REVEALED'), findsNothing);

        // Sincronización completa con éxito
        repository.setStatusForTesting(CatalogRepositoryStatus.ready);
        await tester.pump();

        // El cover se retira y se revela el contenido
        expect(find.text('APP_CONTENT_REVEALED'), findsOneWidget);
      },
    );

    testWidgets(
      '2. Instalaciones posteriores con caché local válida: entra de inmediato en offlineReady',
      (tester) async {
        // Estado con caché local válida
        repository.setStatusForTesting(CatalogRepositoryStatus.offlineReady);

        await tester.pumpWidget(
          MaterialApp(
            home: HourTvStartupCover(
              store: ContentStore.instance,
              catalogRepository: repository,
              child: const Scaffold(
                body: Center(child: Text('APP_CONTENT_REVEALED')),
              ),
            ),
          ),
        );

        await tester.pump();

        // El contenido se revela de inmediato sin esperar sync remoto
        expect(find.text('APP_CONTENT_REVEALED'), findsOneWidget);
        expect(find.text('Sincronizando catálogo inicial'), findsNothing);
      },
    );

    testWidgets(
      'caché Drift lista revela Inicio aunque el catálogo legado siga abriéndose',
      (tester) async {
        ContentStore.instance.resetForTesting();
        final cacheCompleter = Completer<List<Channel>>();
        unawaited(
          ContentStore.instance.load(
            cacheLoader: () => cacheCompleter.future,
            seriesCacheLoader: () async => <XtreamSeries>[],
            remoteLoader: () async => <Channel>[],
          ),
        );
        expect(
          ContentStore.instance.readiness.phase,
          CatalogLoadPhase.openingCache,
        );
        repository.setStatusForTesting(CatalogRepositoryStatus.offlineReady);

        await tester.pumpWidget(
          MaterialApp(
            home: HourTvStartupCover(
              store: ContentStore.instance,
              catalogRepository: repository,
              child: const Scaffold(
                body: Center(child: Text('APP_CONTENT_REVEALED')),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.text('APP_CONTENT_REVEALED'), findsOneWidget);
        expect(find.text('Abriendo caché local'), findsNothing);
        cacheCompleter.complete(const <Channel>[]);
      },
    );

    testWidgets(
      '3. Fallo en primera instalación: muestra pantalla de error con botón Reintentar y recupera',
      (tester) async {
        // Repositorio en estado de falla
        repository.setStatusForTesting(CatalogRepositoryStatus.failed);

        await tester.pumpWidget(
          MaterialApp(
            home: HourTvStartupCover(
              store: ContentStore.instance,
              catalogRepository: repository,
              child: const Scaffold(
                body: Center(child: Text('APP_CONTENT_REVEALED')),
              ),
            ),
          ),
        );

        await tester.pump();

        expect(find.text('No se pudo cargar el catálogo'), findsOneWidget);
        expect(find.text('Reintentar'), findsOneWidget);
        expect(find.text('APP_CONTENT_REVEALED'), findsNothing);

        // Simular toque en Reintentar
        await tester.tap(find.text('Reintentar'));
        await tester.pump();

        // Al recuperarse tras reintento, el cover se retira
        repository.setStatusForTesting(CatalogRepositoryStatus.ready);
        await tester.pump();

        expect(find.text('APP_CONTENT_REVEALED'), findsOneWidget);
      },
    );
  });
}
