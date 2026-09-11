import 'package:flutter_test/flutter_test.dart';
import 'package:streamtv/database/catalog_database.dart';
import 'package:streamtv/models/channel.dart';
import 'package:streamtv/services/catalog_parser.dart';
import 'package:streamtv/services/catalog/catalog_cursor.dart';
import 'package:streamtv/services/catalog/catalog_dtos.dart';
import 'package:streamtv/services/catalog/catalog_infrastructure.dart';
import 'package:streamtv/services/catalog/catalog_page_source.dart';
import 'package:streamtv/services/catalog/catalog_repository.dart';
import 'package:streamtv/services/catalog/catalog_sync_engine.dart';
import 'package:streamtv/services/catalog/supabase_catalog_gateway.dart';
import 'package:streamtv/services/catalog/unavailable_catalog_gateway.dart';
import 'package:streamtv/services/supabase_bootstrap.dart';
import 'package:streamtv/services/supabase_config.dart';
import 'package:streamtv/services/xtream_service.dart';

class _MockRemoteGateway extends SupabaseCatalogGateway {
  _MockRemoteGateway() : super(null);

  bool fetchMetadataCalled = false;

  @override
  Future<CatalogSyncMetadataDto> fetchSyncMetadata() async {
    fetchMetadataCalled = true;
    return const CatalogSyncMetadataDto(
      minimumAvailableRevision: 1,
      latestRevision: 1,
    );
  }

  @override
  Future<List<CatalogSummaryDto>> fetchTitlesSnapshotKeyset({
    String? lastId,
    int limit = 500,
  }) async {
    if (lastId != null) return [];
    return [
      CatalogSummaryDto(
        id: 'remote-movie-1',
        title: 'Remote Test Movie',
        normalizedTitle: 'remote test movie',
        mediaType: 'movie',
        isFeatured: false,
        createdAt: DateTime.utc(2026, 1, 1),
        genres: const ['Action'],
      ),
    ];
  }

  @override
  Future<List<CatalogGenreDto>> fetchGenresSnapshotKeyset({String? lastId, int limit = 500}) async => [];

  @override
  Future<List<CatalogLanguageDto>> fetchLanguagesSnapshotKeyset({String? lastId, int limit = 500}) async => [];

  @override
  Future<List<Map<String, String>>> fetchTitleGenresSnapshotKeyset({String? lastTitleId, int limit = 1000}) async => [];

  @override
  Future<List<CatalogSeasonDto>> fetchSeasonsSnapshotKeyset({String? lastId, int limit = 500}) async => [];

  @override
  Future<List<CatalogEpisodeDto>> fetchEpisodesSnapshotKeyset({String? lastId, int limit = 500}) async => [];

  @override
  Future<List<CatalogSourceDto>> fetchSourcesSnapshotKeyset({String? lastId, int limit = 500}) async => [];

  @override
  Future<List<CatalogChangeDto>> fetchChanges({
    required int sinceRevision,
    int limit = 200,
  }) async => [];

  @override
  Future<CatalogPageResult<CatalogSummaryDto>> fetchTitlesPage({
    CatalogCursor? cursor,
    int limit = 20,
    String? mediaType,
    String? genreSlug,
    CatalogSortOrder sort = CatalogSortOrder.recent,
  }) async => const CatalogPageResult(items: [], hasMore: false);

  @override
  Future<CatalogDetailDto?> fetchTitleDetails(String titleId) async => null;

  @override
  Future<List<CatalogSourceDto>> fetchTitleSources(String titleId) async => [];

  @override
  Future<List<CatalogSeasonDto>> fetchSeriesEpisodes(String titleId) async => [];
}

class _FailingRemoteGateway extends SupabaseCatalogGateway {
  _FailingRemoteGateway() : super(null);

  @override
  Future<CatalogSyncMetadataDto> fetchSyncMetadata() async {
    throw const CatalogNetworkException('Simulated Supabase 503 error');
  }

  @override
  Future<List<CatalogChangeDto>> fetchChanges({
    required int sinceRevision,
    int limit = 100,
  }) async => [];

  @override
  Future<CatalogPageResult<CatalogSummaryDto>> fetchTitlesPage({
    CatalogCursor? cursor,
    int limit = 20,
    String? mediaType,
    String? genreSlug,
    CatalogSortOrder sort = CatalogSortOrder.recent,
  }) async => const CatalogPageResult(items: [], hasMore: false);

  @override
  Future<CatalogDetailDto?> fetchTitleDetails(String titleId) async => null;

  @override
  Future<List<CatalogSourceDto>> fetchTitleSources(String titleId) async => [];

  @override
  Future<List<CatalogSeasonDto>> fetchSeriesEpisodes(String titleId) async => [];

  @override
  Future<List<CatalogSummaryDto>> fetchCompleteSnapshot({int limit = 200, int offset = 0}) async => [];
}

CatalogPayload _sampleFallbackPayload() {
  return CatalogPayload(
    channels: [
      Channel(
        name: 'Fallback Local Movie',
        url: 'https://stream.example.com/movie.mp4',
        category: 'peliculas',
        forcedType: 'movie',
        logo: 'https://example.com/fallback-movie.jpg',
        tvgId: 'catalog:local-1',
        servers: [
          ChannelServer(
            name: 'Servidor Local 1',
            url: 'https://stream.example.com/movie.mp4',
          ),
        ],
      ),
    ],
    series: [
      XtreamSeries(
        seriesId: 'catalog:local-series-1',
        name: 'Fallback Local Series',
        host: '',
        username: '',
        password: '',
        cover: 'https://example.com/fallback-series.jpg',
        plot: 'Serie local de fallback',
        genre: 'Drama',
        episodes: [
          Channel(
            name: 'Capitulo 1',
            url: 'https://stream.example.com/ep1.mp4',
            group: 'T1',
            tvgId: 'catalog:local-series-1:1:1',
            category: 'series',
            forcedType: 'series',
            servers: [
              ChannelServer(
                name: 'Servidor EP 1',
                url: 'https://stream.example.com/ep1.mp4',
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

void main() {
  group('CatalogInfrastructure Unconfigured Supabase Tests', () {
    late CatalogDatabase db;

    setUp(() {
      db = CatalogDatabase.inMemory();
    });

    tearDown(() async {
      await db.close();
      CatalogRepository.setInstanceForTesting(null);
    });

    test('1. SupabaseConfig vacío -> CatalogRepository sí queda configurado con gateway no disponible', () async {
      final bootstrap = SupabaseBootstrap.forTest();
      await bootstrap.initialize(SupabaseConfig.parse(url: '', publishableKey: ''));

      expect(bootstrap.isAvailable, isFalse);
      expect(bootstrap.client, isNull);

      final infra = await initializeCatalogInfrastructure(
        catalogDatabase: db,
        bootstrap: bootstrap,
        autoInitializeRepository: false,
      );

      expect(CatalogRepository.hasInstance, isTrue);
      expect(CatalogRepository.instance, same(infra.repository));
      expect(infra.repository.gateway, isA<UnavailableCatalogGateway>());
      expect(infra.repository.syncEngine, isNull);
    });

    test('2. Base Drift vacía + Supabase no disponible -> carga sources.json y queda offlineReady', () async {
      final bootstrap = SupabaseBootstrap.forTest();
      await bootstrap.initialize(SupabaseConfig.parse(url: '', publishableKey: ''));

      final infra = await initializeCatalogInfrastructure(
        catalogDatabase: db,
        bootstrap: bootstrap,
        fallbackPayloadLoader: () async => _sampleFallbackPayload(),
        autoInitializeRepository: false,
      );

      // Verificamos estado inicial antes de inicializar
      expect(infra.repository.status, CatalogRepositoryStatus.idle);
      expect(await db.catalogDao.getPage(limit: 1), isEmpty);

      // Ejecutamos inicialización de catálogo sin Supabase
      final status = await infra.repository.initialize();

      expect(status, CatalogRepositoryStatus.offlineReady);
      expect(infra.repository.status, CatalogRepositoryStatus.offlineReady);

      // Verificamos que Drift contiene las entidades de sources.json
      final movies = await db.catalogDao.getPage(mediaType: 'movie', limit: 10);
      expect(movies, hasLength(1));
      expect(movies.first.title, 'Fallback Local Movie');

      final series = await db.catalogDao.getPage(mediaType: 'series', limit: 10);
      expect(series, hasLength(1));
      expect(series.first.title, 'Fallback Local Series');
    });

    test('3. Modo Invitado entra con offlineReady y catálogo visible', () async {
      final bootstrap = SupabaseBootstrap.forTest();
      await bootstrap.initialize(SupabaseConfig.parse(url: '', publishableKey: ''));

      final infra = await initializeCatalogInfrastructure(
        catalogDatabase: db,
        bootstrap: bootstrap,
        fallbackPayloadLoader: () async => _sampleFallbackPayload(),
        autoInitializeRepository: false,
      );

      await infra.repository.initialize();

      // En modo invitado (sin Supabase), status es offlineReady y canEnterApp es true
      expect(infra.repository.isReady, isTrue);
      expect(infra.repository.status, CatalogRepositoryStatus.offlineReady);

      // CatalogPageSource puede cargar las páginas sin depender de Supabase
      final pageSource = CatalogPageSource(
        repository: infra.repository,
        dao: db.catalogDao,
        mediaType: 'movie',
        pageSize: 10,
      );
      await pageSource.loadNextPage();

      expect(pageSource.items, isNotEmpty);
      expect(pageSource.items.first.title, 'Fallback Local Movie');
    });

    test('4. Supabase configurado -> usa gateway remoto y syncEngine', () async {
      final remoteGateway = _MockRemoteGateway();
      final syncEngine = CatalogSyncEngine(gateway: remoteGateway, dao: db.catalogDao);

      final infra = await initializeCatalogInfrastructure(
        catalogDatabase: db,
        gateway: remoteGateway,
        syncEngine: syncEngine,
        autoInitializeRepository: false,
      );

      expect(infra.repository.gateway, same(remoteGateway));
      expect(infra.repository.syncEngine, same(syncEngine));

      final status = await infra.repository.initialize();

      expect(status, CatalogRepositoryStatus.ready);
      expect(remoteGateway.fetchMetadataCalled, isTrue);

      final titles = await db.catalogDao.getPage(limit: 10);
      expect(titles.any((t) => t.title == 'Remote Test Movie'), isTrue);
    });

    test('5. Fallo de Supabase -> fallback local', () async {
      final failingGateway = _FailingRemoteGateway();
      final syncEngine = CatalogSyncEngine(gateway: failingGateway, dao: db.catalogDao);

      final infra = await initializeCatalogInfrastructure(
        catalogDatabase: db,
        gateway: failingGateway,
        syncEngine: syncEngine,
        fallbackPayloadLoader: () async => _sampleFallbackPayload(),
        autoInitializeRepository: false,
      );

      final status = await infra.repository.initialize();

      // El fallo de Supabase no bloquea el arranque: realiza fallback local
      expect(status, CatalogRepositoryStatus.offlineReady);
      expect(infra.repository.status, CatalogRepositoryStatus.offlineReady);

      final titles = await db.catalogDao.getPage(limit: 10);
      expect(titles.any((t) => t.title == 'Fallback Local Movie'), isTrue);
    });

    test('6. Errores se sanitizan sin exponer claves ni URLs', () async {
      final loggedMessages = <String>[];
      final bootstrap = SupabaseBootstrap.forTest();

      await initializeCatalogInfrastructure(
        catalogDatabase: db,
        bootstrap: bootstrap,
        fallbackPayloadLoader: () async {
          throw Exception('https://secret-project.supabase.co?apikey=sb_secret_key_123');
        },
        logError: (message, [error]) {
          loggedMessages.add(message);
        },
        autoInitializeRepository: true,
      );

      // Esperar eventos asíncronos del repository autoInitialize
      await pumpEventQueue();

      for (final msg in loggedMessages) {
        expect(msg, isNot(contains('sb_secret_key_123')));
        expect(msg, isNot(contains('secret-project.supabase.co')));
      }
    });
  });
}
