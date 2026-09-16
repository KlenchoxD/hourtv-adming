import 'dart:async';

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
  Timer? _legacyLoadTimer;
  bool _revealed = false;

  @override
  void initState() {
    super.initState();
    _store = widget.store ?? ContentStore.instance;
    _store.addListener(_onStoreChanged);
    _catalogRepo =
        widget.catalogRepository ??
        (CatalogRepository.hasInstance ? CatalogRepository.instance : null);
    _catalogRepo?.addListener(_onCatalogChanged);

    // Drift is now the primary catalog. Defer the legacy cache parser until
    // after the first frame so it cannot block Home's initial layout/scroll.
    final repoHasUsableCache =
        _catalogRepo != null &&
        (_catalogRepo!.status == CatalogRepositoryStatus.ready ||
            _catalogRepo!.status == CatalogRepositoryStatus.offlineReady);
    if (repoHasUsableCache) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _legacyLoadTimer = Timer(const Duration(milliseconds: 1200), () {
          if (mounted) _store.ensureLoaded();
        });
      });
    } else {
      _store.ensureLoaded();
    }

    _checkReadiness();
  }

  @override
  void dispose() {
    _store.removeListener(_onStoreChanged);
    _catalogRepo?.removeListener(_onCatalogChanged);
    _legacyLoadTimer?.cancel();
    super.dispose();
  }

  void _onStoreChanged() {
    _checkReadiness();
  }

  void _onCatalogChanged() {
    _checkReadiness();
  }

  void _checkReadiness() {
    if (_revealed) return;

    final storeReady = _store.readiness.canEnterApp;
    final repo = _catalogRepo;
    final repoReady =
        repo == null ||
        repo.status == CatalogRepositoryStatus.ready ||
        repo.status == CatalogRepositoryStatus.readyEmpty ||
        repo.status == CatalogRepositoryStatus.offlineReady;

    final repoHasUsableCache =
        repo != null &&
        (repo.status == CatalogRepositoryStatus.ready ||
            repo.status == CatalogRepositoryStatus.offlineReady);

    // Drift already contains renderable catalog data. Do not keep the whole
    // app behind the legacy ContentStore cache parser; it can continue in the
    // background while Inicio renders the same lazy pages used by Buscar.
    if ((storeReady || repoHasUsableCache) && repoReady) {
      debugPrint(
        '[PERF_TTI] CatalogReadiness.canEnterApp: phase=${_store.readiness.phase} time=${DateTime.now().millisecondsSinceEpoch}',
      );
      if (mounted) {
        if (WidgetsBinding.instance.schedulerPhase ==
            SchedulerPhase.persistentCallbacks) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() => _revealed = true);
              debugPrint(
                '[PERF_TTI] FIRST_INTERACTIVE_FRAME: time=${DateTime.now().millisecondsSinceEpoch}',
              );
            }
          });
        } else {
          setState(() {
            _revealed = true;
          });
          WidgetsBinding.instance.addPostFrameCallback((_) {
            debugPrint(
              '[PERF_TTI] FIRST_INTERACTIVE_FRAME: time=${DateTime.now().millisecondsSinceEpoch}',
            );
          });
        }
      }
    } else {
      if (mounted) setState(() {});
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
    final repo = _catalogRepo;
    final repoReady =
        repo == null ||
        repo.status == CatalogRepositoryStatus.ready ||
        repo.status == CatalogRepositoryStatus.readyEmpty ||
        repo.status == CatalogRepositoryStatus.offlineReady;

    final repoHasUsableCache =
        repo != null &&
        (repo.status == CatalogRepositoryStatus.ready ||
            repo.status == CatalogRepositoryStatus.offlineReady);

    if (_revealed ||
        ((_store.readiness.canEnterApp || repoHasUsableCache) && repoReady)) {
      return widget.child;
    }

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
