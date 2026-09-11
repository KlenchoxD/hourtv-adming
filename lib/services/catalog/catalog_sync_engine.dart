import 'package:drift/drift.dart';
import '../../database/catalog_database.dart';
import '../../database/daos/catalog_dao.dart';
import 'catalog_dtos.dart';
import 'supabase_catalog_gateway.dart';
import 'sync_models.dart';

/// Motor de sincronización incremental del catálogo de HourTV.
/// Implementa verificación de retención (compactación en servidor),
/// actualización por deltas con transacciones atómicas de lote y
/// resincronización completa automática sin tocar favoritos ni progreso.
class CatalogSyncEngine {
  final SupabaseCatalogGateway gateway;
  final CatalogDao dao;

  CatalogSyncEngine({
    required this.gateway,
    required this.dao,
  });

  /// Ejecuta un ciclo de sincronización completo o incremental.
  Future<SyncResult> syncCatalog({int batchSize = 200}) async {
    final metadata = await gateway.fetchSyncMetadata();
    final localRev = await dao.getLastCatalogRevision();

    // 1. Verificación de compactación y retención
    if (localRev < metadata.minimumAvailableRevision) {
      return await _performFullResync(
        initialRev: localRev,
        targetRevision: metadata.latestRevision,
      );
    }

    // 2. Sincronización incremental por lotes
    var currentRev = localRev;
    var totalApplied = 0;

    while (true) {
      final changes = await gateway.fetchChanges(
        sinceRevision: currentRev,
        limit: batchSize,
      );

      if (changes.isEmpty) {
        break;
      }

      final batchHighWater = changes
          .map((c) => c.revision)
          .reduce((a, b) => a > b ? a : b);

      // Pre-cargar detalles fuera de la transacción para mantenerla ultrarrápida
      final operations = <Future<void> Function(CatalogDao tx)>[];

      for (final change in changes) {
        if (change.operation == 'delete') {
          operations.add((tx) => tx.applyTombstone(change.entityType, change.entityId));
          continue;
        }

        // Operación 'upsert': consultar estado actual de la entidad en el backend
        switch (change.entityType) {
          case 'title':
            final detail = await gateway.fetchTitleDetails(change.entityId);
            if (detail == null) {
              // Tratada de forma idempotente como lápida si ya no está publicada o fue borrada
              operations.add((tx) => tx.applyTombstone('title', change.entityId));
            } else {
              operations.add((tx) async {
                await tx.upsertTitle(
                  LocalTitlesCompanion.insert(
                    id: detail.id,
                    legacyId: Value(detail.legacyId),
                    mediaType: detail.mediaType,
                    title: detail.title,
                    originalTitle: Value(detail.originalTitle),
                    normalizedTitle: detail.normalizedTitle,
                    plot: Value(detail.plot),
                    year: Value(detail.year),
                    rating: Value(detail.rating),
                    duration: Value(detail.duration),
                    posterUrl: Value(detail.posterUrl),
                    backdropUrl: Value(detail.backdropUrl),
                    isFeatured: Value(detail.isFeatured),
                    castMembers: Value(detail.castMembers),
                    director: Value(detail.director),
                    writer: Value(detail.writer),
                    countryCode: Value(detail.countryCode),
                    tmdbId: Value(detail.tmdbId),
                    imdbId: Value(detail.imdbId),
                    createdAt: detail.createdAt,
                    updatedAt: DateTime.now(),
                  ),
                );
                // Persistir relaciones con géneros
                for (final g in detail.genresDetails) {
                  await tx.upsertGenre(LocalGenresCompanion(
                    id: Value(g.id),
                    name: Value(g.name),
                    slug: Value(g.slug),
                  ));
                  await tx.upsertTitleGenre(detail.id, g.id);
                }
              });
            }
            break;

          case 'genre':
            final genre = await gateway.fetchGenre(change.entityId);
            if (genre == null) {
              operations.add((tx) => tx.applyTombstone('genre', change.entityId));
            } else {
              operations.add((tx) async {
                await tx.upsertGenre(LocalGenresCompanion(
                  id: Value(genre.id),
                  name: Value(genre.name),
                  slug: Value(genre.slug),
                ));
              });
            }
            break;

          case 'language':
            final lang = await gateway.fetchLanguage(change.entityId);
            if (lang == null) {
              operations.add((tx) => tx.applyTombstone('language', change.entityId));
            } else {
              operations.add((tx) async {
                await tx.upsertLanguage(LocalLanguagesCompanion(
                  id: Value(lang.id),
                  code: Value(lang.code),
                  name: Value(lang.name),
                ));
              });
            }
            break;

          case 'season':
            final season = await gateway.fetchSeason(change.entityId);
            if (season == null) {
              operations.add((tx) => tx.applyTombstone('season', change.entityId));
            } else {
              operations.add((tx) async {
                await tx.upsertSeason(LocalSeasonsCompanion(
                  id: Value(season.id),
                  titleId: Value(season.titleId),
                  seasonNumber: Value(season.seasonNumber),
                  name: Value(season.name),
                  plot: Value(season.plot),
                  posterUrl: Value(season.posterUrl),
                ));
              });
            }
            break;

          case 'episode':
            final episode = await gateway.fetchEpisode(change.entityId);
            if (episode == null) {
              operations.add((tx) => tx.applyTombstone('episode', change.entityId));
            } else {
              operations.add((tx) async {
                await tx.upsertEpisode(LocalEpisodesCompanion(
                  id: Value(episode.id),
                  seasonId: Value(episode.seasonId),
                  episodeNumber: Value(episode.episodeNumber),
                  title: Value(episode.title),
                  plot: Value(episode.plot),
                  duration: Value(episode.duration),
                  stillUrl: Value(episode.stillUrl),
                ));
              });
            }
            break;

          case 'source':
            final source = await gateway.fetchSource(change.entityId);
            if (source == null) {
              operations.add((tx) => tx.applyTombstone('source', change.entityId));
            } else {
              operations.add((tx) async {
                await tx.upsertSource(LocalSourcesCompanion(
                  id: Value(source.id),
                  titleId: Value(source.titleId),
                  episodeId: Value(source.episodeId),
                  language: Value(source.languageCode),
                  name: Value(source.name),
                  url: Value(source.url),
                  orderIndex: Value(source.orderIndex),
                  status: Value(source.status),
                  requiresWebview: Value(source.requiresWebview),
                  refererUrl: Value(source.refererUrl),
                  originUrl: Value(source.originUrl),
                  userAgentProfile: Value(source.userAgentProfile),
                ));
              });
            }
            break;

          case 'title_genre':
            final parts = change.entityId.split(':');
            if (parts.length == 2) {
              final exists = await gateway.checkTitleGenreExists(parts[0], parts[1]);
              if (exists) {
                operations.add((tx) async {
                  await tx.upsertTitleGenre(parts[0], parts[1]);
                });
              } else {
                operations.add((tx) => tx.applyTombstone('title_genre', change.entityId));
              }
            }
            break;

          default:
            operations.add((tx) => tx.applyTombstone(change.entityType, change.entityId));
            break;
        }
      }

      // Aplicar todas las operaciones del lote y avanzar checkpoint atómicamente
      await dao.applySyncBatchAtomic(
        operations: (tx) async {
          for (final op in operations) {
            await op(tx);
          }
        },
        newRevision: batchHighWater,
        timestamp: DateTime.now(),
      );

      totalApplied += changes.length;
      currentRev = batchHighWater;

      if (changes.length < batchSize) {
        break;
      }
    }

    return SyncResult(
      initialRevision: localRev,
      finalRevision: currentRev,
      appliedChangesCount: totalApplied,
      fullResyncPerformed: false,
    );
  }

  /// Ejecuta una resincronización completa descargando snapshots paginados,
  /// limpiando únicamente las tablas de catálogo en Drift y preservando
  /// intactos favoritos, perfiles e historial del usuario.
  Future<SyncResult> _performFullResync({
    required int initialRev,
    required int targetRevision,
  }) async {
    const pageSize = 500;
    var offset = 0;
    final allSnapshotTitles = <CatalogSummaryDto>[];

    while (true) {
      final page = await gateway.fetchCompleteSnapshot(
        offset: offset,
        limit: pageSize,
      );
      if (page.isEmpty) break;
      allSnapshotTitles.addAll(page);
      if (page.length < pageSize) break;
      offset += page.length;
    }

    // Reemplazo atómico en Drift
    await dao.transaction(() async {
      await dao.clearAllCatalog();

      for (final s in allSnapshotTitles) {
        await dao.upsertTitle(
          LocalTitlesCompanion.insert(
            id: s.id,
            legacyId: Value(s.legacyId),
            mediaType: s.mediaType,
            title: s.title,
            normalizedTitle: s.normalizedTitle,
            year: Value(s.year),
            rating: Value(s.rating),
            posterUrl: Value(s.posterUrl),
            backdropUrl: Value(s.backdropUrl),
            isFeatured: Value(s.isFeatured),
            createdAt: s.createdAt,
            updatedAt: DateTime.now(),
          ),
        );
      }

      await dao.setLastCatalogRevision(targetRevision);
    });

    return SyncResult(
      initialRevision: initialRev,
      finalRevision: targetRevision,
      appliedChangesCount: allSnapshotTitles.length,
      fullResyncPerformed: true,
    );
  }
}
