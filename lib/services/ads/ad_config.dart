import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../storage_service.dart';

/// Anuncios de Unity LevelPlay, controlados desde `app_config.json` del
/// repositorio del panel (hourtv-adming): se pueden cambiar las claves o
/// apagarlos sin publicar otra versión. Sin conexión se usa la última copia.
class AdConfig {
  const AdConfig({
    required this.levelPlay,
    required this.levelPlayAppKey,
    required this.levelPlayInterstitialId,
  });

  static const remoteUrl =
      'https://raw.githubusercontent.com/KlenchoxD/hourtv-adming/master/app_config.json';
  static const _cacheKey = 'adConfigCache';

  /// Valores de fábrica (también si el archivo remoto aún no existe).
  static const defaults = AdConfig(
    levelPlay: true,
    levelPlayAppKey: String.fromEnvironment('LEVELPLAY_APP_KEY'),
    levelPlayInterstitialId: String.fromEnvironment(
      'LEVELPLAY_INTERSTITIAL_ID',
    ),
  );

  static AdConfig current = defaults;

  final bool levelPlay;
  final String levelPlayAppKey;
  final String levelPlayInterstitialId;

  bool get hasLevelPlay =>
      levelPlay &&
      levelPlayAppKey.isNotEmpty &&
      levelPlayInterstitialId.isNotEmpty;

  @visibleForTesting
  static AdConfig fromJson(Map<String, dynamic> json) {
    final ads = json['ads'];
    if (ads is! Map) return defaults;
    String text(String key, String fallback) {
      final value = ads[key];
      return value is String && value.trim().isNotEmpty
          ? value.trim()
          : fallback;
    }

    return AdConfig(
      levelPlay: ads['levelPlay'] != false,
      levelPlayAppKey: text('levelPlayAppKey', defaults.levelPlayAppKey),
      levelPlayInterstitialId: text(
        'levelPlayInterstitialId',
        defaults.levelPlayInterstitialId,
      ),
    );
  }

  /// Carga la copia guardada y luego busca la versión actual.
  static Future<void> load() async {
    try {
      final cached = StorageService.getSetting(_cacheKey);
      if (cached is String) {
        current = fromJson(jsonDecode(cached) as Map<String, dynamic>);
      }
    } catch (_) {}
    try {
      final res = await http
          .get(Uri.parse(remoteUrl))
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return;
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      current = fromJson(json);
      await StorageService.saveSetting(_cacheKey, res.body);
    } catch (e) {
      debugPrint('[ADS] config ${e.runtimeType}');
    }
  }
}
