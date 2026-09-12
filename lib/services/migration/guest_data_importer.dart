import '../../database/daos/user_data_dao.dart';
import '../sync/profile_sync_engine.dart';
import '../sync/profile_sync_gateway.dart';
import '../sync/uuid_utils.dart';

class GuestImportSummary {
  final int favoritesCount;
  final int progressCount;
  final int historyCount;

  const GuestImportSummary({
    required this.favoritesCount,
    required this.progressCount,
    required this.historyCount,
  });

  bool get hasData => favoritesCount > 0 || progressCount > 0 || historyCount > 0;
}

class GuestImportResult {
  final bool success;
  final String importBatchId;
  final int favoritesImported;
  final int progressImported;
  final int historyImported;
  final String? errorMessage;

  const GuestImportResult({
    required this.success,
    required this.importBatchId,
    this.favoritesImported = 0,
    this.progressImported = 0,
    this.historyImported = 0,
    this.errorMessage,
  });

  factory GuestImportResult.empty(String batchId) => GuestImportResult(
        success: true,
        importBatchId: batchId,
      );

  factory GuestImportResult.error(String batchId, String message) => GuestImportResult(
        success: false,
        importBatchId: batchId,
        errorMessage: message,
      );
}

/// Servicio de importación idempotente y no destructiva de datos del modo Invitado
/// hacia perfiles autenticados, con auditoría y compatibilidad offline.
class GuestDataImporter {
  final UserDataDao userDataDao;
  final ProfileSyncEngine syncEngine;
  final ProfileSyncGateway? gateway;
  final String deviceId;

  GuestDataImporter({
    required this.userDataDao,
    required this.syncEngine,
    this.gateway,
    required this.deviceId,
  });

  /// Inspecciona el volumen de datos personales almacenados bajo el perfil Invitado.
  Future<GuestImportSummary> inspectGuestData({String guestProfileId = 'guest'}) async {
    final favs = await userDataDao.getFavorites(guestProfileId);
    final progs = await userDataDao.getContinueWatching(guestProfileId, limit: 1000);
    final hists = await userDataDao.getHistory(guestProfileId, limit: 1000);

    return GuestImportSummary(
      favoritesCount: favs.length,
      progressCount: progs.length,
      historyCount: hists.length,
    );
  }

  /// Importa los datos del perfil Invitado al perfil destino respetando la máquina de estados.
  /// No borra los datos del perfil Invitado (preservación no destructiva).
  Future<GuestImportResult> importGuestData({
    required String targetProfileId,
    String guestProfileId = 'guest',
  }) async {
    // 1. Generar import_batch_id determinista RFC 4122 v5
    final importBatchId = UuidUtils.v5(
      UuidUtils.namespaceUrl,
      'guest_import_${deviceId}_$targetProfileId',
    );
    final auditRowId = UuidUtils.v5(importBatchId, 'audit_row');

    try {
      final favs = await userDataDao.getFavorites(guestProfileId);
      final progs = await userDataDao.getContinueWatching(guestProfileId, limit: 1000);
      final hists = await userDataDao.getHistory(guestProfileId, limit: 1000);

      // Verificar si ya existe un lote completado con los mismos recuentos (idempotencia)
      final existingAudit = await userDataDao.getGuestImportAudit(targetProfileId, importBatchId);
      if (existingAudit != null && existingAudit.status == 'completed') {
        if (existingAudit.favoritesCount == favs.length &&
            existingAudit.progressCount == progs.length &&
            existingAudit.historyCount == hists.length) {
          return GuestImportResult(
            success: true,
            importBatchId: importBatchId,
            favoritesImported: favs.length,
            progressImported: progs.length,
            historyImported: hists.length,
          );
        }
      }

      final now = DateTime.now().toUtc();

      // 2. Máquina de estados: inexistente -> in_progress
      await userDataDao.upsertGuestImportAudit(
        id: auditRowId,
        targetProfileId: targetProfileId,
        importBatchId: importBatchId,
        status: 'in_progress',
        favoritesCount: favs.length,
        progressCount: progs.length,
        historyCount: hists.length,
        createdAt: now,
      );
      try {
        await gateway?.updateGuestImportAudit(
          profileId: targetProfileId,
          importBatchId: importBatchId,
          status: 'in_progress',
          favoritesCount: favs.length,
          progressCount: progs.length,
          historyCount: hists.length,
        );
      } catch (_) {}

      // 3. Copiar favoritos al perfil destino
      for (final f in favs) {
        await syncEngine.recordFavorite(
          profileId: targetProfileId,
          contentKey: f.contentKey,
          titleId: f.titleId,
          isFavorite: true,
          updatedAt: f.updatedAt,
        );
      }

      // 4. Copiar progreso de reproducción al perfil destino
      for (final p in progs) {
        await syncEngine.recordProgress(
          profileId: targetProfileId,
          contentKey: p.contentKey,
          playbackSessionId: p.playbackSessionId,
          titleId: p.titleId,
          episodeId: p.episodeId,
          positionMs: p.positionMs,
          durationMs: p.durationMs,
          fraction: p.fraction,
          isCompleted: p.isCompleted,
          lastWatchedAt: p.lastWatchedAt,
          updatedAt: p.updatedAt,
        );
      }

      // 5. Copiar historial al perfil destino con IDs deterministas derivados de v5
      for (final h in hists) {
        final newHistId = UuidUtils.v5(importBatchId, 'hist_${h.id}');
        await syncEngine.recordHistoryEntry(
          id: newHistId,
          profileId: targetProfileId,
          playbackSessionId: h.playbackSessionId,
          contentKey: h.contentKey,
          titleId: h.titleId,
          episodeId: h.episodeId,
          stoppedAtMs: h.stoppedAtMs,
          durationMs: h.durationMs,
          fraction: h.fraction,
          isCompleted: h.isCompleted,
          watchedAt: h.watchedAt,
        );
      }

      // 6. Máquina de estados: in_progress -> completed
      final completedAt = DateTime.now().toUtc();
      await userDataDao.upsertGuestImportAudit(
        id: auditRowId,
        targetProfileId: targetProfileId,
        importBatchId: importBatchId,
        status: 'completed',
        favoritesCount: favs.length,
        progressCount: progs.length,
        historyCount: hists.length,
        createdAt: now,
        completedAt: completedAt,
      );
      try {
        await gateway?.updateGuestImportAudit(
          profileId: targetProfileId,
          importBatchId: importBatchId,
          status: 'completed',
          favoritesCount: favs.length,
          progressCount: progs.length,
          historyCount: hists.length,
        );
      } catch (_) {}

      return GuestImportResult(
        success: true,
        importBatchId: importBatchId,
        favoritesImported: favs.length,
        progressImported: progs.length,
        historyImported: hists.length,
      );
    } catch (e) {
      // Máquina de estados: in_progress -> failed
      final errorMsg = e.toString().length > 500 ? e.toString().substring(0, 500) : e.toString();
      await userDataDao.upsertGuestImportAudit(
        id: auditRowId,
        targetProfileId: targetProfileId,
        importBatchId: importBatchId,
        status: 'failed',
        errorMessage: errorMsg,
        createdAt: DateTime.now().toUtc(),
        completedAt: DateTime.now().toUtc(),
      );
      try {
        await gateway?.updateGuestImportAudit(
          profileId: targetProfileId,
          importBatchId: importBatchId,
          status: 'failed',
          errorMessage: errorMsg,
        );
      } catch (_) {}

      return GuestImportResult.error(importBatchId, e.toString());
    }
  }
}
