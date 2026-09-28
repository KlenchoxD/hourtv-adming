import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../database/daos/user_data_dao.dart';
import '../../models/channel.dart';
import '../content_store.dart';
import '../migration/guest_data_importer.dart';
import '../playback_progress.dart';
import '../profiles/supabase_profile_repository.dart';
import '../storage_service.dart';
import '../supabase_bootstrap.dart';
import 'profile_sync_engine.dart';
import 'uuid_utils.dart';

/// Une la sincronización con la nube y lo que muestran las pantallas.
///
/// Las pantallas leen favoritos, "Continuar viendo" y posiciones de
/// reanudación de SharedPreferences (por perfil); el motor de sincronización
/// sube y baja operaciones a la base local (Drift). Antes nada conectaba las
/// dos cosas: lo que bajaba de la nube nunca se veía y lo que había en el
/// teléfono (p. ej. perfiles importados) nunca subía.
///
/// 1. [backfill]: lo del teléfono que la nube no conoce se encola para subir.
/// 2. El motor sube y baja (push + pull).
/// 3. [apply]: lo que hay en la nube se reconstruye en SharedPreferences,
///    resolviendo cada clave de contenido contra el catálogo.
class ProfileCloudSync {
  ProfileCloudSync._();

  static final _inFlight = <String, Future<bool>>{};

  /// Sincroniza un perfil de la nube. true si cambió lo que se ve.
  static Future<bool> sync(String profileId) {
    final engine = ProfileSyncEngine.instance;
    if (engine == null || !UuidUtils.isUuid(profileId)) {
      return Future.value(false);
    }
    // Con llaves: `() => _inFlight.remove(id)` devolvería este mismo Future
    // y whenComplete lo esperaría a sí mismo (nunca terminaba).
    return _inFlight[profileId] ??= _run(engine, profileId).whenComplete(() {
      _inFlight.remove(profileId);
    });
  }

  static const _accountProfilesKey = 'cloudAccountProfileIds';

  static String _importSourceKey(String cloudId) => 'importedFrom.$cloudId';
  static String _driftImportedKey(String cloudId) => 'driftImported.$cloudId';

  /// De qué perfil de este teléfono salió un perfil de la nube importado.
  static Future<void> rememberImportSource({
    required String cloudProfileId,
    required String localProfileId,
  }) => StorageService.saveSetting(
    _importSourceKey(cloudProfileId),
    localProfileId,
  );

  /// Copia una sola vez, del perfil local de origen al de la nube, lo que
  /// vive en la base local (historial, avance, favoritos): de ahí salen las
  /// recomendaciones y el historial completo.
  static Future<void> _importLocalDataOnce(
    ProfileSyncEngine engine,
    String profileId,
  ) async {
    final source = StorageService.getSetting(_importSourceKey(profileId));
    if (source == null ||
        StorageService.getSetting(_driftImportedKey(profileId)) == true) {
      return;
    }
    final result = await GuestDataImporter(
      userDataDao: engine.userDataDao,
      syncEngine: engine,
      deviceId: engine.deviceId,
    ).importGuestData(
      targetProfileId: profileId,
      guestProfileId: source.toString(),
    );
    if (result.success) {
      await StorageService.saveSetting(_driftImportedKey(profileId), true);
      debugPrint(
        '[SYNC] ${profileId.substring(0, 8)}: importados '
        '${result.historyImported} del historial, '
        '${result.progressImported} avances, '
        '${result.favoritesImported} favoritos',
      );
    }
  }

  /// Perfiles importados antes de guardar su origen: se relacionan por
  /// nombre con el perfil local (solo si la cuenta eligió importar).
  static Future<void> _healImportSources(
    List<({String id, String name})> cloud,
  ) async {
    final locals = StorageService.loadProfiles();
    for (final profile in cloud) {
      if (StorageService.getSetting(_importSourceKey(profile.id)) != null) {
        continue;
      }
      final match = locals.where(
        (l) => l['name']?.toString().trim() == profile.name.trim(),
      );
      if (match.isEmpty) continue;
      await rememberImportSource(
        cloudProfileId: profile.id,
        localProfileId: match.first['id'].toString(),
      );
    }
  }

  /// Perfiles de la cuenta conocidos en este teléfono (los guarda el
  /// selector de perfiles cada vez que los lee de la nube).
  static Future<void> rememberAccountProfiles(Iterable<String> ids) =>
      StorageService.saveSetting(_accountProfilesKey, ids.toList());

  /// El perfil activo primero (al abrir la app o volver a ella) y después
  /// los demás perfiles de la cuenta, para que lo hecho en cualquiera llegue
  /// a todos los equipos.
  static Future<void> syncActive() async {
    if (!StorageService.isInitialized) return;
    final active = StorageService.activeProfileId;
    debugPrint('[SYNC] al abrir: perfil ${active.length > 8 ? active.substring(0, 8) : active}');
    // Primero la lista de perfiles: relaciona importaciones antes de subir.
    final accountProfiles = await _accountProfileIds();
    final changed = await sync(active);
    if (changed) ContentStore.instance.refreshProfileData();
    for (final id in accountProfiles) {
      if (id != active) await sync(id);
    }
    await ProfileSyncEngine.instance?.pushAllPending(except: active);
  }

  /// Perfiles de la cuenta: de la nube (incluye los creados en otros
  /// equipos) o, sin conexión, los últimos conocidos.
  static Future<List<String>> _accountProfileIds() async {
    final client = SupabaseBootstrap.instance.client;
    final userId = client?.auth.currentUser?.id;
    if (client != null && userId != null) {
      try {
        final profiles = await SupabaseProfileRepository(
          client: client,
          currentUserId: () => userId,
        ).list().timeout(const Duration(seconds: 15));
        final ids = [for (final p in profiles) p.id];
        await rememberAccountProfiles(ids);
        final accountId = client.auth.currentUser?.id;
        if (accountId != null &&
            StorageService.getSetting('localProfilesImportDecision.$accountId') ==
                'imported') {
          await _healImportSources([
            for (final p in profiles) (id: p.id, name: p.name),
          ]);
        }
        debugPrint('[SYNC] perfiles de la cuenta: ${ids.length}');
        return ids;
      } catch (e) {
        debugPrint('[SYNC] no se pudieron leer los perfiles: $e');
      }
    }
    debugPrint(
      '[SYNC] sin sesión para leer perfiles '
      '(cliente ${client != null}, usuario ${userId != null})',
    );
    final saved = StorageService.getSetting(_accountProfilesKey);
    return saved is List ? [for (final e in saved) e.toString()] : const [];
  }

  static Future<bool> _run(ProfileSyncEngine engine, String profileId) async {
    try {
      final dao = engine.userDataDao;
      await _importLocalDataOnce(engine, profileId);
      await backfill(engine, profileId);
      final result = await engine.syncProfile(profileId);
      final changed = await apply(dao, profileId);
      debugPrint(
        '[SYNC] ${profileId.substring(0, 8)}: '
        '${result.isOffline ? 'sin conexión con el servidor' : result.success ? 'ok' : result.errorMessage}'
        '${changed ? ', pantallas actualizadas' : ''}',
      );
      return changed;
    } catch (e) {
      debugPrint('[SYNC] $profileId falló: ${e.runtimeType}');
      return false;
    }
  }

  // ── 1. Teléfono -> cola de subida ────────────────────────────────────────

  /// Encola lo que está en el teléfono y la base de sincronización no tiene
  /// (favoritos y avance). Idempotente: lo ya conocido no se repite.
  static Future<void> backfill(
    ProfileSyncEngine engine,
    String profileId,
  ) async {
    final dao = engine.userDataDao;
    var queued = 0;
    // Ya en camino al servidor: no se repite.
    final pending = {
      for (final op in await dao.getPendingOperations(profileId, limit: 5000))
        op.contentKey,
    };

    // Favoritos guardados en la base pero que el servidor nunca confirmó
    // (p. ej. hechos sin conexión) y los que solo están en el teléfono.
    final favoriteRows = await dao.getAllFavoriteRows(profileId);
    for (final row in favoriteRows) {
      if (row.serverRevision > 0 || pending.contains(row.contentKey)) continue;
      await engine.recordFavorite(
        profileId: profileId,
        contentKey: row.contentKey,
        titleId: _uuidOrNull(row.titleId),
        isFavorite: row.isFavorite,
        updatedAt: row.updatedAt,
      );
      queued++;
    }
    final knownFavorites = {for (final row in favoriteRows) row.contentKey};
    for (final channel in StorageService.loadFavoritesFor(profileId)) {
      final key = PlaybackProgress.contentKey(channel);
      if (knownFavorites.contains(key)) continue;
      await engine.recordFavorite(
        profileId: profileId,
        contentKey: key,
        titleId: _uuidOrNull(channel.stableTitleId),
        isFavorite: true,
      );
      queued++;
    }

    // Avance: igual que favoritos.
    final progressRows = await dao.getAllProgress(profileId);
    for (final row in progressRows) {
      if (row.serverRevision > 0 || pending.contains(row.contentKey)) continue;
      if (row.durationMs <= 0) continue;
      await engine.recordProgress(
        profileId: profileId,
        contentKey: row.contentKey,
        titleId: _uuidOrNull(row.titleId),
        positionMs: row.positionMs,
        durationMs: row.durationMs,
        fraction: row.fraction,
        isCompleted: row.isCompleted,
        lastWatchedAt: row.lastWatchedAt,
        updatedAt: row.updatedAt,
      );
      queued++;
    }
    final knownProgress = {for (final row in progressRows) row.contentKey};
    final positions = PlaybackProgress.positionsFor(profileId);
    for (final channel in StorageService.loadRecentFor(profileId)) {
      if (channel.type == MediaType.live) continue;
      final key = PlaybackProgress.contentKey(channel);
      if (knownProgress.contains(key)) continue;
      // Sin posición exacta (datos viejos, o importados antes de copiarlas):
      // se estima con el porcentaje visto y la duración del catálogo.
      final saved = positions[key] ?? _estimatedPosition(channel);
      if (saved == null || saved.durationMs <= 0) continue;
      final watched = (channel.lastWatched ?? DateTime.now()).toUtc();
      await engine.recordProgress(
        profileId: profileId,
        contentKey: key,
        titleId: _uuidOrNull(channel.stableTitleId),
        positionMs: saved.positionMs,
        durationMs: saved.durationMs,
        fraction: saved.fraction,
        isCompleted: saved.isCompleted,
        lastWatchedAt: watched,
        updatedAt: watched,
      );
      queued++;
    }
    if (queued > 0) {
      debugPrint('[SYNC] ${profileId.substring(0, 8)}: $queued por subir');
    }
  }

  // ── 3. Base de sincronización -> pantallas ──────────────────────────────

  /// Reconstruye favoritos, "Continuar viendo" y posiciones del perfil a
  /// partir de lo sincronizado. true si algo cambió.
  static Future<bool> apply(UserDataDao dao, String profileId) async {
    final favoriteRows = await dao.getAllFavoriteRows(profileId);
    final progressRows = await dao.getAllProgress(profileId);
    if (favoriteRows.isEmpty && progressRows.isEmpty) return false;

    final localFavorites = StorageService.loadFavoritesFor(profileId);
    final localRecent = StorageService.loadRecentFor(profileId);
    final favByKey = {
      for (final c in localFavorites) PlaybackProgress.contentKey(c): c,
    };
    final recentByKey = {
      for (final c in localRecent) PlaybackProgress.contentKey(c): c,
    };

    final activeFavorites = favoriteRows.where((r) => r.isFavorite).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final recentRows = progressRows.take(40).toList();
    final missing = <String>{
      for (final r in activeFavorites)
        if (!favByKey.containsKey(r.contentKey)) r.contentKey,
      for (final r in recentRows)
        if (!recentByKey.containsKey(r.contentKey)) r.contentKey,
    };
    final catalog = missing.isEmpty
        ? const <String, Channel>{}
        : await _resolve(missing);

    // Favoritos: exactamente los de la nube (los quitados en otro equipo se
    // quitan aquí también). Lo que la nube no conoce ya se encoló en backfill.
    final removed = {
      for (final r in favoriteRows)
        if (!r.isFavorite) r.contentKey,
    };
    final newFavorites = <Channel>[
      for (final r in activeFavorites)
        if ((favByKey[r.contentKey] ?? catalog[r.contentKey]) case final c?)
          c..isFavorite = true,
      // Sin resolver todavía (catálogo sin cargar): se conservan.
      for (final e in favByKey.entries)
        if (!removed.contains(e.key) &&
            !activeFavorites.any((r) => r.contentKey == e.key))
          e.value,
    ];

    // "Continuar viendo": lo más reciente de cada equipo.
    final positions = PlaybackProgress.positionsFor(profileId);
    var positionsChanged = false;
    final merged = <String, Channel>{...recentByKey};
    for (final r in recentRows) {
      final channel = recentByKey[r.contentKey] ?? catalog[r.contentKey];
      if (channel == null) continue;
      final remoteWhen = r.lastWatchedAt.toLocal();
      final localWhen = recentByKey[r.contentKey]?.lastWatched;
      if (localWhen != null && !remoteWhen.isAfter(localWhen)) continue;
      // Copia: los objetos de la lista local se comparan después.
      merged[r.contentKey] = Channel.fromJson(channel.toJson())
        ..progressFraction = r.fraction
        ..lastWatched = remoteWhen;
      if (r.durationMs > 0) {
        positions[r.contentKey] = SavedPosition(
          positionMs: r.positionMs,
          durationMs: r.durationMs,
          fraction: r.fraction,
        );
        positionsChanged = true;
      }
    }
    final newRecent = merged.values.toList()
      ..sort(
        (a, b) => (b.lastWatched ?? DateTime(0)).compareTo(
          a.lastWatched ?? DateTime(0),
        ),
      );
    if (newRecent.length > 20) newRecent.removeRange(20, newRecent.length);

    var changed = false;
    if (!_sameChannels(newFavorites, localFavorites)) {
      await StorageService.saveFavoritesFor(profileId, newFavorites);
      changed = true;
    }
    if (!_sameChannels(newRecent, localRecent)) {
      await StorageService.saveRecentFor(profileId, newRecent);
      changed = true;
    }
    if (positionsChanged) {
      await PlaybackProgress.savePositionsFor(profileId, positions);
      changed = true;
    }
    return changed;
  }

  /// Busca en el catálogo (películas, series y sus episodios) los títulos de
  /// [keys]. Cede el hilo cada pocos milisegundos para no trabar la UI.
  static Future<Map<String, Channel>> _resolve(Set<String> keys) async {
    final store = ContentStore.instance;
    final found = <String, Channel>{};
    final watch = Stopwatch()..start();
    Future<void> visit(Channel c) async {
      final key = PlaybackProgress.contentKey(c);
      if (keys.contains(key)) found[key] = c;
      if (watch.elapsedMilliseconds > 6) {
        await Future<void>.delayed(Duration.zero);
        watch.reset();
      }
    }

    for (final c in store.all) {
      if (found.length == keys.length) return found;
      await visit(c);
    }
    for (final series in store.series) {
      for (final episode in series.episodes ?? const <Channel>[]) {
        if (found.length == keys.length) return found;
        await visit(episode);
      }
    }
    return found;
  }

  static SavedPosition? _estimatedPosition(Channel channel) {
    final fraction = channel.progressFraction;
    final minutes = _durationMinutes(channel.duration);
    if (fraction == null || fraction <= 0 || minutes == null) return null;
    final durationMs = minutes * 60000;
    return SavedPosition(
      positionMs: (durationMs * fraction).round(),
      durationMs: durationMs,
      fraction: fraction,
    );
  }

  /// "107 min", "1 h 40 min", "1h 40m" -> minutos.
  static int? _durationMinutes(String? raw) {
    final text = raw?.toLowerCase().trim() ?? '';
    if (text.isEmpty) return null;
    final hours = RegExp(r'(\d+)\s*h').firstMatch(text);
    final mins = RegExp(r'(\d+)\s*m').firstMatch(text);
    if (hours == null && mins == null) {
      return int.tryParse(RegExp(r'\d+').firstMatch(text)?.group(0) ?? '');
    }
    final total =
        (int.tryParse(hours?.group(1) ?? '') ?? 0) * 60 +
        (int.tryParse(mins?.group(1) ?? '') ?? 0);
    return total > 0 ? total : null;
  }

  static bool _sameChannels(List<Channel> a, List<Channel> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].url != b[i].url ||
          a[i].progressFraction != b[i].progressFraction ||
          a[i].lastWatched != b[i].lastWatched) {
        return false;
      }
    }
    return true;
  }

  static String? _uuidOrNull(String? id) => UuidUtils.isUuid(id) ? id : null;
}
