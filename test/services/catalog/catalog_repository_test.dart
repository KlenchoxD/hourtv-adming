import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:streamtv/database/catalog_database.dart';
import 'package:streamtv/database/daos/catalog_dao.dart';
import 'package:streamtv/models/channel.dart';
import 'package:streamtv/services/catalog/catalog_cursor.dart';
import 'package:streamtv/services/catalog/catalog_dtos.dart';
import 'package:streamtv/services/catalog/catalog_repository.dart';
import 'package:streamtv/services/catalog/catalog_sync_engine.dart';
import 'package:streamtv/services/catalog/supabase_catalog_gateway.dart';

class MockCatalogGateway implements SupabaseCatalogGateway {
  bool shouldFail = false;
  CatalogSyncMetadataDto metadata = const CatalogSyncMetadataDto(
    minimumAvailableRevision: 1,
    latestRevision: 10,
  );

  @override
  Future<CatalogSyncMetadataDto> fetchSyncMetadata() async {
    if (shouldFail) throw const CatalogNetworkException('500 Internal Server Error');
    return metadata;
  }

  @override
  Future<List<CatalogChangeDto>> fetchChanges({required int sinceRevision, int limit = 200}) async {
    if (shouldFail) throw const CatalogNetworkException('500 Internal Server Error');
    return [];
  }

  @override
  Future<CatalogDetailDto?> fetchTitleDetails(String titleId) async => null;

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
  late MockCatalogGateway gateway;
  late CatalogSyncEngine syncEngine;
  late CatalogRepository repository;

  setUp(() {
    db = CatalogDatabase.inMemory();
    dao = db.catalogDao;
    gateway = MockCatalogGateway();
    syncEngine = CatalogSyncEngine(gateway: gateway, dao: dao);
    repository = CatalogRepository(
      dao: dao,
      gateway: gateway,
      syncEngine: syncEngine,
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('CatalogRepository Tests', () {
    test('1. Arranque offline con Drift poblado emite datos locales y estado offlineReady', () async {
      await dao.upsertTitle(
        LocalTitlesCompanion.insert(
          id: 'movie-local-1',
          mediaType: 'movie',
          title: 'Película Local 1',
          normalizedTitle: 'pelicula local 1',
          createdAt: DateTime.utc(2026, 9, 10, 10, 0, 0),
          updatedAt: DateTime.utc(2026, 9, 10, 10, 0, 0),
        ),
      );

      gateway.shouldFail = true; // Simular caída de Supabase

      final status = await repository.initialize();
      expect(status, equals(CatalogRepositoryStatus.offlineReady));

      final titles = await repository.getTitlesPage();
      expect(titles.length, equals(1));
      expect(titles.first.id, equals('movie-local-1'));
    });

    test('2. Arranque en frío sin red ni caché: ejecuta fallback y puebla Drift', () async {
      gateway.shouldFail = true; // Supabase caído
      // Drift está vacío

      var fallbackCalled = false;
      repository.fallbackJsonLoader = () async {
        fallbackCalled = true;
        return [
          Channel(
            name: 'Fallback Movie',
            url: 'https://hourtv.org/stream1.m3u8',
            tvgId: 'fallback-1',
            plot: 'Fallback description',
            year: '2026',
            rating: '8.0',
            servers: [
              const ChannelServer(name: 'Latino 1', url: 'https://hourtv.org/stream1.m3u8'),
            ],
          ),
        ];
      };

      final status = await repository.initialize();
      expect(fallbackCalled, isTrue);
      expect(status, equals(CatalogRepositoryStatus.offlineReady));

      // Comprobar que los datos del fallback se insertaron en Drift
      final titles = await repository.getTitlesPage();
      expect(titles.length, equals(1));
      expect(titles.first.title, equals('Fallback Movie'));

      // Y que las fuentes se guardaron
      final sources = await dao.getSourcesForTitle(titles.first.id);
      expect(sources.length, equals(1));
      expect(sources.first.url, equals('https://hourtv.org/stream1.m3u8'));
    });

    test('3. Hidratación bajo demanda de Channel y fuentes por ID', () async {
      final now = DateTime.utc(2026, 9, 10, 12, 0, 0);
      await dao.upsertTitle(
        LocalTitlesCompanion.insert(
          id: 'movie-hydrate',
          mediaType: 'movie',
          title: 'Película Hidratada',
          normalizedTitle: 'pelicula hidratada',
          plot: const Value('Sinopsis de prueba'),
          year: const Value(2026),
          rating: const Value(8.5),
          duration: const Value('120 min'),
          createdAt: now,
          updatedAt: now,
        ),
      );

      await dao.upsertSource(
        LocalSourcesCompanion.insert(
          id: 'src-1',
          titleId: const Value('movie-hydrate'),
          name: 'Opción 1 - Full HD',
          url: 'https://cdn.example.com/movie.mp4',
          language: const Value('Latino'),
        ),
      );

      final channel = await repository.hydrateChannel('movie-hydrate');
      expect(channel, isNotNull);
      expect(channel!.name, equals('Película Hidratada'));
      expect(channel.plot, equals('Sinopsis de prueba'));
      expect(channel.year, equals('2026'));
      expect(channel.servers.length, equals(1));
      expect(channel.servers.first.url, equals('https://cdn.example.com/movie.mp4'));
      expect(channel.servers.first.language, equals('Latino'));
    });

    test('4. Resolución de favoritos y continuar viendo por IDs sin cargar el catálogo completo', () async {
      await dao.upsertTitle(
        LocalTitlesCompanion.insert(
          id: 'id-fav-1',
          mediaType: 'movie',
          title: 'Favorito 1',
          normalizedTitle: 'favorito 1',
          createdAt: DateTime.utc(2026, 9, 10, 10, 0, 0),
          updatedAt: DateTime.utc(2026, 9, 10, 10, 0, 0),
        ),
      );
      await dao.upsertTitle(
        LocalTitlesCompanion.insert(
          id: 'id-fav-2',
          mediaType: 'movie',
          title: 'Favorito 2',
          normalizedTitle: 'favorito 2',
          createdAt: DateTime.utc(2026, 9, 10, 10, 0, 0),
          updatedAt: DateTime.utc(2026, 9, 10, 10, 0, 0),
        ),
      );

      final channels = await repository.resolveChannelsByIds(['id-fav-1', 'id-fav-2', 'id-no-existe']);
      expect(channels.length, equals(2));
      expect(channels.any((c) => c.tvgId == 'id-fav-1'), isTrue);
      expect(channels.any((c) => c.tvgId == 'id-fav-2'), isTrue);
    });
  });
}
