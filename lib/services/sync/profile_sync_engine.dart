import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:drift/drift.dart';
import '../../database/catalog_database.dart';
import '../../database/daos/user_data_dao.dart';
import '../storage_service.dart';
import 'profile_sync_gateway.dart';
import 'uuid_utils.dart';

class PushResult {
  final int sentCount;
  final int appliedCount;
  final bool hasError;
  final String? errorMessage;

  const PushResult({
    this.sentCount = 0,
    this.appliedCount = 0,
    this.hasError = false,
    this.errorMessage,
  });
}

class SyncResult {
  final bool skippedGuest;
  final bool isOffline;
  final bool success;
  final String? errorMessage;

  const SyncResult({
    this.skippedGuest = false,
    this.isOffline = false,
    this.success = true,
    this.errorMessage,
  });

  factory SyncResult.skippedGuest() => const SyncResult(skippedGuest: true);
  factory SyncResult.offline() => const SyncResult(isOffline: true);
  factory SyncResult.error(String message) => SyncResult(success: false, errorMessage: message);
}

/// Motor de sincronización determinista de perfiles de HourTV.
class ProfileSyncEngine {
  static ProfileSyncEngine? _instance;
  static ProfileSyncEngine? get instance => _instance;
  static void setInstance(ProfileSyncEngine? engine) => _instance = engine;

  final UserDataDao userDataDao;
  final ProfileSyncGateway? gateway;
  final String deviceId;

  ProfileSyncEngine({
    required this.userDataDao,
    this.gateway,
    required this.deviceId,
  });

  UserDataDao get _dao => userDataDao;
  ProfileSyncGateway? get _gateway => gateway;
  String get _deviceId => deviceId;

  /// Perfil local (sin cuenta) o de la nube. Los perfiles de la nube tienen
  /// id UUID de Supabase; los locales, un slug ("kleiner", "invitado").
  /// Antes solo contaba el perfil activo: lo que se hacía en los demás
  /// perfiles de la cuenta (o lo importado) nunca se subía.
  bool isGuestProfile(String profileId) => !UuidUtils.isUuid(profileId);

  /// Vuelca forzadamente y sincroniza las operaciones locales en cambios de ciclo de vida.
  Future<void> flush([String? profileId]) async {
    final targetId = profileId ?? StorageService.activeProfileId;
    if (!isGuestProfile(targetId)) await syncProfile(targetId);
    await pushAllPending(except: targetId);
  }

  /// Sube lo pendiente de todos los perfiles de la cuenta.
  Future<void> pushAllPending({String? except}) async {
    if (_gateway == null) return;
    for (final profileId in await _dao.getProfilesWithPendingOperations()) {
      if (profileId == except || isGuestProfile(profileId)) continue;
      try {
        await pushPendingOperations(profileId);
      } catch (_) {}
    }
  }

  // --- Grabación local con encolado determinista para sincronización ---

  Future<void> recordFavorite({
    required String profileId,
    required String contentKey,
    String? titleId,
    required bool isFavorite,
    DateTime? updatedAt,
  }) async {
    final now = updatedAt ?? DateTime.now().toUtc();
    await _dao.setFavorite(
      profileId: profileId,
      contentKey: contentKey,
      titleId: titleId,
      isFavorite: isFavorite,
      updatedAt: now,
    );

    if (!isGuestProfile(profileId) && _gateway != null) {
      final opId = UuidUtils.v4();
      final seq = await _dao.getNextSequence(profileId, _deviceId);
      await _dao.enqueueOperation(
        operationId: opId,
        profileId: profileId,
        deviceId: _deviceId,
        clientSequence: seq,
        operationType: isFavorite ? 'favorite_add' : 'favorite_remove',
        contentKey: contentKey,
        titleId: titleId,
        payload: '{}',
        clientTimestamp: now,
      );
    }
  }

  Future<void> recordProgress({
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
    DateTime? updatedAt,
  }) async {
    final now = updatedAt ?? DateTime.now().toUtc();
    await _dao.upsertProgress(
      profileId: profileId,
      contentKey: contentKey,
      playbackSessionId: playbackSessionId,
      titleId: titleId,
      episodeId: episodeId,
      positionMs: positionMs,
      durationMs: durationMs,
      fraction: fraction,
      isCompleted: isCompleted,
      lastWatchedAt: lastWatchedAt,
      updatedAt: now,
    );

    if (!isGuestProfile(profileId) && _gateway != null) {
      final opId = UuidUtils.v4();
      final seq = await _dao.getNextSequence(profileId, _deviceId);
      final payloadStr = jsonEncode({
        'position_ms': positionMs,
        'duration_ms': durationMs,
      });

      await _dao.enqueueOperation(
        operationId: opId,
        profileId: profileId,
        deviceId: _deviceId,
        clientSequence: seq,
        playbackSessionId: playbackSessionId,
        operationType: 'progress_update',
        contentKey: contentKey,
        titleId: titleId,
        episodeId: episodeId,
        payload: payloadStr,
        clientTimestamp: now,
      );
    }
  }

  Future<void> recordRestart({
    required String profileId,
    required String contentKey,
    required String playbackSessionId,
    String? titleId,
    String? episodeId,
    required int durationMs,
    required DateTime lastWatchedAt,
    DateTime? updatedAt,
  }) async {
    final now = updatedAt ?? DateTime.now().toUtc();
    await _dao.upsertProgress(
      profileId: profileId,
      contentKey: contentKey,
      playbackSessionId: playbackSessionId,
      titleId: titleId,
      episodeId: episodeId,
      positionMs: 0,
      durationMs: durationMs,
      fraction: 0.0,
      isCompleted: false,
      lastWatchedAt: lastWatchedAt,
      updatedAt: now,
    );

    if (!isGuestProfile(profileId) && _gateway != null) {
      final opId = UuidUtils.v4();
      final seq = await _dao.getNextSequence(profileId, _deviceId);
      final payloadStr = jsonEncode({'duration_ms': durationMs});

      await _dao.enqueueOperation(
        operationId: opId,
        profileId: profileId,
        deviceId: _deviceId,
        clientSequence: seq,
        playbackSessionId: playbackSessionId,
        operationType: 'restart',
        contentKey: contentKey,
        titleId: titleId,
        episodeId: episodeId,
        payload: payloadStr,
        clientTimestamp: now,
      );
    }
  }

  Future<void> recordHistoryEntry({
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
  }) async {
    await _dao.addHistoryEntry(
      id: id,
      profileId: profileId,
      playbackSessionId: playbackSessionId,
      contentKey: contentKey,
      titleId: titleId,
      episodeId: episodeId,
      stoppedAtMs: stoppedAtMs,
      durationMs: durationMs,
      fraction: fraction,
      isCompleted: isCompleted,
      watchedAt: watchedAt,
    );

    await _dao.pruneHistory(profileId, maxEntries: 500);

    if (!isGuestProfile(profileId) && _gateway != null) {
      final opId = UuidUtils.v4();
      final seq = await _dao.getNextSequence(profileId, _deviceId);
      final payloadStr = jsonEncode({
        'history_id': id,
        'stopped_at_ms': stoppedAtMs,
        'duration_ms': durationMs,
        'is_completed': isCompleted,
      });

      await _dao.enqueueOperation(
        operationId: opId,
        profileId: profileId,
        deviceId: _deviceId,
        clientSequence: seq,
        playbackSessionId: playbackSessionId,
        operationType: 'history_add',
        contentKey: contentKey,
        titleId: titleId,
        episodeId: episodeId,
        payload: payloadStr,
        clientTimestamp: watchedAt,
      );
    }
  }

  Future<void> recordPreferences(
    String profileId, {
    String? preferredAudioLanguage,
    String? preferredSubtitleLanguage,
    bool? subtitlesEnabled,
    bool? autoPlayNext,
    DateTime? updatedAt,
  }) async {
    final now = updatedAt ?? DateTime.now().toUtc();
    await _dao.upsertPreferences(
      profileId,
      preferredAudioLanguage: preferredAudioLanguage,
      preferredSubtitleLanguage: preferredSubtitleLanguage,
      subtitlesEnabled: subtitlesEnabled,
      autoPlayNext: autoPlayNext,
      updatedAt: now,
    );

    if (!isGuestProfile(profileId) && _gateway != null) {
      final opId = UuidUtils.v4();
      final seq = await _dao.getNextSequence(profileId, _deviceId);
      final payloadMap = <String, dynamic>{};
      if (preferredAudioLanguage != null) payloadMap['preferred_audio_language'] = preferredAudioLanguage;
      if (preferredSubtitleLanguage != null) payloadMap['preferred_subtitle_language'] = preferredSubtitleLanguage;
      if (subtitlesEnabled != null) payloadMap['subtitles_enabled'] = subtitlesEnabled;
      if (autoPlayNext != null) payloadMap['auto_play_next'] = autoPlayNext;

      await _dao.enqueueOperation(
        operationId: opId,
        profileId: profileId,
        deviceId: _deviceId,
        clientSequence: seq,
        operationType: 'preferences_update',
        contentKey: 'preferences',
        payload: jsonEncode(payloadMap),
        clientTimestamp: now,
      );
    }
  }

  // --- Sincronización Remota: Push ---

  Future<PushResult> pushPendingOperations(String profileId, {int batchSize = 50}) async {
    final gateway = _gateway;
    if (gateway == null || isGuestProfile(profileId)) {
      return const PushResult();
    }

    final pending = await _dao.getPendingOperations(profileId, limit: batchSize);
    if (pending.isEmpty) {
      debugPrint('[SYNC] push ${profileId.substring(0, 8)}: nada pendiente');
      return const PushResult();
    }

    // Lo que el servidor jamás aceptaría (p. ej. historial de menos de un
    // minuto) se descarta: un solo rechazo tumba el lote entero.
    final sendable = <LocalProfileSyncQueueData>[];
    final operationsPayload = <Map<String, dynamic>>[];
    final dropped = <String>[];
    for (final op in pending) {
      final item = toServerOperation(
        profileId: profileId,
        operationId: op.operationId,
        deviceId: op.deviceId,
        clientSequence: op.clientSequence,
        operationType: op.operationType,
        contentKey: op.contentKey,
        playbackSessionId: op.playbackSessionId,
        titleId: op.titleId,
        payload: op.payload,
        clientTimestamp: op.clientTimestamp,
      );
      if (item == null || op.retryCount >= 5) {
        dropped.add(op.operationId);
      } else {
        sendable.add(op);
        operationsPayload.add(item);
      }
    }
    if (dropped.isNotEmpty) await _dao.removeOperations(dropped);
    if (operationsPayload.isEmpty) return const PushResult();

    try {
      final results = await gateway.pushOperations(profileId, operationsPayload);
      final appliedIds = <String>[];

      for (final res in results) {
        final opId = res['operation_id']?.toString();
        final status = res['status']?.toString() ?? res['apply_status']?.toString();

        if (opId != null) {
          if (status == 'applied' || status == 'duplicate' || status == 'ignored_stale') {
            appliedIds.add(opId);
          } else if (status == 'error') {
            final op = pending.firstWhere((p) => p.operationId == opId);
            await _dao.updateOperationStatus(opId, 'failed', retryCount: op.retryCount + 1);
          }
        }
      }

      if (appliedIds.isNotEmpty) {
        await _dao.removeOperations(appliedIds);
      }
      debugPrint(
        '[SYNC] push ${profileId.substring(0, 8)}: '
        'enviadas ${operationsPayload.length}, aceptadas ${appliedIds.length}',
      );

      return PushResult(
        sentCount: operationsPayload.length,
        appliedCount: appliedIds.length,
      );
    } catch (e) {
      debugPrint('[SYNC] push ${profileId.substring(0, 8)} rechazado: $e');
      for (final op in sendable) {
        await _dao.updateOperationStatus(op.operationId, 'failed', retryCount: op.retryCount + 1);
      }
      return PushResult(
        sentCount: operationsPayload.length,
        hasError: true,
        errorMessage: e.toString(),
      );
    }
  }

  static const _allowedPreferenceKeys = {
    'preferred_audio_language',
    'preferred_subtitle_language',
    'subtitles_enabled',
    'preferred_quality',
  };

  /// Traduce una operación de la cola al contrato de push_profile_operations
  /// (ver la migración create_profile_sync_schema). null = el servidor la
  /// rechazaría siempre.
  ///
  /// - playback_session_id debe ser UUID; title_id/episode_id no se envían.
  /// - El historial se llama history_append y lleva position_ms/duration_ms
  ///   (y solo se acepta si pasó de un minuto o del 90 %).
  /// - preferences_update solo admite ciertas claves.
  static Map<String, dynamic>? toServerOperation({
    required String profileId,
    required String operationId,
    required String deviceId,
    required int clientSequence,
    required String operationType,
    required String contentKey,
    required String? playbackSessionId,
    required String? titleId,
    required String payload,
    required DateTime clientTimestamp,
  }) {
    final key = contentKey.trim();
    if (key.isEmpty || key.length > 255) return null;
    Map<String, dynamic> data;
    try {
      data = Map<String, dynamic>.from(jsonDecode(payload) as Map);
    } catch (_) {
      data = {};
    }
    // Una sesión estable por perfil y título: el servidor ignora el avance
    // que llega con otra sesión distinta de la guardada.
    // Siempre la misma (aunque la operación traiga otra): si llegara con una
    // sesión distinta de la guardada, el servidor la marcaría como vieja.
    final session = UuidUtils.v5(
      UuidUtils.namespaceUrl,
      'hourtv-session:$profileId:$key',
    );
    var type = operationType;
    switch (operationType) {
      case 'favorite_add':
      case 'favorite_remove':
        data = {};
      case 'progress_update':
        final pos = (data['position_ms'] as num?)?.toInt() ?? 0;
        final dur = (data['duration_ms'] as num?)?.toInt() ?? 0;
        if (pos < 0 || dur < 0) return null;
        data = {
          'position_ms': dur > 0 && pos > dur ? dur : pos,
          'duration_ms': dur,
        };
      case 'restart':
      case 'mark_completed':
        final dur = (data['duration_ms'] as num?)?.toInt();
        data = {if (dur != null && dur > 0) 'duration_ms': dur};
      case 'history_add':
      case 'history_append':
        type = 'history_append';
        final pos =
            (data['position_ms'] as num?)?.toInt() ??
            (data['stopped_at_ms'] as num?)?.toInt() ??
            0;
        final dur = (data['duration_ms'] as num?)?.toInt() ?? 0;
        final meaningful = pos >= 60000 || (dur > 0 && pos >= dur * 0.9);
        if (!meaningful || pos < 0 || dur < 0) return null;
        data = {'position_ms': pos, 'duration_ms': dur};
      case 'preferences_update':
        data.removeWhere((k, _) => !_allowedPreferenceKeys.contains(k));
        if (data.isEmpty) return null;
      default:
        return null;
    }
    return {
      'operation_id': operationId,
      'device_id': deviceId,
      'client_sequence': clientSequence,
      'operation_type': type,
      'content_key': key,
      'payload': data,
      'client_timestamp': clientTimestamp.toUtc().toIso8601String(),
      'playback_session_id': session,
      // Sin title_id: el servidor exige que exista en su tabla "titles" y el
      // catálogo publicado (catalog.json) no está ahí. La clave de contenido
      // ya identifica el título.
    };
  }

  // --- Sincronización Remota: Pull ---

  Future<void> pullRemoteChanges(String profileId, {int pageSize = 100}) async {
    final gateway = _gateway;
    if (gateway == null || isGuestProfile(profileId)) {
      return;
    }

    final checkpoint = await _dao.getCheckpoint(profileId);
    var currentCursor = checkpoint?.latestServerRevision ?? 0;
    var hasMore = true;

    while (hasMore) {
      final response = await gateway.pullChanges(
        profileId,
        sinceRevision: currentCursor,
        limit: pageSize,
      );

      final fullResyncRequired = response['full_resync_required'] == true;
      if (fullResyncRequired) {
        await _handleFullResync(profileId);
        break;
      }

      final operations = (response['operations'] as List?) ?? [];
      final nextCursor = (response['next_cursor'] as num?)?.toInt() ?? currentCursor;
      hasMore = response['has_more'] == true;

      for (final opItem in operations) {
        if (opItem is! Map) continue;
        final op = Map<String, dynamic>.from(opItem);
        final applyStatus = op['apply_status']?.toString() ?? 'applied';

        // Si es ignored_stale, no degradar el estado activo local
        if (applyStatus == 'ignored_stale') {
          continue;
        }

        await _materializeOperationLocally(profileId, op);
      }

      currentCursor = nextCursor;
      await _dao.updateCheckpoint(
        profileId,
        latestServerRevision: currentCursor,
        lastSyncedAt: DateTime.now().toUtc(),
      );
    }
  }

  Future<void> _materializeOperationLocally(String profileId, Map<String, dynamic> op) async {
    final opType = op['operation_type']?.toString();
    final contentKey = op['content_key']?.toString();
    final titleId = op['title_id']?.toString();
    final episodeId = op['episode_id']?.toString();
    final sessionId = op['playback_session_id']?.toString();
    final serverRev = (op['server_revision'] as num?)?.toInt() ?? 0;
    final serverReceivedAtStr = op['server_received_at']?.toString();
    // Cuándo ocurrió en el dispositivo de origen (para ordenar "Continuar
    // viendo"); si no viene, cuándo lo recibió el servidor.
    final clientTs = DateTime.tryParse(op['client_timestamp']?.toString() ?? '');
    final receivedAt =
        clientTs?.toUtc() ??
        (serverReceivedAtStr != null
            ? DateTime.tryParse(serverReceivedAtStr)?.toUtc() ??
                  DateTime.now().toUtc()
            : DateTime.now().toUtc());

    final payload = (op['payload'] is Map)
        ? Map<String, dynamic>.from(op['payload'] as Map)
        : <String, dynamic>{};

    if (contentKey == null) return;

    switch (opType) {
      case 'favorite_add':
        await _dao.setFavorite(
          profileId: profileId,
          contentKey: contentKey,
          titleId: titleId,
          isFavorite: true,
          updatedAt: receivedAt,
          serverRevision: serverRev,
        );
        break;
      case 'favorite_remove':
        await _dao.setFavorite(
          profileId: profileId,
          contentKey: contentKey,
          titleId: titleId,
          isFavorite: false,
          updatedAt: receivedAt,
          serverRevision: serverRev,
        );
        break;
      case 'progress_update':
        final pos = (payload['position_ms'] as num?)?.toInt() ?? 0;
        final dur = (payload['duration_ms'] as num?)?.toInt() ?? 0;
        final frac = dur > 0 ? (pos / dur).clamp(0.0, 1.0) : 0.0;
        final isCompleted = frac >= 0.90;

        await _dao.upsertProgress(
          profileId: profileId,
          contentKey: contentKey,
          playbackSessionId: sessionId,
          titleId: titleId,
          episodeId: episodeId,
          positionMs: pos,
          durationMs: dur,
          fraction: frac,
          isCompleted: isCompleted,
          lastWatchedAt: receivedAt,
          updatedAt: receivedAt,
          serverRevision: serverRev,
        );
        break;
      case 'restart':
        final dur = (payload['duration_ms'] as num?)?.toInt() ?? 0;
        await _dao.upsertProgress(
          profileId: profileId,
          contentKey: contentKey,
          playbackSessionId: sessionId,
          titleId: titleId,
          episodeId: episodeId,
          positionMs: 0,
          durationMs: dur,
          fraction: 0.0,
          isCompleted: false,
          lastWatchedAt: receivedAt,
          updatedAt: receivedAt,
          serverRevision: serverRev,
        );
        break;
      case 'progress_delete':
        await _dao.deleteProgress(
          profileId,
          contentKey,
          deletedAt: receivedAt,
          serverRevision: serverRev,
        );
        break;
      case 'history_add':
      case 'history_append':
        final histId =
            payload['history_id']?.toString() ??
            op['operation_id']?.toString() ??
            UuidUtils.v4();
        final stoppedAt =
            (payload['stopped_at_ms'] as num?)?.toInt() ??
            (payload['position_ms'] as num?)?.toInt() ??
            0;
        final dur = (payload['duration_ms'] as num?)?.toInt() ?? 0;
        final isComp = payload['is_completed'] == true;
        final frac = dur > 0 ? (stoppedAt / dur).clamp(0.0, 1.0) : 0.0;

        await _dao.addHistoryEntry(
          id: histId,
          profileId: profileId,
          playbackSessionId: sessionId ?? UuidUtils.v4(),
          contentKey: contentKey,
          titleId: titleId,
          episodeId: episodeId,
          stoppedAtMs: stoppedAt,
          durationMs: dur,
          fraction: frac,
          isCompleted: isComp,
          watchedAt: receivedAt,
          serverRevision: serverRev,
        );
        break;
      case 'preferences_update':
        await _dao.upsertPreferences(
          profileId,
          preferredAudioLanguage: payload['preferred_audio_language']?.toString(),
          preferredSubtitleLanguage: payload['preferred_subtitle_language']?.toString(),
          subtitlesEnabled: payload['subtitles_enabled'] as bool?,
          autoPlayNext: payload['auto_play_next'] as bool?,
          updatedAt: receivedAt,
          serverRevision: serverRev,
        );
        break;
    }
  }

  Future<void> _handleFullResync(String profileId) async {
    final gateway = _gateway;
    if (gateway == null) return;

    final snapshot = await gateway.getProfileSnapshot(profileId);
    final snapshotRev = (snapshot['snapshot_revision'] as num?)?.toInt() ?? 0;

    final favoritesRaw = (snapshot['favorites'] as List?) ?? [];
    final progressRaw = (snapshot['progress'] as List?) ?? [];
    final historyRaw = (snapshot['history'] as List?) ?? [];
    final prefsRaw = snapshot['preferences'] as Map?;

    final favorites = favoritesRaw.map((item) {
      final m = Map<String, dynamic>.from(item as Map);
      return LocalProfileFavoritesCompanion.insert(
        profileId: profileId,
        contentKey: m['content_key'] as String,
        titleId: Value(m['title_id'] as String?),
        isFavorite: Value(m['is_favorite'] == true),
        updatedAt: DateTime.now().toUtc(),
        serverRevision: Value((m['server_revision'] as num?)?.toInt() ?? 0),
      );
    }).toList();

    final progress = progressRaw.map((item) {
      final m = Map<String, dynamic>.from(item as Map);
      final lastWatched = m['last_watched_at'] != null
          ? DateTime.tryParse(m['last_watched_at'].toString())?.toUtc() ?? DateTime.now().toUtc()
          : DateTime.now().toUtc();
      final updated = m['updated_at'] != null
          ? DateTime.tryParse(m['updated_at'].toString())?.toUtc() ?? DateTime.now().toUtc()
          : DateTime.now().toUtc();

      return LocalProfilePlaybackProgressCompanion.insert(
        profileId: profileId,
        contentKey: m['content_key'] as String,
        playbackSessionId: Value(m['playback_session_id'] as String?),
        titleId: Value(m['title_id'] as String?),
        episodeId: Value(m['episode_id'] as String?),
        positionMs: Value((m['position_ms'] as num?)?.toInt() ?? 0),
        durationMs: Value((m['duration_ms'] as num?)?.toInt() ?? 0),
        fraction: Value((m['fraction'] as num?)?.toDouble() ?? 0.0),
        isCompleted: Value(m['is_completed'] == true),
        lastWatchedAt: lastWatched,
        updatedAt: updated,
        serverRevision: Value((m['server_revision'] as num?)?.toInt() ?? 0),
      );
    }).toList();

    final history = historyRaw.map((item) {
      final m = Map<String, dynamic>.from(item as Map);
      final watched = m['watched_at'] != null
          ? DateTime.tryParse(m['watched_at'].toString())?.toUtc() ?? DateTime.now().toUtc()
          : DateTime.now().toUtc();

      return LocalProfileHistoryCompanion.insert(
        id: m['id']?.toString() ?? UuidUtils.v4(),
        profileId: profileId,
        playbackSessionId: m['playback_session_id']?.toString() ?? '',
        contentKey: m['content_key'] as String,
        titleId: Value(m['title_id'] as String?),
        episodeId: Value(m['episode_id'] as String?),
        stoppedAtMs: Value((m['stopped_at_ms'] as num?)?.toInt() ?? 0),
        durationMs: Value((m['duration_ms'] as num?)?.toInt() ?? 0),
        fraction: Value((m['fraction'] as num?)?.toDouble() ?? 0.0),
        isCompleted: Value(m['is_completed'] == true),
        watchedAt: watched,
        serverRevision: Value((m['server_revision'] as num?)?.toInt() ?? 0),
      );
    }).toList();

    LocalProfilePreferencesCompanion? preferences;
    if (prefsRaw != null) {
      final p = Map<String, dynamic>.from(prefsRaw);
      preferences = LocalProfilePreferencesCompanion.insert(
        profileId: profileId,
        preferredAudioLanguage: Value(p['preferred_audio_language'] as String?),
        preferredSubtitleLanguage: Value(p['preferred_subtitle_language'] as String?),
        subtitlesEnabled: Value(p['subtitles_enabled'] == true),
        autoPlayNext: Value(p['auto_play_next'] != false),
        updatedAt: DateTime.now().toUtc(),
        serverRevision: Value((p['server_revision'] as num?)?.toInt() ?? 0),
      );
    }

    await _dao.applySnapshot(
      profileId: profileId,
      snapshotRevision: snapshotRev,
      favorites: favorites,
      progress: progress,
      history: history,
      preferences: preferences,
    );
  }

  // --- Sincronización Completa del Perfil Activo ---

  Future<SyncResult> syncProfile(String profileId) async {
    if (isGuestProfile(profileId)) {
      return SyncResult.skippedGuest();
    }
    if (_gateway == null) {
      return SyncResult.offline();
    }

    try {
      // Todos los lotes (el servidor acepta hasta 100 por llamada).
      for (var batch = 0; batch < 40; batch++) {
        final pushed = await pushPendingOperations(profileId);
        if (pushed.hasError || pushed.sentCount == 0) break;
      }
      await pullRemoteChanges(profileId);
      return const SyncResult(success: true);
    } catch (e) {
      return SyncResult.error(e.toString());
    }
  }
}
