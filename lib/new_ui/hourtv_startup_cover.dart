import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../mobile_ui/hourtv_mobile_components.dart';
import '../mobile_ui/hourtv_mobile_theme.dart';
import '../services/catalog/catalog_repository.dart';
import '../services/content_store.dart';

/// Tapadera de inicio que muestra los estados reales de carga del catálogo
/// (restauración de sesión, caché, sincronización remota y construcción de Inicio)
/// sin recurrir a temporizadores arbitrarios.
class HourTvStartupCover extends StatefulWidget {
  const HourTvStartupCover({
    super.key,
    required this.child,
    this.store,
    this.catalogRepository,
  });

  final Widget child;
  final ContentStore? store;
  final CatalogRepository? catalogRepository;

  @override
  State<HourTvStartupCover> createState() => _HourTvStartupCoverState();
}

class _HourTvStartupCoverState extends State<HourTvStartupCover> {
  late final ContentStore _store;
  CatalogRepository? _catalogRepo;
  Timer? _fallbackTimer;
  Timer? _revealTimer;
  // En pruebas (reloj falso, sin GPU) se conserva la regla anterior: se
  // entra apenas hay datos, sin esperar filas ni frames tapados.
  static final _isTest =
      !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');
  // Inicio se construye y dibuja DEBAJO de esta pantalla antes de quitarla:
  // su primer frame (el más pesado) y la subida de las primeras imágenes
  // ocurren tapados. Antes se mostraba a los ~0.4 s y en los 2 s siguientes
  // se rehacía tres veces (llegaba el catálogo, luego las filas de género)
  // mientras el usuario ya deslizaba. Así se ve como Xuper: aparece completo.
  bool _childMounted = false;
  bool _revealed = false;
  bool _warmingRows = false;

  @override
  void initState() {
    super.initState();
    _store = widget.store ?? ContentStore.instance;
    _store.addListener(_onStoreChanged);
    _catalogRepo =
        widget.catalogRepository ??
        (CatalogRepository.hasInstance ? CatalogRepository.instance : null);
    _catalogRepo?.addListener(_onCatalogChanged);

    // La lectura del catálogo ya corre en isolates: se empieza enseguida
    // (antes se retrasaba 1.2 s y el contenido cambiaba ya visible).
    _store.ensureLoaded();

    // Red de seguridad: si el catálogo tarda, se entra igual con lo que haya
    // en la base local, como antes.
    if (!_isTest) {
      _fallbackTimer = Timer(const Duration(seconds: 3), () {
        if (mounted && _repoUsable) _mountAndReveal();
      });
    }

    _checkReadiness();
  }

  @override
  void dispose() {
    _store.removeListener(_onStoreChanged);
    _catalogRepo?.removeListener(_onCatalogChanged);
    _fallbackTimer?.cancel();
    _revealTimer?.cancel();
    super.dispose();
  }

  void _onStoreChanged() {
    _checkReadiness();
  }

  void _onCatalogChanged() {
    _checkReadiness();
  }

  bool get _repoUsable {
    final repo = _catalogRepo;
    return repo == null ||
        repo.status == CatalogRepositoryStatus.ready ||
        repo.status == CatalogRepositoryStatus.readyEmpty ||
        repo.status == CatalogRepositoryStatus.offlineReady;
  }

  bool get _repoHasUsableCache {
    final repo = _catalogRepo;
    return repo != null &&
        (repo.status == CatalogRepositoryStatus.ready ||
            repo.status == CatalogRepositoryStatus.offlineReady);
  }

  void _checkReadiness() {
    if (_childMounted) return;
    if (_isTest) {
      if ((_store.readiness.canEnterApp || _repoHasUsableCache) &&
          _repoUsable) {
        _childMounted = true;
        _revealed = true;
      }
      if (mounted) setState(() {});
      return;
    }
    if (_store.readiness.canEnterApp && _repoUsable) {
      // Las filas Anime/K-Drama/Tendencia se calculan aquí, tapadas, para
      // que Inicio no las inserte después mientras se desliza.
      if (!_store.homeGenreRowsReady) {
        if (!_warmingRows) {
          _warmingRows = true;
          _store.warmHomeGenreRows().whenComplete(() {
            _warmingRows = false;
            if (mounted) _checkReadiness();
          });
        }
        return;
      }
      debugPrint(
        '[PERF_TTI] CatalogReadiness.canEnterApp: phase=${_store.readiness.phase} time=${DateTime.now().millisecondsSinceEpoch}',
      );
      _mountAndReveal();
    } else {
      if (mounted) setState(() {});
    }
  }

  void _mountAndReveal() {
    if (_childMounted || !mounted) return;
    _fallbackTimer?.cancel();
    void mountNow() {
      if (!mounted) return;
      setState(() => _childMounted = true);
      // Deja que Inicio dibuje un par de frames tapado (primer frame pesado
      // + primeras imágenes) y recién entonces se quita esta pantalla.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _revealTimer = Timer(const Duration(milliseconds: 350), () {
          if (!mounted) return;
          setState(() => _revealed = true);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            debugPrint(
              '[PERF_TTI] FIRST_INTERACTIVE_FRAME: time=${DateTime.now().millisecondsSinceEpoch}',
            );
          });
        });
      });
    }

    if (WidgetsBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) => mountNow());
    } else {
      mountNow();
    }
  }

  String _stageTitle(CatalogLoadPhase phase) => switch (phase) {
    CatalogLoadPhase.restoringSession => 'Restaurando sesión',
    CatalogLoadPhase.openingCache => 'Abriendo caché local',
    CatalogLoadPhase.syncingCatalog => 'Sincronizando catálogo inicial',
    CatalogLoadPhase.buildingHome => 'Construyendo Inicio',
    CatalogLoadPhase.ready ||
    CatalogLoadPhase.readyWithContent ||
    CatalogLoadPhase.readyEmpty ||
    CatalogLoadPhase.offlineReady => 'Listo',
    CatalogLoadPhase.failed => 'No se pudo cargar el catálogo',
  };

  @override
  Widget build(BuildContext context) {
    // Mismo Stack siempre: al quitar la cubierta Inicio no se reconstruye.
    return Stack(
      fit: StackFit.expand,
      children: [
        if (_childMounted) widget.child,
        if (!_revealed) _cover(context),
      ],
    );
  }

  Widget _cover(BuildContext context) {
    final repo = _catalogRepo;
    final readiness = _store.readiness;
    final repoFailed =
        repo != null && repo.status == CatalogRepositoryStatus.failed;

    if (readiness.phase == CatalogLoadPhase.failed || repoFailed) {
      return Scaffold(
        backgroundColor: HourTvMobileTokens.deepBlack,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const HourTvLogo(fontSize: 34),
                const SizedBox(height: 28),
                const Icon(
                  Icons.error_outline_rounded,
                  color: HourTvMobileTokens.error,
                  size: 44,
                ),
                const SizedBox(height: 16),
                const Text(
                  'No se pudo cargar el catálogo',
                  style: TextStyle(
                    color: HourTvMobileTokens.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  readiness.message ?? 'Verifica tu conexión a internet.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: HourTvMobileTokens.textMuted,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () {
                    if (_store.readiness.phase == CatalogLoadPhase.failed) {
                      _store.retry();
                    }
                    if (_catalogRepo != null &&
                        _catalogRepo!.status ==
                            CatalogRepositoryStatus.failed) {
                      _catalogRepo!.initialize();
                    }
                  },
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Reintentar'),
                  style: FilledButton.styleFrom(
                    backgroundColor: HourTvMobileTokens.emerald,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final isSyncingRepo =
        repo != null && repo.status == CatalogRepositoryStatus.syncing;
    final stageTitle = isSyncingRepo
        ? 'Sincronizando catálogo inicial'
        : _stageTitle(readiness.phase);
    final stageSubtitle = isSyncingRepo
        ? 'Sincronizando el catálogo más reciente...'
        : 'Un momento, estamos preparando el catálogo.';

    return Scaffold(
      backgroundColor: HourTvMobileTokens.deepBlack,
      body: HourTvBootLoading(title: stageTitle, subtitle: stageSubtitle),
    );
  }
}
