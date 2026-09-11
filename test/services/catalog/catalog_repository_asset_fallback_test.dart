import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamtv/database/catalog_database.dart';
import 'package:streamtv/database/daos/catalog_dao.dart';
import 'package:streamtv/services/catalog/catalog_cursor.dart';
import 'package:streamtv/services/catalog/catalog_dtos.dart';
import 'package:streamtv/services/catalog/catalog_repository.dart';
import 'package:streamtv/services/catalog/catalog_sync_engine.dart';
import 'package:streamtv/services/catalog/supabase_catalog_gateway.dart';

class FailingMockGateway extends SupabaseCatalogGateway {
  @override
  Future<CatalogSyncMetadataDto> fetchSyncMetadata() async {
    throw const CatalogNetworkException('Supabase offline');
  }

  @override
  Future<List<CatalogChangeDto>> fetchChanges({required int sinceRevision, int limit = 200}) async => [];

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
  late FailingMockGateway gateway;
  late CatalogSyncEngine syncEngine;
  late CatalogRepository repository;

  setUp(() {
    db = CatalogDatabase.inMemory();
    dao = db.catalogDao;
    gateway = FailingMockGateway();
    syncEngine = CatalogSyncEngine(gateway: gateway, dao: dao);
    repository = CatalogRepository(
      dao: dao,
      gateway: gateway,
      syncEngine: syncEngine,
      fallbackPayloadLoader: () => CatalogRepository.loadAssetSources(),
    );
    CatalogRepository.setInstanceForTesting(repository);
  });

  tearDown(() async {
    CatalogRepository.setInstanceForTesting(null);
    await db.close();
  });

  group('CatalogRepository Real Asset Fallback (sources.json)', () {
    test('1. Carga real de sources.json puebla películas, series, temporadas, episodios y fuentes funcionales', () async {
      // Base de datos inicialmente vacía
      final initialTitles = await dao.getPage(limit: 10);
      expect(initialTitles, isEmpty);

      // Inicializar con Supabase caído -> debe activar el fallback real
      final status = await repository.initialize();
      expect(status, equals(CatalogRepositoryStatus.offlineReady));

      // 1. Total de títulos > 0
      final allTitles = await dao.getPage(limit: 500);
      expect(allTitles.length, greaterThan(200), reason: 'Debe cargar películas y series del JSON real');

      final movies = allTitles.where((t) => t.mediaType == 'movie').toList();
      final series = allTitles.where((t) => t.mediaType == 'series').toList();
      expect(movies.isNotEmpty, isTrue, reason: 'Debe haber películas');
      expect(series.isNotEmpty, isTrue, reason: 'Debe haber series');

      // 2. Comprobar fuentes de película
      final sampleMovie = movies.first;
      final movieSources = await dao.getSourcesForTitle(sampleMovie.id);
      expect(movieSources.isNotEmpty, isTrue);
      expect(movieSources.first.url, startsWith('http'));

      // 3. Comprobar temporadas y episodios con fuentes en series
      final sampleSeries = series.first;
      final seasons = await dao.getSeasonsForTitle(sampleSeries.id);
      expect(seasons.isNotEmpty, isTrue, reason: 'La serie debe tener al menos una temporada');
      expect(seasons.first.seasonNumber, greaterThanOrEqualTo(1));

      final episodes = await dao.getEpisodesForSeason(seasons.first.id);
      expect(episodes.isNotEmpty, isTrue, reason: 'La temporada debe tener episodios');
      expect(episodes.first.episodeNumber, greaterThanOrEqualTo(1));

      final episodeSources = await dao.getSourcesForEpisode(episodes.first.id);
      expect(episodeSources.isNotEmpty, isTrue, reason: 'El episodio debe tener fuentes de reproducción');
      expect(episodeSources.first.url, startsWith('http'));

      // 4. Hidratación completa de la serie
      final hydrated = await repository.hydrateSeries(sampleSeries.id);
      expect(hydrated, isNotNull);
      expect(hydrated!.seriesId, equals(sampleSeries.id));
      expect(hydrated.episodes, isNotNull);
      expect(hydrated.episodes!.isNotEmpty, isTrue);
      expect(hydrated.episodes!.first.servers.isNotEmpty, isTrue);
      expect(hydrated.episodes!.first.servers.first.url, startsWith('http'));
    });

    test('2. Segunda ejecución de populateFromPayload es idempotente (0 duplicados)', () async {
      final payload = await CatalogRepository.loadAssetSources();
      expect(payload.channels.isNotEmpty || payload.series.isNotEmpty, isTrue);

      // Primera inserción
      await repository.populateFromPayload(payload);
      final countTitles1 = (await dao.getPage(limit: 1000)).length;
      final seriesList1 = (await dao.getPage(limit: 1000, mediaType: 'series'));
      final sampleSeriesId = seriesList1.first.id;
      final seasons1 = await dao.getSeasonsForTitle(sampleSeriesId);
      final episodes1 = await dao.getEpisodesForSeason(seasons1.first.id);
      final epSources1 = await dao.getSourcesForEpisode(episodes1.first.id);

      // Segunda inserción idéntica
      await repository.populateFromPayload(payload);
      final countTitles2 = (await dao.getPage(limit: 1000)).length;
      final seasons2 = await dao.getSeasonsForTitle(sampleSeriesId);
      final episodes2 = await dao.getEpisodesForSeason(seasons1.first.id);
      final epSources2 = await dao.getSourcesForEpisode(episodes1.first.id);

      // Verificación estricta de 0 duplicados
      expect(countTitles2, equals(countTitles1), reason: 'No deben duplicarse títulos');
      expect(seasons2.length, equals(seasons1.length), reason: 'No deben duplicarse temporadas');
      expect(episodes2.length, equals(episodes1.length), reason: 'No deben duplicarse episodios');
      expect(epSources2.length, equals(epSources1.length), reason: 'No deben duplicarse fuentes');
    });
  });
}
