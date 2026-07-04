import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import '../models/channel.dart';
import '../models/m3u_list.dart';

class StorageService {
  static const String _channelsKey = 'channels';
  static const String _favoritesKey = 'favorites';
  static const String _listsKey = 'lists';
  static const String _recentKey = 'recent_channels';
  static const String _settingsKey = 'settings';

  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // ============ CHANNELS ============
  static Future<void> saveChannels(List<Channel> channels) async {
    final jsonList = channels.map((c) => c.toJson()).toList();
    await _prefs?.setString(_channelsKey, jsonEncode(jsonList));
  }

  static List<Channel> loadChannels() {
    final String? data = _prefs?.getString(_channelsKey);
    if (data == null) return [];
    try {
      final List<dynamic> jsonList = jsonDecode(data);
      return jsonList.map((json) => Channel.fromJson(json)).toList();
    } catch (e) {
      return [];
    }
  }

  // ============ FAVORITES ============
  static Future<void> saveFavorites(List<Channel> favorites) async {
    final jsonList = favorites.map((c) => c.toJson()).toList();
    await _prefs?.setString(_favoritesKey, jsonEncode(jsonList));
  }

  static List<Channel> loadFavorites() {
    final String? data = _prefs?.getString(_favoritesKey);
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
  static Future<void> saveRecent(Channel channel) async {
    final recent = loadRecent();
    recent.removeWhere((c) => c.url == channel.url);
    channel.lastWatched = DateTime.now();
    recent.insert(0, channel);
    if (recent.length > 20) recent.removeRange(20, recent.length);
    await _prefs?.setString(_recentKey, jsonEncode(recent.map((c) => c.toJson()).toList()));
  }

  static List<Channel> loadRecent() {
    final String? data = _prefs?.getString(_recentKey);
    if (data == null) return [];
    try {
      final List<dynamic> jsonList = jsonDecode(data);
      return jsonList.map((json) => Channel.fromJson(json)).toList();
    } catch (e) {
      return [];
    }
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
    await _prefs?.remove(_recentKey);
    await DefaultCacheManager().emptyCache();
  }
}
