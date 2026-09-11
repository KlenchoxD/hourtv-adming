import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../../database/catalog_database.dart';
import '../../database/daos/catalog_dao.dart';
import '../../models/channel.dart';
import '../../services/catalog_parser.dart';
import '../../services/xtream_service.dart';
import 'catalog_sync_engine.dart';
import 'supabase_catalog_gateway.dart';
import 'sync_models.dart';

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
class CatalogRepository extends ChangeNotifier {
  static CatalogRepository? _instance;
  static CatalogRepository get instance {
    if (_instance == null) {
      throw StateError('CatalogRepository.instance no está inicializado.');
    }
    return _instance!;
  }
  static bool get hasInstance => _instance != null;
  static void configureInstance(CatalogRepository repo) {
    _instance = repo;
  }

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
      catalogTitleId: t.id,
    );
  }

  final CatalogDao dao;
  final SupabaseCatalogGateway? gateway;
  final CatalogSyncEngine? syncEngine;
  Future<List<Channel>> Function()? fallbackJsonLoader;
  Future<CatalogPayload> Function()? fallbackPayloadLoader;

  CatalogRepositoryStatus _status = CatalogRepositoryStatus.idle;
  CatalogRepositoryStatus get status => _status;

  CatalogRepository({
    required this.dao,
    this.gateway,
    this.syncEngine,
    this.fallbackJsonLoader,
    this.fallbackPayloadLoader,
  }) {
    _instance ??= this;
  }

  bool get isReady =>
      _status == CatalogRepositoryStatus.ready ||
      _status == CatalogRepositoryStatus.offlineReady;

  @visibleForTesting
  void setStatusForTesting(CatalogRepositoryStatus newStatus) {
    _status = newStatus;
    notifyListeners();
  }

  /// Inicializa el repositorio siguiendo la jerarquía de fallback:
  /// 1. Drift Local: si hay datos, emite offlineReady de inmediato y revalida de fondo si hay syncEngine.
  /// 2. Supabase Remoto: si local está vacío y hay syncEngine disponible, sincroniza.
  /// 3. Respaldo Temporal JSON / sources.json: si Supabase falla o no está configurado y local está vacío.
  Future<CatalogRepositoryStatus> initialize() async {
    final localTitles = await dao.getPage(limit: 1);
    final hasLocalData = localTitles.isNotEmpty;

    if (hasLocalData) {
      _status = CatalogRepositoryStatus.offlineReady;
      notifyListeners();
      if (syncEngine != null) {
        unawaited(_triggerBackgroundSync());
      }
      return _status;
    }

    // 2. Si la base local está completamente vacía y hay syncEngine disponible, intentar sincronizar con Supabase
    if (syncEngine != null) {
      try {
        _status = CatalogRepositoryStatus.syncing;
        notifyListeners();
        final syncResult = await syncEngine!.syncCatalog(
          onBatchApplied: (_) => notifyListeners(),
        );
        if (syncResult.hasChanges || (await dao.getPage(limit: 1)).isNotEmpty) {
          _status = CatalogRepositoryStatus.ready;
          notifyListeners();
          return _status;
        }
      } catch (_) {
        // Supabase caído o sin conectividad
      }
    }

    // 3. Fallback de emergencia a JSON/Payload si continúa vacía
    if (fallbackPayloadLoader != null) {
      try {
        final payload = await fallbackPayloadLoader!();
        if (payload.channels.isNotEmpty || payload.series.isNotEmpty) {
          await populateFromPayload(payload);
          _status = CatalogRepositoryStatus.offlineReady;
          notifyListeners();
          return _status;
        }
      } catch (_) {}
    } else if (fallbackJsonLoader != null) {
      try {
        final fallbackChannels = await fallbackJsonLoader!();
        if (fallbackChannels.isNotEmpty) {
          await _populateFromFallback(fallbackChannels);
          _status = CatalogRepositoryStatus.offlineReady;
          notifyListeners();
          return _status;
        }
      } catch (_) {}
    }

    _status = hasLocalData ? CatalogRepositoryStatus.offlineReady : CatalogRepositoryStatus.failed;
    notifyListeners();
    return _status;
  }

  /// Ejecuta un ciclo de sincronización explícito notificando observadores.
  Future<SyncResult> sync() async {
    if (syncEngine == null) {
      final hasLocal = (await dao.getPage(limit: 1)).isNotEmpty;
      _status = hasLocal ? CatalogRepositoryStatus.offlineReady : CatalogRepositoryStatus.idle;
      notifyListeners();
      return const SyncResult(initialRevision: 0, finalRevision: 0, appliedChangesCount: 0);
    }
    _status = CatalogRepositoryStatus.syncing;
    notifyListeners();
    try {
      final result = await syncEngine!.syncCatalog(
        onBatchApplied: (_) => notifyListeners(),
      );
      final hasLocal = (await dao.getPage(limit: 1)).isNotEmpty;
      _status = hasLocal ? CatalogRepositoryStatus.ready : CatalogRepositoryStatus.offlineReady;
      notifyListeners();
      return result;
    } catch (e) {
      final hasLocal = (await dao.getPage(limit: 1)).isNotEmpty;
      _status = hasLocal ? CatalogRepositoryStatus.offlineReady : CatalogRepositoryStatus.failed;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> _triggerBackgroundSync() async {
    if (syncEngine == null) return;
    try {
      final syncResult = await syncEngine!.syncCatalog(
        onBatchApplied: (_) => notifyListeners(),
      );
      if (syncResult.hasChanges) {
        _status = CatalogRepositoryStatus.ready;
        notifyListeners();
      }
    } catch (_) {
      // En background no bloquea la navegación local
    }
  }

  /// Carga el archivo sources.json desde el sistema de archivos o desde el bundle de assets.
  static Future<CatalogPayload> loadAssetSources({String path = 'assets/data/sources.json'}) async {
    String? raw;
    try {
      final file = File(path);
      if (file.existsSync()) {
        raw = await file.readAsString();
      }
    } catch (_) {}
    if (raw == null) {
      try {
        raw = await rootBundle.loadString(path);
      } catch (_) {}
    }
    if (raw == null) return const CatalogPayload();
    return CatalogParser.parse(jsonDecode(raw));
  }

  /// Puebla la base de datos Drift a partir de un CatalogPayload completo (películas + series + temporadas + episodios + fuentes).
  Future<void> populateFromPayload(CatalogPayload payload) async {
    await dao.transaction(() async {
      final now = DateTime.now();

      // 1. Películas y sus fuentes
      for (final ch in payload.channels) {
        if (ch.forcedType != 'movie' && !ch.url.endsWith('.mp4') && !ch.url.endsWith('.mkv')) {
          continue;
        }
        final titleId = ch.tvgId?.isNotEmpty == true ? ch.tvgId! : ch.name;
        await dao.upsertTitle(
          LocalTitlesCompanion.insert(
            id: titleId,
            mediaType: 'movie',
            title: ch.name,
            normalizedTitle: ch.name.toLowerCase().trim(),
            plot: Value(ch.plot),
            year: Value(int.tryParse(ch.year ?? '')),
            rating: Value(double.tryParse(ch.rating ?? '')),
            duration: Value(ch.duration),
            castMembers: Value(ch.cast),
            director: Value(ch.director),
            writer: Value(ch.writer),
            posterUrl: Value(ch.logo),
            backdropUrl: Value(ch.backdrop),
            isFeatured: Value(ch.isFeatured),
            createdAt: now,
            updatedAt: now,
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

      // 2. Series, Temporadas, Episodios y Fuentes
      for (final s in payload.series) {
        final seriesId = s.seriesId.isNotEmpty ? s.seriesId : s.name;
        await dao.upsertTitle(
          LocalTitlesCompanion.insert(
            id: seriesId,
            mediaType: 'series',
            title: s.name,
            normalizedTitle: s.name.toLowerCase().trim(),
            plot: Value(s.plot),
            year: Value(int.tryParse(s.year ?? '')),
            rating: Value(double.tryParse(s.rating ?? '')),
            duration: Value(s.duration),
            castMembers: Value(s.cast),
            director: Value(s.director),
            writer: Value(s.writer),
            posterUrl: Value(s.cover),
            backdropUrl: Value(s.backdrop),
            isFeatured: Value(s.isFeatured),
            createdAt: now,
            updatedAt: now,
          ),
        );

        final seasonMap = <int, List<Channel>>{};
        for (final ep in s.episodes ?? const <Channel>[]) {
          int seasonNum = 1;
          if (ep.group != null && ep.group!.isNotEmpty) {
            final match = RegExp(r'(\d+)').firstMatch(ep.group!);
            if (match != null) {
              seasonNum = int.tryParse(match.group(1)!) ?? 1;
            }
          }
          seasonMap.putIfAbsent(seasonNum, () => []).add(ep);
        }

        for (final entry in seasonMap.entries) {
          final seasonNumber = entry.key;
          final seasonId = '${seriesId}_s$seasonNumber';
          await dao.upsertSeason(
            LocalSeasonsCompanion.insert(
              id: seasonId,
              titleId: seriesId,
              seasonNumber: seasonNumber,
              name: Value('Temporada $seasonNumber'),
              plot: Value(s.plot),
              posterUrl: Value(s.cover),
            ),
          );

          var epIndex = 1;
          for (final ep in entry.value) {
            final epNumMatch = RegExp(r'(\d+)').firstMatch(ep.name);
            final episodeNumber = epNumMatch != null ? int.tryParse(epNumMatch.group(1)!) ?? epIndex : epIndex;
            final episodeId = '${seasonId}_ep$episodeNumber';

            await dao.upsertEpisode(
              LocalEpisodesCompanion.insert(
                id: episodeId,
                seasonId: seasonId,
                episodeNumber: episodeNumber,
                title: ep.name,
                plot: Value(ep.plot),
                duration: Value(ep.duration),
                stillUrl: Value(ep.logo ?? s.cover),
              ),
            );

            if (ep.servers.isNotEmpty) {
              var sOrder = 0;
              for (final server in ep.servers) {
                await dao.upsertSource(
                  LocalSourcesCompanion.insert(
                    id: '${episodeId}_server_$sOrder',
                    episodeId: Value(episodeId),
                    name: server.name,
                    url: server.url,
                    language: Value(server.language),
                    orderIndex: Value(sOrder++),
                  ),
                );
              }
            } else if (ep.url.isNotEmpty) {
              await dao.upsertSource(
                LocalSourcesCompanion.insert(
                  id: '${episodeId}_default',
                  episodeId: Value(episodeId),
                  name: 'Predeterminado',
                  url: ep.url,
                ),
              );
            }
            epIndex++;
          }
        }
      }
    });
    notifyListeners();
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
    notifyListeners();
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
      catalogTitleId: title.id,
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
            tvgId: 'S${s.seasonNumber}:E${ep.episodeNumber}',
            catalogTitleId: ep.id,
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
