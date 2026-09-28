import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../storage_service.dart';
import '../supabase_bootstrap.dart';

/// Acceso a la tabla profile_extras (ver la migración create_profile_extras).
abstract class ProfileExtrasStore {
  Future<void> upsert(List<Map<String, dynamic>> rows);
  Future<List<Map<String, dynamic>>> fetch(String profileId);
}

class SupabaseProfileExtrasStore implements ProfileExtrasStore {
  SupabaseProfileExtrasStore(this.client);

  final SupabaseClient client;

  @override
  Future<void> upsert(List<Map<String, dynamic>> rows) async {
    for (var i = 0; i < rows.length; i += 500) {
      final end = i + 500 > rows.length ? rows.length : i + 500;
      await client.from('profile_extras').upsert(rows.sublist(i, end));
    }
  }

  @override
  Future<List<Map<String, dynamic>>> fetch(String profileId) async {
    final rows = await client
        .from('profile_extras')
        .select('kind,key,value,updated_at')
        .eq('profile_id', profileId);
    return [for (final r in rows) Map<String, dynamic>.from(r)];
  }
}

/// "Me gusta", conteo de reproducciones (fila Tendencia sin TMDB) y ajustes
/// de reproducción, sincronizados por perfil entre equipos.
///
/// - Me gusta y ajustes: gana el cambio más reciente.
/// - Conteos: se queda el mayor de cada título.
///
/// Si la tabla todavía no existe en Supabase (migración sin ejecutar), no
/// hace nada: los datos quedan en el teléfono y suben cuando exista.
class ProfileExtrasSync {
  ProfileExtrasSync._();

  static bool _tableMissing = false;

  /// true si cambió algo que se ve (Me gusta, conteos o ajustes).
  static Future<bool> sync(
    String profileId, {
    required bool includeSettings,
    ProfileExtrasStore? store,
  }) async {
    final effective = store ?? _defaultStore();
    if (effective == null || _tableMissing) return false;
    try {
      final rows = _localRows(profileId, includeSettings: includeSettings);
      await effective.upsert(rows);
      final remote = await effective.fetch(profileId);
      final changed = await _applyRemote(
        profileId,
        remote,
        includeSettings: includeSettings,
      );
      debugPrint(
        '[SYNC] extras ${profileId.substring(0, 8)}: subidos ${rows.length}, '
        'en la nube ${remote.length}${changed ? ', cambios aplicados' : ''}',
      );
      return changed;
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST205' || e.code == '42P01') {
        _tableMissing = true;
        debugPrint(
          '[SYNC] falta la tabla profile_extras en Supabase: Me gusta, '
          'conteos y ajustes quedan en el teléfono hasta ejecutar la migración',
        );
      } else {
        debugPrint('[SYNC] extras: ${e.message}');
      }
      return false;
    } catch (e) {
      debugPrint('[SYNC] extras: ${e.runtimeType}');
      return false;
    }
  }

  static ProfileExtrasStore? _defaultStore() {
    final client = SupabaseBootstrap.instance.client;
    if (client == null || client.auth.currentUser == null) return null;
    return SupabaseProfileExtrasStore(client);
  }

  static List<Map<String, dynamic>> _localRows(
    String profileId, {
    required bool includeSettings,
  }) {
    final rows = <Map<String, dynamic>>[];
    Map<String, dynamic> row(
      String kind,
      String key,
      Object? value,
      DateTime at,
    ) => {
      'profile_id': profileId,
      'kind': kind,
      'key': key,
      'value': value,
      'updated_at': at.toUtc().toIso8601String(),
    };

    final liked = StorageService.loadLikedUrlsFor(profileId);
    final stamps = StorageService.loadLikeStampsFor(profileId);
    // "Me gusta" de antes de guardar fechas: cuentan como de hace mucho.
    final old = DateTime.utc(2020);
    for (final url in {...liked, ...stamps.keys}) {
      rows.add(row('like', url, liked.contains(url), stamps[url] ?? old));
    }
    final now = DateTime.now();
    for (final e in StorageService.loadWatchCountsFor(profileId).entries) {
      rows.add(row('watch_count', e.key, e.value, now));
    }
    if (includeSettings) {
      for (final key in StorageService.syncedSettingKeys) {
        final at = StorageService.settingChangedAt(key);
        final value = StorageService.getSetting(key);
        if (at == null || value == null) continue;
        rows.add(row('setting', key, value, at));
      }
    }
    return rows;
  }

  static Future<bool> _applyRemote(
    String profileId,
    List<Map<String, dynamic>> remote, {
    required bool includeSettings,
  }) async {
    final liked = StorageService.loadLikedUrlsFor(profileId);
    final stamps = StorageService.loadLikeStampsFor(profileId);
    final counts = StorageService.loadWatchCountsFor(profileId);
    var likesChanged = false;
    var countsChanged = false;
    var settingsChanged = false;

    for (final r in remote) {
      final key = r['key']?.toString() ?? '';
      final at = DateTime.tryParse(r['updated_at']?.toString() ?? '');
      if (key.isEmpty || at == null) continue;
      switch (r['kind']) {
        case 'like':
          final local = stamps[key];
          if (local != null && !at.isAfter(local)) continue;
          final isLiked = r['value'] == true;
          if (isLiked != liked.contains(key)) {
            isLiked ? liked.add(key) : liked.remove(key);
            likesChanged = true;
          }
          stamps[key] = at;
        case 'watch_count':
          final value = (r['value'] as num?)?.toInt() ?? 0;
          if (value > (counts[key] ?? 0)) {
            counts[key] = value;
            countsChanged = true;
          }
        case 'setting':
          if (!includeSettings ||
              !StorageService.syncedSettingKeys.contains(key)) {
            continue;
          }
          final local = StorageService.settingChangedAt(key);
          if (local != null && !at.isAfter(local)) continue;
          if (StorageService.getSetting(key) != r['value']) {
            settingsChanged = true;
          }
          await StorageService.applySyncedSetting(key, r['value'], at);
      }
    }
    if (likesChanged) await StorageService.saveLikedUrlsFor(profileId, liked);
    await StorageService.saveLikeStampsFor(profileId, stamps);
    if (countsChanged) {
      await StorageService.saveWatchCountsFor(profileId, counts);
    }
    return likesChanged || countsChanged || settingsChanged;
  }

  @visibleForTesting
  static void resetForTesting() => _tableMissing = false;
}
