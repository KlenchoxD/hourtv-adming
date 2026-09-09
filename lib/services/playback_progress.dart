import 'dart:async';
import 'dart:convert';

import '../models/channel.dart';
import 'tmdb_service.dart';
import 'storage_service.dart';

/// Una posicion guardada de un titulo VOD, estilo Netflix: posicion absoluta
/// (ms), duracion total (ms) y fraccion 0..1 reproducida.
class SavedPosition {
  final int positionMs;
  final int durationMs;
  final double fraction;

  const SavedPosition({
    required this.positionMs,
    required this.durationMs,
    required this.fraction,
  });

  /// Posicion desde la que reanudar: 0 si el titulo ya se vio completo
  /// (volver a abrirlo no debe saltar al final de los creditos).
  int get resumePositionMs =>
      isCompleted ? Duration.zero.inMilliseconds : positionMs;

  /// >=95% reproducido cuenta como terminado (los creditos finales no se
  /// exigen para "ver" una pelicula).
  bool get isCompleted => fraction >= 0.95;

  factory SavedPosition.fromMap(Map<String, dynamic> map) => SavedPosition(
    positionMs: (map['positionMs'] as num?)?.toInt() ?? 0,
    durationMs: (map['durationMs'] as num?)?.toInt() ?? 0,
    fraction: (map['fraction'] as num?)?.toDouble() ?? 0,
  );

  Map<String, dynamic> toMap() => {
    'positionMs': positionMs,
    'durationMs': durationMs,
    'fraction': fraction,
  };
}

/// Progreso de reproduccion por titulo, persistido por perfil.
///
/// La identidad del contenido NO es la URL del servidor (que cambia al
/// cambiar de mirror o al re-publicar el catalogo):
/// - Pelicula: id de catalogo (tvgId, ej. TMDB) o, si no existe, titulo
///   normalizado + anyo.
/// - Episodio: serie+temporada+episodio (tvgId `catalog:ID:T:E`) o, si no
///   existe, titulo de serie + identificador de episodio normalizado.
///
/// Retrocompatible: si no hay registro nuevo pero el titulo ya estaba en
/// "recientes" con solo `progressFraction`, se reconstruye la posicion
/// absoluta con la duracion conocida del catalogo.
class PlaybackProgress {
  PlaybackProgress._();

  static const _storageKey = 'playbackPositions';
  static final Map<String, Map<String, dynamic>> _cache = {};
  static Future<void> _writeChain = Future.value();

  /// Clave estable que identifica una pelicula o un episodio concretos.
  static String contentKey(Channel channel) {
    final id = channel.tvgId?.trim();
    final isSeries = channel.type == MediaType.series ||
        channel.forcedType == 'series' ||
        (id != null && id.startsWith('catalog:') && id.split(':').length >= 4);
    if (id != null && id.isNotEmpty) {
      return isSeries ? 'series:$id' : 'movie:$id';
    }
    // Sin id de catalogo: titulo normalizado (+anyo si hay) identifica la
    // pelicula aunque el servidor cambie.
    final title = TmdbService.normalizeTitle(channel.displayName);
    final year = channel.year?.trim();
    final movieKey = year == null || year.isEmpty
        ? title
        : '$title:$year';
    if (isSeries) {
      // Episodio: el nombre puede traer "1x02"/"S1E2" o el grupo "T2".
      final marker = _episodeMarker(channel);
      return 'series:$title:$marker';
    }
    return 'movie:$movieKey';
  }

  static String _episodeMarker(Channel channel) {
    final name = channel.name;
    final sxe = RegExp(
      r'(\d{1,2})\s*[xX]\s*(\d{1,3})',
    ).firstMatch(name);
    if (sxe != null) {
      return 'S${sxe.group(1)}E${sxe.group(2)}';
    }
    final srtEpi = RegExp(
      r'[Ss](\d{1,2})[\s._-]*[Ee](\d{1,3})',
    ).firstMatch(name);
    if (srtEpi != null) {
      return 'S${srtEpi.group(1)}E${srtEpi.group(2)}';
    }
    final capNum = RegExp(
      r'(?:cap[ií]tulo|episodio|ep\.?)\s*(\d{1,3})',
      caseSensitive: false,
    ).firstMatch(name);
    if (capNum != null) {
      final ep = capNum.group(1);
      final s = RegExp(r'(\d+)').firstMatch(channel.group ?? '')?.group(1) ?? '1';
      return 'S${s}E$ep';
    }
    final group = channel.group?.trim();
    if (group != null && group.isNotEmpty) {
      return '$group:${name.trim().toLowerCase()}';
    }
    return name.trim().toLowerCase();
  }

  /// Guarda la posicion absoluta de `channel`. Actualiza la memoria
  /// de inmediato y serializa la escritura en disco para evitar colisiones
  /// y condiciones de carrera.
  static Future<void> save(
    Channel channel, {
    required int positionMs,
    required int durationMs,
  }) {
    if (durationMs <= 0 || positionMs < 0) return Future.value();
    final profileKey = _profileStorageKey();
    final positions = _loadAll(profileKey);
    final fraction = (positionMs / durationMs).clamp(0.0, 1.0);
    positions[contentKey(channel)] = SavedPosition(
      positionMs: positionMs,
      durationMs: durationMs,
      fraction: fraction,
    ).toMap();

    final payload = jsonEncode(positions);
    final completer = Completer<void>();
    _writeChain = _writeChain.then((_) async {
      try {
        await StorageService.saveSetting(profileKey, payload);
        completer.complete();
      } catch (e, st) {
        completer.completeError(e, st);
      }
    }).catchError((_) {});
    return completer.future;
  }

  /// Posicion guardada de `channel`, o null si nunca se reprodujo.
  /// Consulta tambien los datos viejos (solo progressFraction en
  /// "recientes") para que un usuario existente no pierda su avance.
  static SavedPosition? load(Channel channel) {
    final key = contentKey(channel);
    final positions = _loadAll();
    final saved = positions[key];
    if (saved is Map<String, dynamic>) {
      return SavedPosition.fromMap(saved);
    }
    return _fromLegacyRecent(channel);
  }

  /// Borrado para tests / limpieza.
  static Future<void> clear() {
    final profileKey = _profileStorageKey();
    _cache[profileKey] = <String, dynamic>{};
    return StorageService.saveSetting(profileKey, '{}');
  }

  static String _profileStorageKey() =>
      '$_storageKey.profile.${StorageService.activeProfileId}';

  static Map<String, dynamic> _loadAll([String? key]) {
    final storageKey = key ?? _profileStorageKey();
    if (_cache.containsKey(storageKey)) {
      return _cache[storageKey]!;
    }
    final raw = StorageService.getSetting(storageKey)?.toString();
    if (raw == null || raw.trim().isEmpty) {
      final empty = <String, dynamic>{};
      _cache[storageKey] = empty;
      return empty;
    }
    try {
      final decoded = jsonDecode(raw);
      final map = decoded is Map<String, dynamic>
          ? Map<String, dynamic>.from(decoded)
          : <String, dynamic>{};
      _cache[storageKey] = map;
      return map;
    } catch (_) {
      final empty = <String, dynamic>{};
      _cache[storageKey] = empty;
      return empty;
    }
  }

  /// Datos de la version anterior: el titulo esta en "recientes" con solo
  /// `progressFraction`. Se reconstruye la posicion absoluta usando la
  /// duracion conocida del catalogo (string de minutos) o, si no hay, no se
  /// puede saber nada mejor que la fraccion (se devuelve igual: reanudar
  /// con fraccion es mejor que nada cuando la duracion real se conozca al
  /// inicializar el player).
  static SavedPosition? _fromLegacyRecent(Channel channel) {
    final recent = StorageService.loadRecent();
    final byUrl = {for (final item in recent) item.url: item};
    final legacy = byUrl[channel.url] ?? _findByContentKey(channel, recent);
    final fraction = legacy?.progressFraction;
    if (legacy == null || fraction == null || fraction <= 0) return null;
    if (fraction >= 0.95) {
      return SavedPosition(
        positionMs: 0,
        durationMs: 0,
        fraction: 1,
      );
    }
    final durationMs = _catalogDurationMs(channel);
    if (durationMs == null || durationMs <= 0) {
      // Duracion desconocida: fraccion sin posicion absoluta. El reproductor
      // la aplicara cuando conozca la duracion real del stream.
      return SavedPosition(positionMs: 0, durationMs: 0, fraction: fraction);
    }
    return SavedPosition(
      positionMs: (durationMs * fraction).round(),
      durationMs: durationMs,
      fraction: fraction,
    );
  }

  static Channel? _findByContentKey(
    Channel channel,
    List<Channel> recent,
  ) {
    final key = contentKey(channel);
    for (final item in recent) {
      if (contentKey(item) == key) return item;
    }
    return null;
  }

  /// La duracion en el catalogo viene en minutos como string ("120").
  static int? _catalogDurationMs(Channel channel) {
    final raw = channel.duration?.trim();
    if (raw == null || raw.isEmpty) return null;
    final minutes = double.tryParse(raw);
    if (minutes == null || minutes <= 0) return null;
    return (minutes * 60 * 1000).round();
  }

  /// Siguiente episodio de la misma serie y temporada, por identidad
  /// (tvgId o titulo+marcador), no por posicion de lista.
  static Channel? nextEpisode(Channel current, List<Channel> episodes) {
    final currentKey = contentKey(current);
    final index = episodes.indexWhere(
      (ep) => contentKey(ep) == currentKey,
    );
    if (index < 0 || index + 1 >= episodes.length) return null;
    return episodes[index + 1];
  }

  /// El episodio en el que la serie quedo: el ultimo con progreso sin
  /// terminar (>=95% cuenta como terminado y se salta). Si todos los
  /// episodios guardados estan completos o no hay progreso, el primero
  /// no visto; a falta de todo, el primero de la temporada.
  static Channel? nextUnfinishedEpisode(List<Channel> seasonEpisodes) {
    if (seasonEpisodes.isEmpty) return null;
    Channel? firstUnwatched;
    Channel? unfinished;
    for (final episode in seasonEpisodes) {
      final saved = load(episode);
      if (saved == null) {
        firstUnwatched ??= episode;
        continue;
      }
      if (!saved.isCompleted) {
        unfinished = episode;
        break;
      }
    }
    return unfinished ?? firstUnwatched ?? seasonEpisodes.first;
  }
}
