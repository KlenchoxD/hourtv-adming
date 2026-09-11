import 'dart:async';
import 'package:drift/drift.dart';
import '../../database/catalog_database.dart';
import '../../database/daos/catalog_dao.dart';
import '../../models/channel.dart';
import '../../services/xtream_service.dart';
import 'catalog_sync_engine.dart';
import 'supabase_catalog_gateway.dart';

/// Estado de disponibilidad del repositorio de catálogo.
enum CatalogRepositoryStatus {
  idle,
  syncing,
  ready,
  offlineReady,
  failed,
}

/// Repositorio resiliente que orquesta la caché local Drift, la sincronización
/// incremental con Supabase y el respaldo de emergencia a JSON.
class CatalogRepository {
  static CatalogRepository? _instance;
  static CatalogRepository get instance {
    if (_instance == null) {
      throw StateError('CatalogRepository.instance no está inicializado.');
    }
    return _instance!;
  }
  static bool get hasInstance => _instance != null;
  static void setInstanceForTesting(CatalogRepository? repo) {
    _instance = repo;
  }

  static Channel titleToChannel(LocalTitle t) {
    return Channel(
      name: t.title,
      url: 'catalog://${t.id}',
      logo: t.posterUrl,
      backdrop: t.backdropUrl,
      tvgId: t.id,
      plot: t.plot,
      year: t.year?.toString(),
      rating: t.rating?.toString(),
      duration: t.duration,
      cast: t.castMembers,
      director: t.director,
      writer: t.writer,
      forcedType: t.mediaType,
    );
  }

  final CatalogDao dao;
  final SupabaseCatalogGateway gateway;
  final CatalogSyncEngine syncEngine;
  Future<List<Channel>> Function()? fallbackJsonLoader;

  CatalogRepositoryStatus _status = CatalogRepositoryStatus.idle;
  CatalogRepositoryStatus get status => _status;

  CatalogRepository({
    required this.dao,
    required this.gateway,
    required this.syncEngine,
    this.fallbackJsonLoader,
  }) {
    _instance ??= this;
  }

  /// Inicializa el repositorio siguiendo la jerarquía de fallback:
  /// 1. Drift Local: si hay datos, emite offlineReady de inmediato y revalida de fondo.
  /// 2. Supabase Remoto: si local está vacío, sincroniza.
  /// 3. Respaldo Temporal JSON: si Supabase falla y local está vacío, puebla Drift desde fallbackJsonLoader.
  Future<CatalogRepositoryStatus> initialize() async {
    final localTitles = await dao.getPage(limit: 1);
    final hasLocalData = localTitles.isNotEmpty;

    if (hasLocalData) {
      _status = CatalogRepositoryStatus.offlineReady;
      unawaited(_triggerBackgroundSync());
      return _status;
    }

    // 2. Si la base local está completamente vacía, intentar sincronizar con Supabase
    try {
      _status = CatalogRepositoryStatus.syncing;
      final syncResult = await syncEngine.syncCatalog();
      if (syncResult.hasChanges || (await dao.getPage(limit: 1)).isNotEmpty) {
        _status = CatalogRepositoryStatus.ready;
        return _status;
      }
    } catch (_) {
      // Supabase caído o sin conectividad
    }

    // 3. Fallback de emergencia a JSON si continúa vacía
    if (fallbackJsonLoader != null) {
      try {
        final fallbackChannels = await fallbackJsonLoader!();
        if (fallbackChannels.isNotEmpty) {
          await _populateFromFallback(fallbackChannels);
          _status = CatalogRepositoryStatus.offlineReady;
          return _status;
        }
      } catch (_) {}
    }

    _status = hasLocalData ? CatalogRepositoryStatus.offlineReady : CatalogRepositoryStatus.failed;
    return _status;
  }

  Future<void> _triggerBackgroundSync() async {
    try {
      await syncEngine.syncCatalog();
    } catch (_) {
      // En background no bloquea la navegación local
    }
  }

  Future<void> _populateFromFallback(List<Channel> channels) async {
    await dao.transaction(() async {
      for (final ch in channels) {
        final titleId = ch.tvgId?.isNotEmpty == true ? ch.tvgId! : ch.name;
        final isMovie = ch.forcedType == 'movie' || ch.url.endsWith('.mp4') || ch.url.endsWith('.mkv');
        final mediaType = isMovie ? 'movie' : 'series';

        await dao.upsertTitle(
          LocalTitlesCompanion.insert(
            id: titleId,
            mediaType: mediaType,
            title: ch.name,
            normalizedTitle: ch.name.toLowerCase().trim(),
            plot: Value(ch.plot),
            year: Value(int.tryParse(ch.year ?? '')),
            rating: Value(double.tryParse(ch.rating ?? '')),
            posterUrl: Value(ch.logo),
            backdropUrl: Value(ch.backdrop),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

        if (ch.servers.isNotEmpty) {
          var order = 0;
          for (final server in ch.servers) {
            await dao.upsertSource(
              LocalSourcesCompanion.insert(
                id: '${titleId}_server_$order',
                titleId: Value(titleId),
                name: server.name,
                url: server.url,
                language: Value(server.language),
                orderIndex: Value(order++),
              ),
            );
          }
        } else if (ch.url.isNotEmpty) {
          await dao.upsertSource(
            LocalSourcesCompanion.insert(
              id: '${titleId}_default',
              titleId: Value(titleId),
              name: 'Predeterminado',
              url: ch.url,
            ),
          );
        }
      }
    });
  }

  Future<List<LocalTitle>> getTitlesPage({
    int limit = 20,
    DateTime? cursorCreatedAt,
    String? cursorId,
    String? mediaType,
    String? genreSlug,
  }) {
    return dao.getPage(
      limit: limit,
      cursorCreatedAt: cursorCreatedAt,
      cursorId: cursorId,
      mediaType: mediaType,
      genreSlug: genreSlug,
    );
  }

  Future<List<LocalTitle>> getTitlesByIds(List<String> ids) => dao.getTitlesByIds(ids);

  Future<List<LocalTitle>> searchTitles({required String query, int limit = 20}) =>
      dao.searchTitlesFts(rawQuery: query, limit: limit);

  /// Hidrata un Channel completo a partir de Drift para la vista de detalle y el reproductor actual.
  Future<Channel?> hydrateChannel(String titleId) async {
    final title = await dao.getTitleById(titleId);
    if (title == null) return null;

    final sources = await dao.getSourcesForTitle(titleId);
    final servers = sources
        .map((s) => ChannelServer(name: s.name, url: s.url, language: s.language))
        .toList();

    return Channel(
      name: title.title,
      url: servers.isNotEmpty ? servers.first.url : '',
      logo: title.posterUrl,
      backdrop: title.backdropUrl,
      tvgId: title.id,
      plot: title.plot,
      year: title.year?.toString(),
      rating: title.rating?.toString(),
      duration: title.duration,
      cast: title.castMembers,
      director: title.director,
      writer: title.writer,
      servers: servers,
      forcedType: title.mediaType,
    );
  }

  /// Hidrata un XtreamSeries con temporadas y episodios bajo demanda.
  Future<XtreamSeries?> hydrateSeries(String titleId) async {
    final title = await dao.getTitleById(titleId);
    if (title == null) return null;

    final seasons = await dao.getSeasonsForTitle(titleId);
    final episodeChannels = <Channel>[];

    for (final s in seasons) {
      final episodes = await dao.getEpisodesForSeason(s.id);
      for (final ep in episodes) {
        final epSources = await dao.getSourcesForEpisode(ep.id);
        final servers = epSources
            .map((src) => ChannelServer(name: src.name, url: src.url, language: src.language))
            .toList();

        episodeChannels.add(
          Channel(
            name: ep.title,
            url: servers.isNotEmpty ? servers.first.url : '',
            logo: ep.stillUrl ?? s.posterUrl ?? title.posterUrl,
            plot: ep.plot ?? s.plot,
            duration: ep.duration,
            servers: servers,
            forcedType: 'series',
            group: s.name ?? 'Temporada ${s.seasonNumber}',
          ),
        );
      }
    }

    return XtreamSeries(
      seriesId: title.id,
      name: title.title,
      cover: title.posterUrl,
      backdrop: title.backdropUrl,
      plot: title.plot,
      host: '',
      username: '',
      password: '',
      year: title.year?.toString(),
      rating: title.rating?.toString(),
      duration: title.duration,
      cast: title.castMembers,
      director: title.director,
      writer: title.writer,
      episodes: episodeChannels,
      isFeatured: title.isFeatured,
    );
  }

  /// Resuelve una lista de canales a partir de sus IDs (para favoritos y continuar viendo)
  Future<List<Channel>> resolveChannelsByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    final titles = await dao.getTitlesByIds(ids);
    final results = <Channel>[];

    for (final t in titles) {
      final ch = await hydrateChannel(t.id);
      if (ch != null) {
        results.add(ch);
      }
    }

    return results;
  }
}
