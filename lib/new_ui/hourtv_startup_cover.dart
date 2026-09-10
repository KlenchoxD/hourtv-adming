import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../mobile_ui/hourtv_mobile_components.dart';
import '../mobile_ui/hourtv_mobile_theme.dart';
import '../services/content_store.dart';

/// Tapadera de inicio que muestra los estados reales de carga del catálogo
/// (restauración de sesión, caché, sincronización remota y construcción de Inicio)
/// sin recurrir a temporizadores arbitrarios.
class HourTvStartupCover extends StatefulWidget {
  const HourTvStartupCover({
    super.key,
    required this.child,
    this.store,
  });

  final Widget child;
  final ContentStore? store;

  @override
  State<HourTvStartupCover> createState() => _HourTvStartupCoverState();
}

class _HourTvStartupCoverState extends State<HourTvStartupCover> {
  late final ContentStore _store;
  bool _revealed = false;

  @override
  void initState() {
    super.initState();
    _store = widget.store ?? ContentStore.instance;
    _store.addListener(_onStoreChanged);
    _store.ensureLoaded();
    _checkReadiness();
  }

  @override
  void dispose() {
    _store.removeListener(_onStoreChanged);
    super.dispose();
  }

  void _onStoreChanged() {
    _checkReadiness();
  }

  void _checkReadiness() {
    if (_revealed) return;
    if (_store.readiness.canEnterApp) {
      if (mounted) {
        if (WidgetsBinding.instance.schedulerPhase ==
            SchedulerPhase.persistentCallbacks) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _revealed = true);
          });
        } else {
          setState(() {
            _revealed = true;
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
    CatalogLoadPhase.ready || CatalogLoadPhase.offlineReady => 'Listo',
    CatalogLoadPhase.failed => 'No se pudo cargar el catálogo',
  };

  @override
  Widget build(BuildContext context) {
    if (_revealed || _store.readiness.canEnterApp) {
      return widget.child;
    }

    final readiness = _store.readiness;
    if (readiness.phase == CatalogLoadPhase.failed) {
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
                if (readiness.canRetry) ...[
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () => _store.retry(),
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
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: HourTvMobileTokens.deepBlack,
      body: HourTvBootLoading(
        title: _stageTitle(readiness.phase),
        subtitle: 'Un momento, estamos preparando el catálogo.',
      ),
    );
  }
}
