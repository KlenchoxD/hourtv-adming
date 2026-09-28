import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:unity_levelplay_mediation/unity_levelplay_mediation.dart';

/// Video a pantalla completa de Unity LevelPlay (lo que usa MHDPlus). Se
/// precarga al abrir la app para mostrarlo al instante antes de la película.
class LevelPlayAds
    implements LevelPlayInitListener, LevelPlayInterstitialAdListener {
  LevelPlayAds._();

  static final LevelPlayAds instance = LevelPlayAds._();

  LevelPlayInterstitialAd? _ad;
  bool _started = false;
  bool _loaded = false;
  Completer<bool>? _showing;
  Completer<void>? _loadedSignal;
  Duration _retry = const Duration(seconds: 30);

  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  void start({required String appKey, required String interstitialId}) {
    if (_started || !supported) return;
    _started = true;
    _ad = LevelPlayInterstitialAd(adUnitId: interstitialId)..setListener(this);
    unawaited(
      LevelPlay.init(
        initRequest: LevelPlayInitRequest(appKey: appKey),
        initListener: this,
      ).catchError((Object e) {
        debugPrint('[ADS] levelplay_init_error ${e.runtimeType}');
      }),
    );
  }

  bool get isLoaded => _loaded;

  /// Espera a que haya un video listo (como máximo [limit]).
  Future<bool> waitUntilLoaded(Duration limit) async {
    if (_loaded) return true;
    if (_ad == null) return false;
    // Se pide uno ya, sin esperar al reintento programado.
    if (_loadedSignal == null) _load();
    final signal = _loadedSignal ??= Completer<void>();
    try {
      await signal.future.timeout(limit);
    } on TimeoutException {
      return false;
    }
    return _loaded;
  }

  /// Muestra el video si ya está cargado; true si el usuario lo vio.
  Future<bool> show() async {
    final ad = _ad;
    if (ad == null || !_loaded) return false;
    try {
      if (!await ad.isAdReady()) return false;
      _loaded = false;
      final shown = _showing = Completer<bool>();
      await ad.showAd();
      // Se espera a que lo cierre (o falle) antes de seguir a la película.
      return await shown.future.timeout(
        const Duration(minutes: 3),
        onTimeout: () => true,
      );
    } catch (e) {
      debugPrint('[ADS] levelplay_show_error ${e.runtimeType}');
      return false;
    } finally {
      _showing = null;
      _load(); // el siguiente queda listo desde ya
    }
  }

  void _load() {
    final ad = _ad;
    if (ad == null) return;
    unawaited(ad.loadAd().catchError((Object _) {}));
  }

  void _finish(bool shown) {
    final showing = _showing;
    if (showing != null && !showing.isCompleted) showing.complete(shown);
  }

  @override
  void onInitSuccess(LevelPlayConfiguration configuration) {
    debugPrint('[ADS] levelplay_ready');
    _load();
  }

  @override
  void onInitFailed(LevelPlayInitError error) {
    debugPrint('[ADS] levelplay_init_failed ${error.errorCode}');
  }

  @override
  void onAdLoaded(LevelPlayAdInfo adInfo) {
    _loaded = true;
    final signal = _loadedSignal;
    _loadedSignal = null;
    if (signal != null && !signal.isCompleted) signal.complete();
    _retry = const Duration(seconds: 30);
    debugPrint('[ADS] levelplay_loaded');
  }

  @override
  void onAdLoadFailed(LevelPlayAdError error) {
    _loaded = false;
    debugPrint('[ADS] levelplay_no_fill ${error.errorCode}');
    // Sin anuncio disponible: reintentar cada vez más espaciado (máx. 5 min).
    Timer(_retry, _load);
    final next = _retry * 2;
    _retry = next > const Duration(minutes: 5)
        ? const Duration(minutes: 5)
        : next;
  }

  @override
  void onAdDisplayed(LevelPlayAdInfo adInfo) {
    debugPrint('[ADS] levelplay_displayed');
  }

  @override
  void onAdDisplayFailed(LevelPlayAdError error, LevelPlayAdInfo adInfo) {
    _finish(false);
  }

  @override
  void onAdClosed(LevelPlayAdInfo adInfo) {
    _finish(true);
  }

  @override
  void onAdClicked(LevelPlayAdInfo adInfo) {}

  @override
  void onAdInfoChanged(LevelPlayAdInfo adInfo) {}
}
