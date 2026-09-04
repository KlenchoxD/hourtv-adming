import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import '../models/channel.dart';
import '../models/m3u_list.dart';
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
  static SharedPreferences? _prefs;

  /// Si todavia no se eligio perfil (instalacion nueva, o tras cerrar
  /// sesion): la raiz de la app usa esto para mostrar el selector de
  /// perfil en vez de la app normal, estilo "¿Quien ve HourTV?" de Netflix.
  static final ValueNotifier<bool> hasChosenProfile = ValueNotifier<bool>(
    false,
  );

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    // Un (re)init cuenta como estado nuevo: sin esto, un segundo init() con
    // otras SharedPreferences (tests, o un futuro "restablecer app") podia
    // seguir sirviendo el cache de "recientes" de la instancia anterior.
    _recentCache = null;
    _recentCacheProfileId = null;
    await _migrateLegacyProfileData();
    hasChosenProfile.value = getSetting(
      _hasChosenProfileKey,
      defaultValue: false,
    ) as bool;
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
    final jsonList = channels.map((channel) => channel.toJson()).toList();
    final encoded = await compute(_encodeJsonList, jsonList);
    await _prefs?.setString(_channelsKey, encoded);
  }

  static Future<List<Channel>> loadChannels() async {
    final String? data = _prefs?.getString(_channelsKey);
    if (data == null) return [];
    try {
      final jsonList = await compute(_decodeJsonList, data);
      return jsonList
          .map((json) => Channel.fromJson(Map<String, dynamic>.from(json)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ============ SERIES ============
  static Future<void> saveSeries(List<XtreamSeries> series) async {
    final jsonList = series.map((item) => item.toJson()).toList();
    final encoded = await compute(_encodeJsonList, jsonList);
    await _prefs?.setString(_seriesKey, encoded);
  }

  static Future<List<XtreamSeries>> loadSeries() async {
    final String? data = _prefs?.getString(_seriesKey);
    if (data == null) return [];
    try {
      final jsonList = await compute(_decodeJsonList, data);
      return jsonList
          .map((json) => XtreamSeries.fromJson(Map<String, dynamic>.from(json)))
          .toList();
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

  static Map<String, dynamic> loadSettings() {
    final String? data = _prefs?.getString(_settingsKey);
    if (data == null) return {};
    try {
      return Map<String, dynamic>.from(jsonDecode(data));
    } catch (e) {
      return {};
    }
  }

  static dynamic getSetting(String key, {dynamic defaultValue}) {
    return loadSettings()[key] ?? defaultValue;
  }

  static Future<void> clearAll() async {
    await _prefs?.clear();
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

String _encodeJsonList(List<Map<String, dynamic>> values) => jsonEncode(values);

List<Map<String, dynamic>> _decodeJsonList(String value) {
  final decoded = jsonDecode(value) as List<dynamic>;
  return decoded.whereType<Map>().map(Map<String, dynamic>.from).toList();
}
