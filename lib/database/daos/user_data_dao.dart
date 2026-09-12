import 'package:drift/drift.dart';
import '../catalog_database.dart';
import '../tables/user_data_tables.dart';
import '../tables/catalog_tables.dart';

part 'user_data_dao.g.dart';

@DriftAccessor(tables: [
  LocalProfileFavorites,
  LocalProfilePlaybackProgress,
  LocalProfileHistory,
  LocalProfilePreferences,
  LocalProfileSyncQueue,
  LocalProfileSyncCheckpoint,
  LocalGuestImportAudit,
  LocalTitles,
  LocalEpisodes,
])
class UserDataDao extends DatabaseAccessor<CatalogDatabase> with _$UserDataDaoMixin {
  UserDataDao(super.db);

  // --- Favoritos ---

  Future<List<LocalProfileFavorite>> getFavorites(String profileId) {
    return (select(localProfileFavorites)
          ..where((t) => t.profileId.equals(profileId) & t.isFavorite.equals(true))
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .get();
  }

  Stream<List<LocalProfileFavorite>> watchFavorites(String profileId) {
    return (select(localProfileFavorites)
          ..where((t) => t.profileId.equals(profileId) & t.isFavorite.equals(true))
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .watch();
  }

  Future<bool> isFavorite(String profileId, String contentKey) async {
    final row = await (select(localProfileFavorites)
          ..where((t) => t.profileId.equals(profileId) & t.contentKey.equals(contentKey)))
        .getSingleOrNull();
    return row?.isFavorite ?? false;
  }

  Future<void> setFavorite({
    required String profileId,
    required String contentKey,
    String? titleId,
    required bool isFavorite,
    DateTime? updatedAt,
    int? serverRevision,
  }) async {
    final now = updatedAt ?? DateTime.now().toUtc();
    await into(localProfileFavorites).insertOnConflictUpdate(
      LocalProfileFavoritesCompanion.insert(
        profileId: profileId,
        contentKey: contentKey,
        titleId: Value(titleId),
        isFavorite: Value(isFavorite),
        updatedAt: now,
        serverRevision: Value(serverRevision ?? 0),
      ),
    );
  }

  Future<int> countFavorites(String profileId) async {
    final countExp = localProfileFavorites.contentKey.count();
    final query = selectOnly(localProfileFavorites)
      ..where(localProfileFavorites.profileId.equals(profileId) & localProfileFavorites.isFavorite.equals(true))
      ..addColumns([countExp]);
    final result = await query.getSingle();
    return result.read(countExp) ?? 0;
  }

  // --- Progreso de Reproducción & Continuar Viendo ---

  Future<LocalProfilePlaybackProgressData?> getProgress(String profileId, String contentKey) {
    return (select(localProfilePlaybackProgress)
          ..where((t) => t.profileId.equals(profileId) & t.contentKey.equals(contentKey)))
        .getSingleOrNull();
  }

  Future<List<LocalProfilePlaybackProgressData>> getContinueWatching(
    String profileId, {
    int limit = 50,
  }) {
    return (select(localProfilePlaybackProgress)
          ..where((t) =>
              t.profileId.equals(profileId) &
              t.isCompleted.equals(false) &
              t.positionMs.isBiggerThanValue(0) &
              t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.lastWatchedAt)])
          ..limit(limit))
        .get();
  }

  Stream<List<LocalProfilePlaybackProgressData>> watchContinueWatching(
    String profileId, {
    int limit = 50,
  }) {
    return (select(localProfilePlaybackProgress)
          ..where((t) =>
              t.profileId.equals(profileId) &
              t.isCompleted.equals(false) &
              t.positionMs.isBiggerThanValue(0) &
              t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.lastWatchedAt)])
          ..limit(limit))
        .watch();
  }

  Future<void> upsertProgress({
    required String profileId,
    required String contentKey,
    String? playbackSessionId,
    String? titleId,
    String? episodeId,
    required int positionMs,
    required int durationMs,
    required double fraction,
    required bool isCompleted,
    required DateTime lastWatchedAt,
    required DateTime updatedAt,
    DateTime? deletedAt,
    int? serverRevision,
  }) async {
    await into(localProfilePlaybackProgress).insertOnConflictUpdate(
      LocalProfilePlaybackProgressCompanion.insert(
        profileId: profileId,
        contentKey: contentKey,
        playbackSessionId: Value(playbackSessionId),
        titleId: Value(titleId),
        episodeId: Value(episodeId),
        positionMs: Value(positionMs),
        durationMs: Value(durationMs),
        fraction: Value(fraction),
        isCompleted: Value(isCompleted),
        lastWatchedAt: lastWatchedAt,
        updatedAt: updatedAt,
        deletedAt: Value(deletedAt),
        serverRevision: Value(serverRevision ?? 0),
      ),
    );
  }

  Future<void> deleteProgress(
    String profileId,
    String contentKey, {
    DateTime? deletedAt,
    int? serverRevision,
  }) async {
    final now = deletedAt ?? DateTime.now().toUtc();
    await (update(localProfilePlaybackProgress)
          ..where((t) => t.profileId.equals(profileId) & t.contentKey.equals(contentKey)))
        .write(
      LocalProfilePlaybackProgressCompanion(
        deletedAt: Value(now),
        updatedAt: Value(now),
        serverRevision: Value(serverRevision ?? 0),
      ),
    );
  }

  // --- Historial ---

  Future<List<LocalProfileHistoryData>> getHistory(
    String profileId, {
    int limit = 50,
  }) {
    return (select(localProfileHistory)
          ..where((t) => t.profileId.equals(profileId))
          ..orderBy([(t) => OrderingTerm.desc(t.watchedAt)])
          ..limit(limit))
        .get();
  }

  Stream<List<LocalProfileHistoryData>> watchHistory(
    String profileId, {
    int limit = 50,
  }) {
    return (select(localProfileHistory)
          ..where((t) => t.profileId.equals(profileId))
          ..orderBy([(t) => OrderingTerm.desc(t.watchedAt)])
          ..limit(limit))
        .watch();
  }

  Future<void> addHistoryEntry({
    required String id,
    required String profileId,
    required String playbackSessionId,
    required String contentKey,
    String? titleId,
    String? episodeId,
    required int stoppedAtMs,
    required int durationMs,
    required double fraction,
    required bool isCompleted,
    required DateTime watchedAt,
    int? serverRevision,
  }) async {
    await into(localProfileHistory).insertOnConflictUpdate(
      LocalProfileHistoryCompanion.insert(
        id: id,
        profileId: profileId,
        playbackSessionId: playbackSessionId,
        contentKey: contentKey,
        titleId: Value(titleId),
        episodeId: Value(episodeId),
        stoppedAtMs: Value(stoppedAtMs),
        durationMs: Value(durationMs),
        fraction: Value(fraction),
        isCompleted: Value(isCompleted),
        watchedAt: watchedAt,
        serverRevision: Value(serverRevision ?? 0),
      ),
    );
  }

  Future<void> pruneHistory(String profileId, {int maxEntries = 500}) async {
    await customStatement('''
      DELETE FROM local_profile_history
      WHERE profile_id = ?
        AND id NOT IN (
          SELECT id FROM local_profile_history
          WHERE profile_id = ?
          ORDER BY watched_at DESC, id DESC
          LIMIT ?
        )
    ''', [profileId, profileId, maxEntries]);
  }

  // --- Preferencias ---

  Future<LocalProfilePreference?> getPreferences(String profileId) {
    return (select(localProfilePreferences)..where((t) => t.profileId.equals(profileId)))
        .getSingleOrNull();
  }

  Future<void> upsertPreferences(
    String profileId, {
    String? preferredAudioLanguage,
    String? preferredSubtitleLanguage,
    bool? subtitlesEnabled,
    bool? autoPlayNext,
    DateTime? updatedAt,
    int? serverRevision,
  }) async {
    final now = updatedAt ?? DateTime.now().toUtc();
    final existing = await getPreferences(profileId);
    await into(localProfilePreferences).insertOnConflictUpdate(
      LocalProfilePreferencesCompanion.insert(
        profileId: profileId,
        preferredAudioLanguage: Value(preferredAudioLanguage ?? existing?.preferredAudioLanguage),
        preferredSubtitleLanguage:
            Value(preferredSubtitleLanguage ?? existing?.preferredSubtitleLanguage),
        subtitlesEnabled: Value(subtitlesEnabled ?? existing?.subtitlesEnabled ?? false),
        autoPlayNext: Value(autoPlayNext ?? existing?.autoPlayNext ?? true),
        updatedAt: now,
        serverRevision: Value(serverRevision ?? 0),
      ),
    );
  }

  // --- Cola de Sincronización ---

  Future<int> getNextSequence(String profileId, String deviceId) async {
    final maxSeq = localProfileSyncQueue.clientSequence.max();
    final query = selectOnly(localProfileSyncQueue)
      ..where(localProfileSyncQueue.profileId.equals(profileId) &
          localProfileSyncQueue.deviceId.equals(deviceId))
      ..addColumns([maxSeq]);
    final result = await query.getSingle();
    final current = result.read(maxSeq) ?? 0;
    return current + 1;
  }

  Future<void> enqueueOperation({
    required String operationId,
    required String profileId,
    required String deviceId,
    required int clientSequence,
    String? playbackSessionId,
    required String operationType,
    required String contentKey,
    String? titleId,
    String? episodeId,
    required String payload,
    required DateTime clientTimestamp,
  }) async {
    await into(localProfileSyncQueue).insert(
      LocalProfileSyncQueueCompanion.insert(
        operationId: operationId,
        profileId: profileId,
        deviceId: deviceId,
        clientSequence: clientSequence,
        playbackSessionId: Value(playbackSessionId),
        operationType: operationType,
        contentKey: contentKey,
        titleId: Value(titleId),
        episodeId: Value(episodeId),
        payload: Value(payload),
        clientTimestamp: clientTimestamp,
        status: const Value('pending'),
        createdAt: DateTime.now().toUtc(),
      ),
    );
  }

  Future<List<LocalProfileSyncQueueData>> getPendingOperations(
    String profileId, {
    int limit = 100,
  }) {
    return (select(localProfileSyncQueue)
          ..where((t) => t.profileId.equals(profileId) & t.status.isIn(['pending', 'failed']))
          ..orderBy([(t) => OrderingTerm.asc(t.clientSequence)])
          ..limit(limit))
        .get();
  }

  Future<void> updateOperationStatus(
    String operationId,
    String status, {
    int? retryCount,
  }) async {
    await (update(localProfileSyncQueue)..where((t) => t.operationId.equals(operationId))).write(
      LocalProfileSyncQueueCompanion(
        status: Value(status),
        retryCount: retryCount != null ? Value(retryCount) : const Value.absent(),
      ),
    );
  }

  Future<void> removeOperations(List<String> operationIds) async {
    if (operationIds.isEmpty) return;
    await (delete(localProfileSyncQueue)..where((t) => t.operationId.isIn(operationIds))).go();
  }

  // --- Checkpoint ---

  Future<LocalProfileSyncCheckpointData?> getCheckpoint(String profileId) {
    return (select(localProfileSyncCheckpoint)..where((t) => t.profileId.equals(profileId)))
        .getSingleOrNull();
  }

  Future<void> updateCheckpoint(
    String profileId, {
    required int latestServerRevision,
    DateTime? lastSyncedAt,
    int? lastSuccessfulSequence,
  }) async {
    await into(localProfileSyncCheckpoint).insertOnConflictUpdate(
      LocalProfileSyncCheckpointCompanion.insert(
        profileId: profileId,
        latestServerRevision: Value(latestServerRevision),
        lastSyncedAt: Value(lastSyncedAt),
        lastSuccessfulSequence: Value(lastSuccessfulSequence ?? 0),
      ),
    );
  }

  // --- Auditoría de Modo Invitado ---

  Future<LocalGuestImportAuditData?> getGuestImportAudit(
    String targetProfileId,
    String importBatchId,
  ) {
    return (select(localGuestImportAudit)
          ..where((t) =>
              t.targetProfileId.equals(targetProfileId) & t.importBatchId.equals(importBatchId)))
        .getSingleOrNull();
  }

  Future<void> upsertGuestImportAudit({
    required String id,
    required String targetProfileId,
    required String importBatchId,
    required String status,
    int favoritesCount = 0,
    int progressCount = 0,
    int historyCount = 0,
    String? errorMessage,
    required DateTime createdAt,
    DateTime? completedAt,
  }) async {
    await into(localGuestImportAudit).insertOnConflictUpdate(
      LocalGuestImportAuditCompanion.insert(
        id: id,
        targetProfileId: targetProfileId,
        importBatchId: importBatchId,
        status: status,
        favoritesCount: Value(favoritesCount),
        progressCount: Value(progressCount),
        historyCount: Value(historyCount),
        errorMessage: Value(errorMessage),
        createdAt: createdAt,
        completedAt: Value(completedAt),
      ),
    );
  }

  // --- Materialización atómica de snapshot ---

  Future<void> applySnapshot({
    required String profileId,
    required int snapshotRevision,
    required List<LocalProfileFavoritesCompanion> favorites,
    required List<LocalProfilePlaybackProgressCompanion> progress,
    required List<LocalProfileHistoryCompanion> history,
    LocalProfilePreferencesCompanion? preferences,
  }) async {
    await transaction(() async {
      // 1. Reemplazar favoritos del perfil
      await (delete(localProfileFavorites)..where((t) => t.profileId.equals(profileId))).go();
      for (final fav in favorites) {
        await into(localProfileFavorites).insert(fav);
      }

      // 2. Reemplazar progreso
      await (delete(localProfilePlaybackProgress)..where((t) => t.profileId.equals(profileId))).go();
      for (final prog in progress) {
        await into(localProfilePlaybackProgress).insert(prog);
      }

      // 3. Reemplazar historial
      await (delete(localProfileHistory)..where((t) => t.profileId.equals(profileId))).go();
      for (final hist in history) {
        await into(localProfileHistory).insert(hist);
      }

      // 4. Preferencias si vienen
      if (preferences != null) {
        await into(localProfilePreferences).insertOnConflictUpdate(preferences);
      }

      // 5. Actualizar checkpoint
      await updateCheckpoint(
        profileId,
        latestServerRevision: snapshotRevision,
        lastSyncedAt: DateTime.now().toUtc(),
      );
    });
  }
}
