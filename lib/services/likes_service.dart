import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/channel.dart';
import 'playback_progress.dart';
import 'storage_service.dart';
import 'supabase_bootstrap.dart';
import 'sync/uuid_utils.dart';

/// "Me gusta" de películas y series: el del perfil y el total global (cuántos
/// perfiles de todos los usuarios le dieron Me gusta).
class LikesService {
  LikesService._();

  /// Clave estable del título, igual para todos los usuarios: no depende del
  /// servidor del video (que cambia al reemplazar un enlace caído).
  static String keyFor(Channel channel) {
    if (channel.url.startsWith('hourtv-series:')) {
      final id = Uri.decodeComponent(channel.url.split(':').last);
      return 'series:$id';
    }
    return PlaybackProgress.contentKey(channel);
  }

  static bool isLiked(Channel channel) {
    final liked = StorageService.loadLikedUrls();
    // Los Me gusta de antes se guardaban por url.
    return liked.contains(keyFor(channel)) || liked.contains(channel.url);
  }

  /// Marca o quita el Me gusta y lo sube enseguida (el total de los demás
  /// usuarios cambia al momento, sin esperar a cerrar la app).
  static Future<bool> toggle(Channel channel) async {
    final key = keyFor(channel);
    if (StorageService.loadLikedUrls().contains(channel.url)) {
      // Pasar el Me gusta viejo (por url) a la clave estable.
      await StorageService.toggleLiked(channel.url);
      await StorageService.toggleLiked(key);
    }
    final liked = await StorageService.toggleLiked(key);
    _cache.remove(key);
    await _push(key, liked);
    return liked;
  }

  static Future<void> _push(String key, bool liked) async {
    final profileId = StorageService.activeProfileId;
    final client = SupabaseBootstrap.instance.client;
    if (!UuidUtils.isUuid(profileId) ||
        client == null ||
        client.auth.currentUser == null) {
      return;
    }
    try {
      await client.from('profile_extras').upsert({
        'profile_id': profileId,
        'kind': 'like',
        'key': key,
        'value': liked,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e) {
      // Sin conexión: sube en la próxima sincronización.
      debugPrint('[LIKES] no se subió: ${e.runtimeType}');
    }
  }

  static final _cache = <String, int>{};

  /// Total global de Me gusta del título; null si no se pudo consultar.
  static Future<int?> count(Channel channel) async {
    final key = keyFor(channel);
    final cached = _cache[key];
    if (cached != null) return cached;
    final client = SupabaseBootstrap.instance.client;
    if (client == null) return null;
    try {
      final rows = await client.rpc(
        'get_like_counts',
        params: {
          'p_keys': [key],
        },
      );
      var total = 0;
      if (rows is List) {
        for (final r in rows) {
          if (r is Map && r['key'] == key) {
            total = (r['likes'] as num?)?.toInt() ?? 0;
          }
        }
      }
      _cache[key] = total;
      return total;
    } on PostgrestException catch (e) {
      debugPrint('[LIKES] ${e.message}');
      return null;
    } catch (_) {
      return null;
    }
  }

  static List<(String, int)>? _top;
  static DateTime _topAt = DateTime(0);

  /// Títulos con más Me gusta de todos los usuarios (clave, total), de más a
  /// menos. Vacío si no hay conexión o la función aún no está en el servidor.
  static Future<List<(String, int)>> topLiked({int limit = 40}) async {
    final cached = _top;
    if (cached != null &&
        DateTime.now().difference(_topAt) < const Duration(minutes: 10)) {
      return cached;
    }
    final client = SupabaseBootstrap.instance.client;
    if (client == null) return const [];
    try {
      final rows = await client.rpc(
        'get_top_liked',
        params: {'p_limit': limit},
      );
      final top = <(String, int)>[
        if (rows is List)
          for (final r in rows)
            if (r is Map && r['key'] is String)
              (r['key'] as String, (r['likes'] as num?)?.toInt() ?? 0),
      ];
      _top = top;
      _topAt = DateTime.now();
      return top;
    } catch (e) {
      debugPrint('[LIKES] top ${e.runtimeType}');
      return const [];
    }
  }

  /// Canales de [candidates] en el orden de [top] (los que no están en el
  /// catálogo visible, p. ej. en un perfil infantil, se omiten).
  static List<Channel> rank(
    List<(String, int)> top,
    Iterable<Channel> candidates,
  ) {
    if (top.isEmpty) return const [];
    final byKey = <String, Channel>{};
    for (final channel in candidates) {
      byKey.putIfAbsent(keyFor(channel), () => channel);
      // Me gusta antiguos se guardaban por URL.
      byKey.putIfAbsent(channel.url, () => channel);
    }
    final seen = <String>{};
    return [
      for (final (key, likes) in top)
        if (likes > 0 && byKey[key] != null && seen.add(byKey[key]!.url))
          byKey[key]!,
    ];
  }

  /// "1", "12", "1,2 mil", "3,4 M".
  static String format(int count) {
    String short(double v) {
      final text = v >= 10 ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
      return text.endsWith('.0')
          ? text.substring(0, text.length - 2)
          : text.replaceAll('.', ',');
    }

    if (count >= 1000000) return '${short(count / 1000000)} M';
    if (count >= 1000) return '${short(count / 1000)} mil';
    return '$count';
  }
}
