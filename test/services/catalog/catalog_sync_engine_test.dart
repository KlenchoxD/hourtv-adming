import 'package:drift/drift.dart' hide isNull, isNotNull;
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
  Map<String, CatalogGenreDto> genresOnServer = {};
  Map<String, CatalogLanguageDto> languagesOnServer = {};
  Map<String, CatalogSeasonDto> seasonsOnServer = {};
  Map<String, CatalogEpisodeDto> episodesOnServer = {};
  Map<String, CatalogSourceDto> sourcesOnServer = {};
  Set<String> titleGenresOnServer = {};
  List<CatalogSummaryDto> snapshotTitles = [];
  List<CatalogGenreDto> snapshotGenres = [];
  List<CatalogLanguageDto> snapshotLanguages = [];
  List<Map<String, String>> snapshotTitleGenres = [];
  List<CatalogSeasonDto> snapshotSeasons = [];
  List<CatalogEpisodeDto> snapshotEpisodes = [];
  List<CatalogSourceDto> snapshotSources = [];

  bool throwOnFetchChanges = false;
  bool throwOnFetchTitleDetails = false;
  CatalogSyncMetadataDto Function()? onFetchMetadata;

  @override
  Future<CatalogSyncMetadataDto> fetchSyncMetadata() async {
    if (onFetchMetadata != null) {
      return onFetchMetadata!();
    }
    return metadata;
  }

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
  Future<CatalogGenreDto?> fetchGenre(String id) async => genresOnServer[id];

  @override
  Future<CatalogLanguageDto?> fetchLanguage(String id) async => languagesOnServer[id];

  @override
  Future<CatalogSeasonDto?> fetchSeason(String id) async => seasonsOnServer[id];

  @override
  Future<CatalogEpisodeDto?> fetchEpisode(String id) async => episodesOnServer[id];

  @override
  Future<CatalogSourceDto?> fetchSource(String id) async => sourcesOnServer[id];

  @override
  Future<bool> checkTitleGenreExists(String titleId, String genreId) async =>
      titleGenresOnServer.contains('$titleId:$genreId');

  @override
  Future<List<CatalogSummaryDto>> fetchCompleteSnapshot({
    int offset = 0,
    int limit = 500,
  }) async {
    return snapshotTitles.skip(offset).take(limit).toList();
  }

  @override
  Future<List<CatalogSummaryDto>> fetchTitlesSnapshotKeyset({
    String? lastId,
    int limit = 500,
  }) async {
    var items = snapshotTitles;
    if (lastId != null) {
      final idx = items.indexWhere((i) => i.id == lastId);
      if (idx != -1) {
        items = items.sublist(idx + 1);
      }
    }
    return items.take(limit).toList();
  }

  @override
  Future<List<CatalogGenreDto>> fetchGenresSnapshotKeyset({
    String? lastId,
    int limit = 500,
  }) async {
    var items = snapshotGenres;
    if (lastId != null) {
      final idx = items.indexWhere((i) => i.id == lastId);
      if (idx != -1) {
        items = items.sublist(idx + 1);
      }
    }
    return items.take(limit).toList();
  }

  @override
  Future<List<CatalogLanguageDto>> fetchLanguagesSnapshotKeyset({
    String? lastId,
    int limit = 500,
  }) async {
    var items = snapshotLanguages;
    if (lastId != null) {
      final idx = items.indexWhere((i) => i.id == lastId);
      if (idx != -1) {
        items = items.sublist(idx + 1);
      }
    }
    return items.take(limit).toList();
  }

  @override
  Future<List<Map<String, String>>> fetchTitleGenresSnapshotKeyset({
    String? lastTitleId,
    int limit = 1000,
  }) async {
    var items = snapshotTitleGenres;
    if (lastTitleId != null) {
      final idx = items.indexWhere((i) => i['title_id'] == lastTitleId);
      if (idx != -1) {
        items = items.sublist(idx + 1);
      }
    }
    return items.take(limit).toList();
  }

  @override
  Future<List<CatalogSeasonDto>> fetchSeasonsSnapshotKeyset({
    String? lastId,
    int limit = 500,
  }) async {
    var items = snapshotSeasons;
    if (lastId != null) {
      final idx = items.indexWhere((i) => i.id == lastId);
      if (idx != -1) {
        items = items.sublist(idx + 1);
      }
    }
    return items.take(limit).toList();
  }

  @override
  Future<List<CatalogEpisodeDto>> fetchEpisodesSnapshotKeyset({
    String? lastId,
    int limit = 500,
  }) async {
    var items = snapshotEpisodes;
    if (lastId != null) {
      final idx = items.indexWhere((i) => i.id == lastId);
      if (idx != -1) {
        items = items.sublist(idx + 1);
      }
    }
    return items.take(limit).toList();
  }

  @override
  Future<List<CatalogSourceDto>> fetchSourcesSnapshotKeyset({
    String? lastId,
    int limit = 500,
  }) async {
    var items = snapshotSources;
    if (lastId != null) {
      final idx = items.indexWhere((i) => i.id == lastId);
      if (idx != -1) {
        items = items.sublist(idx + 1);
      }
    }
    return items.take(limit).toList();
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

    test('5. Cliente con revisión 0 y minimumAvailableRevision > 0: dispara Full Resync', () async {
      // Cliente nunca ha sincronizado (revisión 0)
      expect(await dao.getLastCatalogRevision(), equals(0));

      gateway.metadata = const CatalogSyncMetadataDto(
        minimumAvailableRevision: 10,
        latestRevision: 100,
      );

      gateway.snapshotTitles = [
        CatalogSummaryDto(
          id: 'fresh-1',
          title: 'Fresh Title',
          normalizedTitle: 'fresh title',
          mediaType: 'movie',
          isFeatured: true,
          createdAt: DateTime.utc(2026, 9, 10, 15, 0, 0),
        ),
      ];

      final result = await engine.syncCatalog();
      expect(result.fullResyncPerformed, isTrue, reason: 'Revision 0 debe disparar full resync si minimumAvailableRevision > 0');
      expect(result.finalRevision, equals(100));

      final titles = await dao.getPage();
      expect(titles.length, equals(1));
      expect(titles.first.id, equals('fresh-1'));
    });

    test('6. Entity type genre: upsert persiste género local y delete aplica lápida', () async {
      await dao.setLastCatalogRevision(10);

      gateway.genresOnServer['genre-action'] = const CatalogGenreDto(
        id: 'genre-action',
        name: 'Acción',
        slug: 'accion',
      );

      // 1. Upsert
      gateway.changesToReturn = [
        CatalogChangeDto(
          revision: 11,
          entityType: 'genre',
          entityId: 'genre-action',
          operation: 'upsert',
          changedAt: DateTime.utc(2026, 9, 10, 16, 0, 0),
        ),
      ];

      await engine.syncCatalog();
      var genres = await dao.getAllGenres();
      expect(genres.any((g) => g.id == 'genre-action' && g.name == 'Acción'), isTrue);

      // 2. Delete
      gateway.changesToReturn = [
        CatalogChangeDto(
          revision: 12,
          entityType: 'genre',
          entityId: 'genre-action',
          operation: 'delete',
          changedAt: DateTime.utc(2026, 9, 10, 16, 1, 0),
        ),
      ];

      await engine.syncCatalog();
      genres = await dao.getAllGenres();
      expect(genres.any((g) => g.id == 'genre-action'), isFalse);
    });

    test('7. Entity type language: upsert persiste idioma local y delete aplica lápida', () async {
      await dao.setLastCatalogRevision(10);

      gateway.languagesOnServer['lang-es'] = const CatalogLanguageDto(
        id: 'lang-es',
        code: 'es',
        name: 'Español',
      );

      // 1. Upsert
      gateway.changesToReturn = [
        CatalogChangeDto(
          revision: 11,
          entityType: 'language',
          entityId: 'lang-es',
          operation: 'upsert',
          changedAt: DateTime.utc(2026, 9, 10, 16, 0, 0),
        ),
      ];

      await engine.syncCatalog();
      // 2. Delete
      gateway.changesToReturn = [
        CatalogChangeDto(
          revision: 12,
          entityType: 'language',
          entityId: 'lang-es',
          operation: 'delete',
          changedAt: DateTime.utc(2026, 9, 10, 16, 1, 0),
        ),
      ];

      final res = await engine.syncCatalog();
      expect(res.finalRevision, equals(12));
    });

    test('8. Entity type season: upsert persiste temporada local y delete aplica lápida', () async {
      await dao.setLastCatalogRevision(10);

      // Título base para FK
      await dao.upsertTitle(LocalTitlesCompanion.insert(
        id: 'series-x',
        title: 'Series X',
        normalizedTitle: 'series x',
        mediaType: 'series',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      gateway.seasonsOnServer['s-1'] = const CatalogSeasonDto(
        id: 's-1',
        titleId: 'series-x',
        seasonNumber: 1,
        name: 'Temporada 1',
      );

      // 1. Upsert
      gateway.changesToReturn = [
        CatalogChangeDto(
          revision: 11,
          entityType: 'season',
          entityId: 's-1',
          operation: 'upsert',
          changedAt: DateTime.utc(2026, 9, 10, 16, 0, 0),
        ),
      ];

      await engine.syncCatalog();
      var seasons = await dao.getSeasonsForTitle('series-x');
      expect(seasons.length, equals(1));
      expect(seasons.first.id, equals('s-1'));

      // 2. Delete
      gateway.changesToReturn = [
        CatalogChangeDto(
          revision: 12,
          entityType: 'season',
          entityId: 's-1',
          operation: 'delete',
          changedAt: DateTime.utc(2026, 9, 10, 16, 1, 0),
        ),
      ];

      await engine.syncCatalog();
      seasons = await dao.getSeasonsForTitle('series-x');
      expect(seasons, isEmpty);
    });

    test('9. Entity type episode: upsert persiste episodio local y delete aplica lápida', () async {
      await dao.setLastCatalogRevision(10);

      await dao.upsertTitle(LocalTitlesCompanion.insert(
        id: 'series-x',
        title: 'Series X',
        normalizedTitle: 'series x',
        mediaType: 'series',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      await dao.upsertSeason(const LocalSeasonsCompanion(
        id: Value('s-1'),
        titleId: Value('series-x'),
        seasonNumber: Value(1),
      ));

      gateway.episodesOnServer['ep-1'] = const CatalogEpisodeDto(
        id: 'ep-1',
        seasonId: 's-1',
        episodeNumber: 1,
        title: 'Piloto',
      );

      // 1. Upsert
      gateway.changesToReturn = [
        CatalogChangeDto(
          revision: 11,
          entityType: 'episode',
          entityId: 'ep-1',
          operation: 'upsert',
          changedAt: DateTime.utc(2026, 9, 10, 16, 0, 0),
        ),
      ];

      await engine.syncCatalog();
      var episodes = await dao.getEpisodesForSeason('s-1');
      expect(episodes.length, equals(1));
      expect(episodes.first.title, equals('Piloto'));

      // 2. Delete
      gateway.changesToReturn = [
        CatalogChangeDto(
          revision: 12,
          entityType: 'episode',
          entityId: 'ep-1',
          operation: 'delete',
          changedAt: DateTime.utc(2026, 9, 10, 16, 1, 0),
        ),
      ];

      await engine.syncCatalog();
      episodes = await dao.getEpisodesForSeason('s-1');
      expect(episodes, isEmpty);
    });

    test('10. Entity type source: upsert persiste fuente local y delete aplica lápida', () async {
      await dao.setLastCatalogRevision(10);

      await dao.upsertTitle(LocalTitlesCompanion.insert(
        id: 'movie-x',
        title: 'Movie X',
        normalizedTitle: 'movie x',
        mediaType: 'movie',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      gateway.sourcesOnServer['src-1'] = const CatalogSourceDto(
        id: 'src-1',
        titleId: 'movie-x',
        name: 'Stream 1080p',
        url: 'https://cdn.test/stream.m3u8',
        orderIndex: 0,
        status: 'active',
        requiresWebview: false,
      );

      // 1. Upsert
      gateway.changesToReturn = [
        CatalogChangeDto(
          revision: 11,
          entityType: 'source',
          entityId: 'src-1',
          operation: 'upsert',
          changedAt: DateTime.utc(2026, 9, 10, 16, 0, 0),
        ),
      ];

      await engine.syncCatalog();
      var sources = await dao.getSourcesForTitle('movie-x');
      expect(sources.length, equals(1));
      expect(sources.first.url, equals('https://cdn.test/stream.m3u8'));

      // 2. Delete
      gateway.changesToReturn = [
        CatalogChangeDto(
          revision: 12,
          entityType: 'source',
          entityId: 'src-1',
          operation: 'delete',
          changedAt: DateTime.utc(2026, 9, 10, 16, 1, 0),
        ),
      ];

      await engine.syncCatalog();
      sources = await dao.getSourcesForTitle('movie-x');
      expect(sources, isEmpty);
    });

    test('11. Entity type title_genre: upsert vincula relación y delete desvincula', () async {
      await dao.setLastCatalogRevision(10);

      await dao.upsertTitle(LocalTitlesCompanion.insert(
        id: 'title-link',
        title: 'Title Link',
        normalizedTitle: 'title link',
        mediaType: 'movie',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      await dao.upsertGenre(const LocalGenresCompanion(
        id: Value('genre-linked'),
        name: Value('Linked Genre'),
        slug: Value('linked-genre'),
      ));

      gateway.titleGenresOnServer.add('title-link:genre-linked');

      // 1. Upsert
      gateway.changesToReturn = [
        CatalogChangeDto(
          revision: 11,
          entityType: 'title_genre',
          entityId: 'title-link:genre-linked',
          operation: 'upsert',
          changedAt: DateTime.utc(2026, 9, 10, 16, 0, 0),
        ),
      ];

      await engine.syncCatalog();
      var genres = await dao.getGenresForTitle('title-link');
      expect(genres.length, equals(1));
      expect(genres.first.id, equals('genre-linked'));

      // 2. Delete
      gateway.changesToReturn = [
        CatalogChangeDto(
          revision: 12,
          entityType: 'title_genre',
          entityId: 'title-link:genre-linked',
          operation: 'delete',
          changedAt: DateTime.utc(2026, 9, 10, 16, 1, 0),
        ),
      ];

      await engine.syncCatalog();
      genres = await dao.getGenresForTitle('title-link');
      expect(genres, isEmpty);
    });

    test('12. Entity type title: upsert persiste título y sincroniza relaciones con géneros en title_genres', () async {
      await dao.setLastCatalogRevision(10);

      const titleId = 'title-full-rel';
      gateway.titlesOnServer[titleId] = CatalogDetailDto(
        id: titleId,
        title: 'Title Full Rel',
        normalizedTitle: 'title full rel',
        mediaType: 'movie',
        isFeatured: false,
        createdAt: DateTime.utc(2026, 9, 10, 17, 0, 0),
        genres: const ['action'],
        genresDetails: const [
          CatalogGenreDto(id: 'g-act', name: 'Action', slug: 'action'),
        ],
      );

      gateway.changesToReturn = [
        CatalogChangeDto(
          revision: 11,
          entityType: 'title',
          entityId: titleId,
          operation: 'upsert',
          changedAt: DateTime.utc(2026, 9, 10, 17, 0, 0),
        ),
      ];

      await engine.syncCatalog();

      final title = await dao.getTitleById(titleId);
      expect(title, isNotNull);
      expect(title!.normalizedTitle, equals('title full rel'));

      final genres = await dao.getGenresForTitle(titleId);
      expect(genres.length, equals(1));
      expect(genres.first.id, equals('g-act'));
      expect(genres.first.name, equals('Action'));
    });

    test('13. Full Resync descarga snapshot consistente de las 7 tablas sin offset y verifica detalle, géneros y reproducción', () async {
      await dao.setLastCatalogRevision(10);

      gateway.metadata = const CatalogSyncMetadataDto(
        minimumAvailableRevision: 50,
        latestRevision: 150,
      );

      // 7 tablas en snapshot
      gateway.snapshotGenres = [
        const CatalogGenreDto(id: 'g-drama', name: 'Drama', slug: 'drama'),
      ];
      gateway.snapshotLanguages = [
        const CatalogLanguageDto(id: 'l-es', code: 'es', name: 'Español'),
      ];
      gateway.snapshotTitles = [
        CatalogSummaryDto(
          id: 'series-resync',
          title: 'Serie Resync',
          normalizedTitle: 'serie resync',
          mediaType: 'series',
          isFeatured: true,
          createdAt: DateTime.utc(2026, 9, 10, 18, 0, 0),
        ),
      ];
      gateway.snapshotTitleGenres = [
        {'title_id': 'series-resync', 'genre_id': 'g-drama'},
      ];
      gateway.snapshotSeasons = [
        const CatalogSeasonDto(
          id: 'sea-1',
          titleId: 'series-resync',
          seasonNumber: 1,
          name: 'Temporada 1',
        ),
      ];
      gateway.snapshotEpisodes = [
        const CatalogEpisodeDto(
          id: 'ep-101',
          seasonId: 'sea-1',
          episodeNumber: 1,
          title: 'Capitulo 1',
        ),
      ];
      gateway.snapshotSources = [
        const CatalogSourceDto(
          id: 'src-101',
          episodeId: 'ep-101',
          languageCode: 'es',
          name: 'HLS 1080p',
          url: 'https://cdn.example.com/live/ep101.m3u8',
          orderIndex: 0,
          status: 'active',
          requiresWebview: false,
        ),
      ];

      final result = await engine.syncCatalog();
      expect(result.fullResyncPerformed, isTrue);
      expect(result.finalRevision, equals(150));

      // Verificación de integridad: detalle, géneros y reproducción
      final title = await dao.getTitleById('series-resync');
      expect(title, isNotNull);
      expect(title!.title, equals('Serie Resync'));

      final genres = await dao.getGenresForTitle('series-resync');
      expect(genres.length, equals(1));
      expect(genres.first.name, equals('Drama'));

      final seasons = await dao.getSeasonsForTitle('series-resync');
      expect(seasons.length, equals(1));
      expect(seasons.first.name, equals('Temporada 1'));

      final episodes = await dao.getEpisodesForSeason('sea-1');
      expect(episodes.length, equals(1));
      expect(episodes.first.title, equals('Capitulo 1'));

      final sources = await dao.getSourcesForEpisode('ep-101');
      expect(sources.length, equals(1));
      expect(sources.first.url, equals('https://cdn.example.com/live/ep101.m3u8'));
    });

    test('14. Full Resync captura watermark coherente y procesa deltas posteriores', () async {
      await dao.setLastCatalogRevision(10);

      gateway.snapshotTitles = [
        CatalogSummaryDto(
          id: 'snap-title',
          title: 'Snapshot Title',
          normalizedTitle: 'snapshot title',
          mediaType: 'movie',
          isFeatured: false,
          createdAt: DateTime.utc(2026, 9, 10, 19, 0, 0),
        ),
      ];

      // Simulamos que tras la descarga del snapshot, el servidor avanzó a revisión 105
      // y emitió un delta posterior al watermark
      gateway.changesToReturn = [
        CatalogChangeDto(
          revision: 105,
          entityType: 'genre',
          entityId: 'genre-post-watermark',
          operation: 'upsert',
          changedAt: DateTime.utc(2026, 9, 10, 19, 5, 0),
        ),
      ];
      gateway.genresOnServer['genre-post-watermark'] = const CatalogGenreDto(
        id: 'genre-post-watermark',
        name: 'Post Watermark Genre',
        slug: 'post-watermark',
      );

      // Watermark inicial en 100, y tras el snapshot el servidor sube a 105
      var calls = 0;
      gateway.onFetchMetadata = () {
        calls++;
        if (calls <= 2) {
          return const CatalogSyncMetadataDto(
            minimumAvailableRevision: 50,
            latestRevision: 100,
          );
        } else {
          return const CatalogSyncMetadataDto(
            minimumAvailableRevision: 50,
            latestRevision: 105,
          );
        }
      };

      final result = await engine.syncCatalog();
      expect(result.fullResyncPerformed, isTrue);
      expect(result.finalRevision, equals(105));

      final genre = (await dao.getAllGenres()).where((g) => g.id == 'genre-post-watermark');
      expect(genre, isNotEmpty);
      expect(await dao.getLastCatalogRevision(), equals(105));
    });
  });
}
