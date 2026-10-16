import 'dart:async';

import 'package:flutter/material.dart';

import '../models/channel.dart';
import '../theme/app_theme.dart';
import 'ads/ad_config.dart';
import 'ads/levelplay_ads.dart';

/// Punto único para el anuncio previo a películas y episodios: un video de
/// Unity LevelPlay, precargado al abrir la app. En vivo nunca lleva anuncio.
class AdService {
  AdService._();

  /// Si el video aún no está listo al tocar Reproducir, se espera hasta esto.
  static const maxWait = Duration(seconds: 8);
  // Remote configuration is refreshed in the background, but must not hold
  // media startup hostage when the network or ad domains are slow.
  static const _configWaitBudget = Duration(seconds: 2);
  static Future<void>? _warmUpFuture;
  static Future<void>? _configRefreshFuture;
  static bool _warmUpComplete = false;
  static bool _configRefreshComplete = false;

  /// Al abrir la app: lee la configuración y precarga el video.
  static Future<void> warmUp() => _warmUpFuture ??= _initializeAds();

  static Future<void> _initializeAds() async {
    final refresh = AdConfig.load();
    _configRefreshFuture = refresh;
    unawaited(
      refresh.then(
        (_) {
          _configRefreshComplete = true;
          _startLevelPlayFromCurrentConfig();
        },
        onError: (Object error) {
          _configRefreshComplete = true;
          debugPrint('[ADS] config_refresh_error ${error.runtimeType}');
        },
      ),
    );
    try {
      // AdConfig.load applies the local cache before its remote request. Give
      // that refresh a short head start, then initialize from cached/default
      // values so a slow config endpoint does not consume the ad wait budget.
      await refresh.timeout(_configWaitBudget);
      _configRefreshComplete = true;
    } catch (e) {
      if (e is TimeoutException) {
        debugPrint('[ADS] config_refresh_deferred');
      } else {
        debugPrint('[ADS] warmup_error ${e.runtimeType}');
      }
    } finally {
      _startLevelPlayFromCurrentConfig();
      _warmUpComplete = true;
    }
  }

  static void _startLevelPlayFromCurrentConfig() {
    final config = AdConfig.current;
    if (!config.hasLevelPlay) return;
    try {
      LevelPlayAds.instance.start(
        appKey: config.levelPlayAppKey,
        interstitialId: config.levelPlayInterstitialId,
      );
    } catch (e) {
      debugPrint('[ADS] levelplay_start_error ${e.runtimeType}');
    }
  }

  static bool shouldShowPreroll(Channel channel) {
    return channel.type != MediaType.live;
  }

  static Future<void> showPreroll(BuildContext context, Channel channel) async {
    if (!shouldShowPreroll(channel) ||
        !LevelPlayAds.supported ||
        !context.mounted) {
      return;
    }
    debugPrint('[ADS] preroll_requested');
    final ads = LevelPlayAds.instance;
    if (_warmUpComplete &&
        _configRefreshComplete &&
        !AdConfig.current.hasLevelPlay) {
      return;
    }

    var ready =
        _warmUpComplete && AdConfig.current.hasLevelPlay && ads.isLoaded;
    if (!ready) {
      final cancelPreparation = Completer<void>();
      // Keep the player/server wheel behind an opaque, branded ad-loading
      // route until both remote config and the first LevelPlay ad are ready.
      ready =
          await Navigator.of(context, rootNavigator: true).push<bool>(
            PageRouteBuilder<bool>(
              opaque: true,
              pageBuilder: (_, _, _) => _WaitingForAd(
                preparation: _preparePreroll(
                  cancelSignal: cancelPreparation.future,
                ),
                onDispose: () {
                  if (!cancelPreparation.isCompleted) {
                    cancelPreparation.complete();
                  }
                },
              ),
              transitionDuration: const Duration(milliseconds: 120),
            ),
          ) ??
          false;
    }
    if (!context.mounted || !ready || !AdConfig.current.hasLevelPlay) {
      debugPrint('[ADS] preroll_without_ad');
      return;
    }
    if (!await ads.show()) debugPrint('[ADS] preroll_without_ad');
  }

  static Future<bool> _preparePreroll({Future<void>? cancelSignal}) async {
    final elapsed = Stopwatch()..start();
    try {
      await warmUp().timeout(maxWait);
    } on TimeoutException {
      debugPrint('[ADS] warmup_timeout');
      return false;
    }
    var remaining = maxWait - elapsed.elapsed;
    if (!AdConfig.current.hasLevelPlay && !_configRefreshComplete) {
      final refresh = _configRefreshFuture;
      if (refresh != null && remaining > Duration.zero) {
        try {
          await refresh.timeout(remaining);
        } on TimeoutException {
          debugPrint('[ADS] config_wait_timeout');
          return false;
        }
        remaining = maxWait - elapsed.elapsed;
      }
    }
    if (!AdConfig.current.hasLevelPlay) return false;
    final ads = LevelPlayAds.instance;
    if (ads.isLoaded) return true;
    if (remaining <= Duration.zero) return false;
    return ads.waitUntilLoaded(remaining, cancelSignal: cancelSignal);
  }
}

/// Controla la frecuencia del preroll durante una sola instancia del
/// reproductor. Cambiar episodio, servidor o mirror no crea otra sesión.
class PrerollSession {
  bool _shown = false;

  bool takeIfNeeded(Channel channel) {
    if (_shown || !AdService.shouldShowPreroll(channel)) return false;
    _shown = true;
    return true;
  }
}

class _WaitingForAd extends StatefulWidget {
  final Future<bool> preparation;
  final VoidCallback onDispose;

  const _WaitingForAd({required this.preparation, required this.onDispose});

  @override
  State<_WaitingForAd> createState() => _WaitingForAdState();
}

class _WaitingForAdState extends State<_WaitingForAd> {
  @override
  void dispose() {
    widget.onDispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    unawaited(_finishPreparation());
  }

  Future<void> _finishPreparation() async {
    var ready = false;
    try {
      ready = await widget.preparation;
    } catch (_) {}
    if (mounted) Navigator.of(context).pop(ready);
  }

  @override
  Widget build(BuildContext context) {
    return const PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RepaintBoundary(
                child: SizedBox.square(
                  dimension: 34,
                  child: CircularProgressIndicator(color: AppColors.accent),
                ),
              ),
              SizedBox(height: 18),
              Text(
                'Cargando publicidad…',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
