import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import '../models/channel.dart';
import '../models/m3u_list.dart';
import 'playback_progress.dart';
import 'sync/profile_sync_engine.dart';
import 'sync/uuid_utils.dart';
import 'xtream_service.dart';

class StorageService {
  static const String _channelsKey = 'channels';
  static const String _seriesKey = 'series';
  static const String _favoritesKey = 'favorites';
  static const String _likedKey = 'liked_channels';
  static const String _listsKey = 'lists';
  static const String _recentKey = 'recent_channels';
  static const String _settingsKey = 'settings';
  static const String _profileMigrationKey = 'profileDataNamespacedV1';
  static const String _activeProfileIdKey = 'activeProfileId';
  static const String _primaryProfileIdKey = 'primaryProfileId';
  static const String _hasChosenProfileKey = 'hasChosenProfile';
  static const String _stableDeviceIdKey = 'hourtv_stable_device_id_v1';
  static SharedPreferences? _prefs;

  static bool get isInitialized => _prefs != null;

  static String getOrCreateDeviceId() {
    final existing = getSetting(_stableDeviceIdKey)?.toString().trim();
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }
    final newId = UuidUtils.v4();
    unawaited(saveSetting(_stableDeviceIdKey, newId));
    return newId;
  }

  /// Si todavia no se eligio perfil (instalacion nueva, o tras cerrar
  /// sesion): la raiz de la app usa esto para mostrar el selector de
  /// perfil en vez de la app normal, estilo "¿Quien ve HourTV?" de Netflix.
  static final ValueNotifier<bool> hasChosenProfile = ValueNotifier<bool>(
    false,
  );

  static Future<void> init({Directory? blobDir}) async {
    _prefs = await SharedPreferences.getInstance();
    // Un (re)init cuenta como estado nuevo: sin esto, un segundo init() con
    // otras SharedPreferences (tests, o un futuro "restablecer app") podia
    // seguir sirviendo el cache de "recientes" de la instancia anterior.
    _recentCache = null;
    _recentCacheProfileId = null;
    // Los widget tests corren con reloj falso donde el I/O real de archivos
    // nunca completa: ahí se sigue usando prefs salvo que pasen blobDir.
    _blobDir = blobDir;
    if (_blobDir == null &&
        !kIsWeb &&
        !Platform.environment.containsKey('FLUTTER_TEST')) {
      try {
        _blobDir = await getApplicationSupportDirectory();
      } catch (_) {}
    }
    if (_blobDir != null) await _moveBlobsOutOfPrefs();
    await _migrateLegacyProfileData();
    hasChosenProfile.value = getSetting(
      _hasChosenProfileKey,
      defaultValue: false,
    ) as bool;
  }

  // Catálogo, canales y series pesan varios MB. En SharedPreferences,
  // getInstance() los cargaba todos por el canal nativo antes del primer
  // frame (~5 s en un Moto G24). Viven en archivos; en web, en prefs.
  static Directory? _blobDir;

  static File _blobFile(String key) => File('${_blobDir!.path}/$key.json');

  static Future<String?> _readBlob(String key) async {
    if (_blobDir == null) return _prefs?.getString(key);
    try {
      // readAsString decodifica UTF-8 de varios MB en el hilo principal
      // (~76 ms al arrancar): se lee y decodifica en un isolate.
      final path = _blobFile(key).path;
      return await compute((_) {
        final file = File(path);
        return file.existsSync() ? file.readAsStringSync() : null;
      }, null);
    } catch (_) {
      return null;
    }
  }

  static Future<void> _writeBlob(String key, String content) async {
    if (_blobDir == null) {
      await _prefs?.setString(key, content);
      return;
    }
    // Codificar varios MB a UTF-8 en el hilo principal trababa el arranque.
    final path = _blobFile(key).path;
    await Isolate.run(() {
      final tmp = File('$path.tmp')..writeAsStringSync(content, flush: true);
      tmp.renameSync(path);
    });
  }

  static Future<void> _moveBlobsOutOfPrefs() async {
    for (final key in [_channelsKey, _seriesKey, _remoteSourcesKey]) {
      final legacy = _prefs?.getString(key);
      if (legacy == null) continue;
      if (!_blobFile(key).existsSync()) await _writeBlob(key, legacy);
      await _prefs?.remove(key);
    }
    final inSettings = _decodedSettings()[_remoteSourcesKey];
    if (inSettings is String) {
      if (!_blobFile(_remoteSourcesKey).existsSync()) {
        await _writeBlob(_remoteSourcesKey, inSettings);
      }
      final settings = loadSettings()..remove(_remoteSourcesKey);
      await _prefs?.setString(_settingsKey, jsonEncode(settings));
    }
  }

  static Future<void> markProfileChosen() async {
    await saveSetting(_hasChosenProfileKey, true);
    hasChosenProfile.value = true;
  }

  /// Al cerrar sesion: vuelve a exigir elegir perfil antes de entrar de
  /// nuevo a la app.
  static Future<void> clearChosenProfile() async {
    await saveSetting(_hasChosenProfileKey, false);
    hasChosenProfile.value = false;
  }

  static String get activeProfileId {
    final settings = loadSettings();
    final stored = settings[_activeProfileIdKey]?.toString().trim();
    if (stored != null && stored.isNotEmpty) return stored;
    return _profileIdForName(
      settings['activeProfile']?.toString() ?? 'Invitado',
    );
  }

  static String get primaryProfileId {
    final stored = loadSettings()[_primaryProfileIdKey]?.toString().trim();
    return stored == null || stored.isEmpty ? activeProfileId : stored;
  }

  static Future<void> setActiveProfile(String name) async {
    final settings = loadSettings();
    settings['activeProfile'] = name;
    settings[_activeProfileIdKey] = _profileIdForName(name);
    settings[_primaryProfileIdKey] ??= settings[_activeProfileIdKey];
    await _prefs?.setString(_settingsKey, jsonEncode(settings));
  }

  // ============ PERFILES CREADOS ============
  // A diferencia de setActiveProfile (arriba, un nombre suelto sin registro
  // propio), estos son perfiles reales que el usuario crea con nombre y
  // caricatura elegidos: se guardan en una lista y quedan disponibles para
  // volver a elegirlos despues, como los perfiles de Netflix.
  static const String _profilesKey = 'userProfiles';

  static List<Map<String, dynamic>> loadProfiles() {
    final raw = _prefs?.getString(_profilesKey);
    if (raw == null) return [];
    try {
      return List<Map<String, dynamic>>.from(
        (jsonDecode(raw) as List).map((e) => Map<String, dynamic>.from(e)),
      );
    } catch (_) {
      return [];
    }
  }

  static Future<void> _saveProfiles(List<Map<String, dynamic>> profiles) =>
      _prefs?.setString(_profilesKey, jsonEncode(profiles)) ??
      Future.value();

  static Future<Map<String, dynamic>> createProfile({
    required String name,
    required String avatarId,
    required bool isKids,
  }) async {
    final profiles = loadProfiles();
    final profile = <String, dynamic>{
      'id': DateTime.now().microsecondsSinceEpoch.toString(),
      'name': name,
      'avatarId': avatarId,
      'isKids': isKids,
    };
    profiles.add(profile);
    await _saveProfiles(profiles);
    await _activateProfileRecord(profile);
    return profile;
  }

  static Future<void> setActiveProfileById(String id) async {
    final match = loadProfiles().where((p) => p['id'] == id);
    if (match.isEmpty) return;
    await _activateProfileRecord(match.first);
  }

  static Future<bool> updateProfile({
    required String id,
    required String name,
    required String avatarId,
    required bool isKids,
  }) async {
    final profiles = loadProfiles();
    final index = profiles.indexWhere((p) => p['id'] == id);
    if (index == -1) return false;
    profiles[index]['name'] = name;
    profiles[index]['avatarId'] = avatarId;
    profiles[index]['isKids'] = isKids;
    await _saveProfiles(profiles);
    if (activeProfileId == id) {
      await _activateProfileRecord(profiles[index]);
    }
    return true;
  }

  static Future<bool> deleteProfile(String id) async {
    final profiles = loadProfiles();
    final index = profiles.indexWhere((p) => p['id'] == id);
    if (index == -1) return false;
    profiles.removeAt(index);
    await _saveProfiles(profiles);
    if (activeProfileId == id) {
      if (profiles.isNotEmpty) {
        await _activateProfileRecord(profiles.first);
      } else {
        await clearChosenProfile();
      }
    }
    return true;
  }

  static const String _cloudAccountIdKey = 'cloudAccountId';
  static const String _cloudProfileIdKey = 'cloudProfileId';

  static String? get cloudAccountId => getSetting(_cloudAccountIdKey)?.toString();
  static String? get cloudProfileId => getSetting(_cloudProfileIdKey)?.toString();

  static Future<void> setCloudProfileContext({
    required String accountId,
    required String profileId,
    required String name,
    required String avatarId,
    required bool isKids,
  }) async {
    final settings = loadSettings();
    settings[_cloudAccountIdKey] = accountId;
    settings[_cloudProfileIdKey] = profileId;
    settings['activeProfile'] = name;
    settings[_activeProfileIdKey] = profileId;
    settings['activeProfileAvatarId'] = avatarId;
    settings['activeProfileIsKids'] = isKids;
    settings[_primaryProfileIdKey] ??= profileId;
    await _prefs?.setString(_settingsKey, jsonEncode(settings));
  }

  static Future<void> clearCloudProfileContext() async {
    final settings = loadSettings();
    settings.remove(_cloudAccountIdKey);
    settings.remove(_cloudProfileIdKey);
    settings.remove('activeProfile');
    settings.remove(_activeProfileIdKey);
    settings.remove('activeProfileAvatarId');
    settings.remove('activeProfileIsKids');
    // Persistido, no solo en memoria: si no, tras reiniciar la app se
    // volvía a entrar sin pasar por "¿Quién está viendo?" y sin perfil.
    settings[_hasChosenProfileKey] = false;
    hasChosenProfile.value = false;
    await _prefs?.setString(_settingsKey, jsonEncode(settings));
  }

  static Future<void> _activateProfileRecord(
    Map<String, dynamic> profile,
  ) async {
    final settings = loadSettings();
    settings['activeProfile'] = profile['name'];
    settings[_activeProfileIdKey] = profile['id'];
    settings['activeProfileAvatarId'] = profile['avatarId'];
    settings['activeProfileIsKids'] = profile['isKids'];
    settings[_primaryProfileIdKey] ??= profile['id'];
    await _prefs?.setString(_settingsKey, jsonEncode(settings));
  }

  static String get activeProfileAvatarId =>
      getSetting('activeProfileAvatarId', defaultValue: '').toString();

  static bool get activeProfileIsKids =>
      getSetting('activeProfileIsKids', defaultValue: false) == true;

  static String _profileKey(String base) => '$base.profile.$activeProfileId';

  /// Copia todos los datos de un perfil (favoritos, "Me gusta", recientes,
  /// conteos...) a otro. No pisa lo que el destino ya tenga.
  static Future<void> copyProfileData({
    required String fromProfileId,
    required String toProfileId,
  }) async {
    final prefs = _prefs;
    if (prefs == null || fromProfileId == toProfileId) return;
    final suffix = '.profile.$fromProfileId';
    for (final key in prefs.getKeys().toList()) {
      if (!key.endsWith(suffix)) continue;
      final target =
          '${key.substring(0, key.length - suffix.length)}.profile.$toProfileId';
      if (prefs.containsKey(target)) continue;
      final value = prefs.get(key);
      switch (value) {
        case String v:
          await prefs.setString(target, v);
        case List v:
          await prefs.setStringList(target, v.cast<String>());
        case bool v:
          await prefs.setBool(target, v);
        case int v:
          await prefs.setInt(target, v);
        case double v:
          await prefs.setDouble(target, v);
      }
    }
    if (activeProfileId == toProfileId) _recentCache = null;
  }

  static Future<void> _migrateLegacyProfileData() async {
    final settings = loadSettings();
    final profileId =
        (settings[_activeProfileIdKey]?.toString().trim().isNotEmpty ?? false)
        ? settings[_activeProfileIdKey].toString()
        : _profileIdForName(
            settings['activeProfile']?.toString() ?? 'Invitado',
          );
    settings[_activeProfileIdKey] = profileId;
    settings[_primaryProfileIdKey] ??= profileId;

    if (settings[_profileMigrationKey] != true) {
      final legacyFavorites = _prefs?.getString(_favoritesKey);
      final legacyRecent = _prefs?.getString(_recentKey);
      final favoriteKey = '$_favoritesKey.profile.$profileId';
      final recentKey = '$_recentKey.profile.$profileId';
      if (legacyFavorites != null &&
          !(_prefs?.containsKey(favoriteKey) ?? false)) {
        await _prefs?.setString(favoriteKey, legacyFavorites);
      }
      if (legacyRecent != null && !(_prefs?.containsKey(recentKey) ?? false)) {
        await _prefs?.setString(recentKey, legacyRecent);
      }
      settings[_profileMigrationKey] = true;
    }
    await _prefs?.setString(_settingsKey, jsonEncode(settings));
  }

  static String _profileIdForName(String name) {
    final value = name.trim().toLowerCase();
    if (value == 'cinéfilo' || value == 'cinefilo') return 'cinefilo';
    if (value == 'kids') return 'kids';
    if (value == 'invitado') return 'invitado';
    final normalized = value
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return normalized.isEmpty ? 'invitado' : normalized;
  }

  // ============ CHANNELS ============
  static Future<void> saveChannels(List<Channel> channels) async {
    final encoded = await compute(_encodeChannels, channels);
    await _writeBlob(_channelsKey, encoded);
  }

  static Future<List<Channel>> loadChannels() async {
    final data = await _readBlob(_channelsKey);
    if (data == null) return [];
    try {
      return await compute(_decodeChannels, data);
    } catch (_) {
      return [];
    }
  }

  // ============ SERIES ============
  static Future<void> saveSeries(List<XtreamSeries> series) async {
    final encoded = await compute(_encodeSeries, series);
    await _writeBlob(_seriesKey, encoded);
  }

  static Future<List<XtreamSeries>> loadSeries() async {
    final data = await _readBlob(_seriesKey);
    if (data == null) return [];
    try {
      return await compute(_decodeSeries, data);
    } catch (_) {
      return [];
    }
  }

  // ============ FAVORITES ============
  static Future<void> saveFavorites(List<Channel> favorites) async {
    final jsonList = favorites.map((c) => c.toJson()).toList();
    await _prefs?.setString(_profileKey(_favoritesKey), jsonEncode(jsonList));
  }

  static List<Channel> loadFavorites() {
    final String? data = _prefs?.getString(_profileKey(_favoritesKey));
    if (data == null) return [];
    try {
      final List<dynamic> jsonList = jsonDecode(data);
      return jsonList.map((json) => Channel.fromJson(json)).toList();
    } catch (e) {
      return [];
    }
  }

  static Future<bool> toggleFavorite(Channel channel) async {
    final favorites = loadFavorites();
    final index = favorites.indexWhere((c) => c.url == channel.url);
    final bool nowFavorite;
    if (index >= 0) {
      favorites.removeAt(index);
      nowFavorite = false;
    } else {
      favorites.insert(0, channel);
      nowFavorite = true;
    }
    channel.isFavorite = nowFavorite;
    await saveFavorites(favorites);

    final syncEngine = ProfileSyncEngine.instance;
    if (syncEngine != null) {
      unawaited(
        syncEngine.recordFavorite(
          profileId: activeProfileId,
          contentKey: PlaybackProgress.contentKey(channel),
          titleId: channel.stableTitleId,
          isFavorite: nowFavorite,
        ),
      );
    }

    return nowFavorite;
  }

  // ============ LIKES ("Me gusta", distinto de Favoritos/Mi lista) ============
  static Set<String> loadLikedUrls() {
    final data = _prefs?.getStringList(_profileKey(_likedKey));
    return data?.toSet() ?? <String>{};
  }

  static Future<bool> toggleLiked(String channelUrl) async {
    final liked = loadLikedUrls();
    final bool nowLiked;
    if (liked.remove(channelUrl)) {
      nowLiked = false;
    } else {
      liked.add(channelUrl);
      nowLiked = true;
    }
    await _prefs?.setStringList(_profileKey(_likedKey), liked.toList());
    return nowLiked;
  }

  // ============ M3U LISTS ============
  static Future<void> saveLists(List<M3UList> lists) async {
    final jsonList = lists.map((l) => l.toJson()).toList();
    await _prefs?.setString(_listsKey, jsonEncode(jsonList));
  }

  static List<M3UList> loadLists() {
    final String? data = _prefs?.getString(_listsKey);
    if (data == null) return [];
    try {
      final List<dynamic> jsonList = jsonDecode(data);
      return jsonList.map((json) => M3UList.fromJson(json)).toList();
    } catch (e) {
      return [];
    }
  }

  // ============ RECENT ============
  // Cache en memoria del "recientes" ya decodificado: `updateRecentProgress`
  // se llama cada ~10s mientras se reproduce (para "Continuar viendo"), y
  // antes eso volvia a leer y decodificar los 20 canales completos desde
  // SharedPreferences en cada tick -> ese jsonDecode+20x Channel.fromJson
  // sincronico en el isolate de UI era el traba/lag breve que se notaba en
  // algunas peliculas. Con el cache, solo se decodifica una vez por perfil.
  static List<Channel>? _recentCache;
  static String? _recentCacheProfileId;

  static Future<void> _persistRecent(List<Channel> recent) async {
    _recentCache = recent;
    _recentCacheProfileId = activeProfileId;
    await _prefs?.setString(
      _profileKey(_recentKey),
      jsonEncode(recent.map((c) => c.toJson()).toList()),
    );
  }

  static Future<void> saveRecent(Channel channel) async {
    final recent = loadRecent();
    recent.removeWhere((c) => c.url == channel.url);
    channel.lastWatched = DateTime.now();
    recent.insert(0, channel);
    if (recent.length > 20) recent.removeRange(20, recent.length);
    await _persistRecent(recent);
    await _incrementWatchCount(channel.url);
  }

  // ============ WATCH COUNTS ============
  // Cuenta real de reproducciones por titulo (no un numero inventado):
  // alimenta la fila "Tendencia" del Inicio con lo que este perfil de
  // verdad ha visto mas, en vez de simular popularidad.
  static const String _watchCountsKey = 'watchCounts';

  static Future<void> _incrementWatchCount(String url) async {
    final counts = loadWatchCounts();
    counts[url] = (counts[url] ?? 0) + 1;
    await _prefs?.setString(
      _profileKey(_watchCountsKey),
      jsonEncode(counts),
    );
  }

  static Map<String, int> loadWatchCounts() {
    final raw = _prefs?.getString(_profileKey(_watchCountsKey));
    if (raw == null) return {};
    try {
      return Map<String, int>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return {};
    }
  }

  static List<Channel> loadRecent() {
    final profileId = activeProfileId;
    final cached = _recentCache;
    if (cached != null && _recentCacheProfileId == profileId) return cached;
    final String? data = _prefs?.getString(_profileKey(_recentKey));
    List<Channel> result;
    if (data == null) {
      result = [];
    } else {
      try {
        final List<dynamic> jsonList = jsonDecode(data);
        result = jsonList.map((json) => Channel.fromJson(json)).toList();
      } catch (e) {
        result = [];
      }
    }
    _recentCache = result;
    _recentCacheProfileId = profileId;
    return result;
  }

  /// Actualiza cuanto se avanzo en un titulo ya presente en "recientes" (lo
  /// agrega `saveRecent` al arrancar la reproduccion). Alimenta "Continuar
  /// viendo" con progreso real en vez de un valor inventado.
  static Future<void> updateRecentProgress(String url, double fraction) async {
    final recent = loadRecent();
    final index = recent.indexWhere((c) => c.url == url);
    if (index < 0) return;
    recent[index].progressFraction = fraction;
    await _persistRecent(recent);
  }

  // ============ SETTINGS ============
  static Future<void> saveSetting(String key, dynamic value) async {
    final settings = loadSettings();
    settings[key] = value;
    await _prefs?.setString(_settingsKey, jsonEncode(settings));
  }

  static String? _settingsRaw;
  static Map<String, dynamic> _settingsCache = const {};

  // getSetting se llama cientos de veces por frame (control parental, perfil
  // activo...). Decodificar el JSON en cada llamada se llevaba ~99% del CPU
  // del arranque. Se decodifica solo cuando cambia el string guardado.
  static Map<String, dynamic> _decodedSettings() {
    final String? data = _prefs?.getString(_settingsKey);
    if (identical(data, _settingsRaw)) return _settingsCache;
    _settingsRaw = data;
    try {
      _settingsCache = data == null
          ? const {}
          : Map<String, dynamic>.from(jsonDecode(data));
    } catch (e) {
      _settingsCache = const {};
    }
    return _settingsCache;
  }

  static Map<String, dynamic> loadSettings() =>
      Map<String, dynamic>.of(_decodedSettings());

  static dynamic getSetting(String key, {dynamic defaultValue}) {
    return _decodedSettings()[key] ?? defaultValue;
  }

  // El catálogo remoto (varios MB) vive en su propia clave: dentro de
  // 'settings' se re-codificaba entero en cada saveSetting.
  static const String _remoteSourcesKey = 'remoteSourcesCache';

  static Future<String?> loadRemoteSourcesCache() =>
      _readBlob(_remoteSourcesKey);

  static Future<void> saveRemoteSourcesCache(String content) =>
      _writeBlob(_remoteSourcesKey, content);

  static Future<void> clearAll() async {
    await _prefs?.clear();
    if (_blobDir != null) {
      for (final key in [_channelsKey, _seriesKey, _remoteSourcesKey]) {
        final file = _blobFile(key);
        if (await file.exists()) await file.delete();
      }
    }
  }

  /// Limpia el cache de imagenes de logos y el historial de canales recientes.
  /// No borra listas, favoritos ni ajustes.
  static Future<void> clearCache() async {
    await _prefs?.remove(_profileKey(_recentKey));
    _recentCache = null;
    _recentCacheProfileId = null;
    await DefaultCacheManager().emptyCache();
  }
}

// Todo (JSON + conversión a objetos) corre en el isolate: con miles de títulos
// el map a Channel/XtreamSeries en el hilo principal trababa el arranque.
List<Map<String, dynamic>> _decodeJsonList(String value) {
  final decoded = jsonDecode(value) as List<dynamic>;
  return decoded.whereType<Map>().map(Map<String, dynamic>.from).toList();
}

String _encodeChannels(List<Channel> values) =>
    jsonEncode(values.map((c) => c.toJson()).toList());

List<Channel> _decodeChannels(String value) => [
  for (final json in _decodeJsonList(value))
    Channel.fromJson(json)..warmDerivedFields(),
];

String _encodeSeries(List<XtreamSeries> values) =>
    jsonEncode(values.map((s) => s.toJson()).toList());

List<XtreamSeries> _decodeSeries(String value) =>
    _decodeJsonList(value).map(XtreamSeries.fromJson).toList();
