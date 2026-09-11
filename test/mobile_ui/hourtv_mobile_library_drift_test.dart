import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamtv/database/catalog_database.dart';
import 'package:streamtv/database/daos/catalog_dao.dart';
import 'package:streamtv/models/channel.dart';
import 'package:streamtv/mobile_ui/hourtv_mobile_shell.dart';
import 'package:streamtv/services/catalog/catalog_dtos.dart';
import 'package:streamtv/services/catalog/catalog_repository.dart';
import 'package:streamtv/services/catalog/catalog_sync_engine.dart';
import 'package:streamtv/services/catalog/supabase_catalog_gateway.dart';
import 'package:streamtv/services/content_store.dart';
import 'package:streamtv/services/storage_service.dart';

class MockCatalogGateway extends SupabaseCatalogGateway {
  @override
  Future<CatalogSyncMetadataDto> fetchSyncMetadata() async => const CatalogSyncMetadataDto(
        minimumAvailableRevision: 0,
        latestRevision: 1,
      );

  @override
  Future<List<CatalogChangeDto>> fetchChanges({required int sinceRevision, int limit = 200}) async => [];

  @override
  Future<CatalogDetailDto?> fetchTitleDetails(String titleId) async => null;

  @override
  Future<List<CatalogSummaryDto>> fetchCompleteSnapshot({int offset = 0, int limit = 500}) async => [];

  @override
  Future<List<CatalogSourceDto>> fetchTitleSources(String titleId) async => [];

  @override
  Future<List<CatalogSeasonDto>> fetchSeriesEpisodes(String titleId) async => [];
}

void main() {
  late CatalogDatabase db;
  late CatalogDao dao;
  late MockCatalogGateway gateway;
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
    gateway = MockCatalogGateway();
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

  group('HourTvMobileLibrary Drift Resolution Tests', () {
    testWidgets('1. Película existente únicamente en Drift se hidrata en Mi Lista con póster y metadatos', (tester) async {
      // 1. Insertar película en Drift con póster y fuentes reales
      final now = DateTime.utc(2026, 9, 10);
      await dao.upsertTitle(
        LocalTitlesCompanion.insert(
          id: 'drift-movie-fav-1',
          mediaType: 'movie',
          title: 'Película Solo Drift',
          normalizedTitle: 'pelicula solo drift',
          posterUrl: const Value('https://cdn.example.com/drift_poster.jpg'),
          plot: const Value('Sinopsis guardada solo en base de datos local SQLite'),
          year: const Value(2026),
          rating: const Value(9.1),
          createdAt: now,
          updatedAt: now,
        ),
      );
      await dao.upsertSource(
        LocalSourcesCompanion.insert(
          id: 'src-1',
          titleId: const Value('drift-movie-fav-1'),
          name: 'Opción 1 - Full HD',
          url: 'https://cdn.example.com/stream.m3u8',
          language: const Value('Latino'),
        ),
      );

      // 2. Guardar como favorito (tarjeta que proviene de Drift)
      final favChannel = Channel(
        name: 'Película Solo Drift',
        url: 'catalog://drift-movie-fav-1',
        catalogTitleId: 'drift-movie-fav-1',
        forcedType: 'movie',
        isFavorite: true,
      );
      await StorageService.toggleFavorite(favChannel);

      Channel? openedChannel;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HourTvMobileLibrary(
              store: ContentStore.instance,
              catalogRepository: repository,
              onOpen: (ch) => openedChannel = ch,
            ),
          ),
        ),
      );

      // Esperar microtasks para que _resolveDriftItems hidrate el canal desde Drift
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Verificar que el título aparece en la grilla
      expect(find.text('Película Solo Drift'), findsOneWidget);

      // Tocar la tarjeta
      await tester.tap(find.text('Película Solo Drift'));
      await tester.pump();

      // Comprobar que el canal abierto está completamente hidratado con datos de Drift
      expect(openedChannel, isNotNull);
      expect(openedChannel!.name, equals('Película Solo Drift'));
      expect(openedChannel!.logo, equals('https://cdn.example.com/drift_poster.jpg'));
      expect(openedChannel!.plot, equals('Sinopsis guardada solo en base de datos local SQLite'));
      expect(openedChannel!.servers.length, equals(1));
      expect(openedChannel!.servers.first.url, equals('https://cdn.example.com/stream.m3u8'));
    });

    testWidgets('2. Serie existente únicamente en Drift en Continuar viendo se hidrata con progreso y póster', (tester) async {
      final now = DateTime.utc(2026, 9, 10);
      await dao.upsertTitle(
        LocalTitlesCompanion.insert(
          id: 'drift-series-cw-1',
          mediaType: 'series',
          title: 'Serie Solo Drift',
          normalizedTitle: 'serie solo drift',
          posterUrl: const Value('https://cdn.example.com/series_poster.jpg'),
          plot: const Value('Sinopsis de serie en Drift'),
          year: const Value(2026),
          createdAt: now,
          updatedAt: now,
        ),
      );
      await dao.upsertSeason(
        const LocalSeasonsCompanion(
          id: Value('s1'),
          titleId: Value('drift-series-cw-1'),
          seasonNumber: Value(1),
          name: Value('Temporada 1'),
        ),
      );
      await dao.upsertEpisode(
        const LocalEpisodesCompanion(
          id: Value('ep1'),
          seasonId: Value('s1'),
          episodeNumber: Value(1),
          title: Value('Episodio 1'),
        ),
      );
      await dao.upsertSource(
        const LocalSourcesCompanion(
          id: Value('src-ep-1'),
          episodeId: Value('ep1'),
          name: Value('Server 1'),
          url: Value('https://cdn.example.com/ep1.mp4'),
        ),
      );

      // Guardar progreso en almacenamiento
      final seriesChannel = Channel(
        name: 'Serie Solo Drift',
        url: 'catalog://drift-series-cw-1',
        catalogTitleId: 'drift-series-cw-1',
        forcedType: 'series',
      );
      await StorageService.saveRecent(seriesChannel);
      await ContentStore.instance.updatePlaybackProgress(seriesChannel, 0.45);

      Channel? openedContinue;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HourTvMobileLibrary(
              store: ContentStore.instance,
              catalogRepository: repository,
              onOpen: (_) {},
              onOpenContinue: (ch) => openedContinue = ch,
            ),
          ),
        ),
      );

      await tester.pump();

      // Cambiar a la pestaña "Continuar viendo"
      await tester.tap(find.text('CONTINUAR VIENDO'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Serie Solo Drift'), findsOneWidget);

      await tester.tap(find.text('Serie Solo Drift'));
      await tester.pump();

      expect(openedContinue, isNotNull);
      expect(openedContinue!.name, equals('Serie Solo Drift'));
      expect(openedContinue!.logo, equals('https://cdn.example.com/series_poster.jpg'));
      expect(openedContinue!.progressFraction, closeTo(0.45, 0.01));
      expect(openedContinue!.forcedType, equals('series'));
    });

    testWidgets('3. Canales tradicionales de TV en vivo se preservan en favoritos', (tester) async {
      final liveChannel = Channel(
        name: 'Canal Noticias 24',
        url: 'https://stream.example.com/live/noticias.m3u8',
        logo: 'https://cdn.example.com/noticias.png',
        group: 'Noticias',
        isFavorite: true,
      );
      await StorageService.toggleFavorite(liveChannel);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HourTvMobileLibrary(
              store: ContentStore.instance,
              catalogRepository: repository,
              onOpen: (_) {},
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Canal Noticias 24'), findsOneWidget);
    });
  });
}
