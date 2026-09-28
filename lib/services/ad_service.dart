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

  /// Al abrir la app: lee la configuración y precarga el video.
  static Future<void> warmUp() async {
    await AdConfig.load();
    final config = AdConfig.current;
    if (config.hasLevelPlay) {
      LevelPlayAds.instance.start(
        appKey: config.levelPlayAppKey,
        interstitialId: config.levelPlayInterstitialId,
      );
    }
  }

  static bool shouldShowPreroll(Channel channel) {
    return channel.type != MediaType.live;
  }

  static Future<void> showPreroll(BuildContext context, Channel channel) async {
    if (!shouldShowPreroll(channel) || !context.mounted) return;
    if (!AdConfig.current.hasLevelPlay) return;
    debugPrint('[ADS] preroll_requested');
    final ads = LevelPlayAds.instance;
    if (!ads.isLoaded) {
      // Aún cargando: se espera un poco con aviso, para no saltarse el
      // anuncio. Si Unity no tiene video (sin inventario o cuenta caída),
      // la película sigue: bloquearla dejaría la app inutilizable.
      await Navigator.of(context, rootNavigator: true).push<void>(
        PageRouteBuilder<void>(
          opaque: true,
          pageBuilder: (_, _, _) => const _WaitingForAd(),
          transitionDuration: const Duration(milliseconds: 120),
        ),
      );
    }
    if (!await ads.show()) debugPrint('[ADS] preroll_without_ad');
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
  const _WaitingForAd();

  @override
  State<_WaitingForAd> createState() => _WaitingForAdState();
}

class _WaitingForAdState extends State<_WaitingForAd> {
  @override
  void initState() {
    super.initState();
    unawaited(
      LevelPlayAds.instance.waitUntilLoaded(AdService.maxWait).then((_) {
        if (mounted) Navigator.of(context).pop();
      }),
    );
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
              SizedBox.square(
                dimension: 34,
                child: CircularProgressIndicator(color: AppColors.accent),
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
