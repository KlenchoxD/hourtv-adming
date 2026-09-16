import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'mobile_ui/hourtv_mobile_shell.dart';
import 'mobile_ui/hourtv_mobile_theme.dart';
import 'new_ui/hourtv_auth_gate.dart';
import 'new_ui/hourtv_cloud_profile_gate.dart';
import 'new_ui/hourtv_new_shell.dart';
import 'new_ui/hourtv_profile_gate.dart';
import 'new_ui/hourtv_settings_update_page.dart';
import 'new_ui/hourtv_startup_cover.dart';
import 'services/content_store.dart';
import 'services/device_type.dart';
import 'services/iptv_server_service.dart';
import 'services/profiles/supabase_profile_repository.dart';
import 'services/storage_service.dart';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'services/sync/profile_sync_engine.dart';
import 'services/recommendations/recommendation_engine.dart';
import 'services/catalog/catalog_infrastructure.dart';
import 'services/supabase_bootstrap.dart';
import 'services/supabase_config.dart';
import 'services/update_service.dart';

void main() {
  final tBoot = DateTime.now().millisecondsSinceEpoch;
  debugPrint('[PERF_TTI] APP_BOOT: time=$tBoot');
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    ErrorWidget.builder = (details) => _FatalError(details.exceptionAsString());

    final tDartStart = DateTime.now().millisecondsSinceEpoch;
    debugPrint('[PERF_TTI] DART_INIT_START: time=$tDartStart');

    // Inicializaciones concurrentes tempranas (almacenamiento, Supabase, dispositivo y ruta de BD)
    final tInitStart = DateTime.now().millisecondsSinceEpoch;
    final docsDirFuture =
        getApplicationDocumentsDirectory().catchError((_) => Directory.systemTemp);
    final storageFuture = StorageService.init().catchError((_) {});
    final deviceProfileFuture = DeviceProfile.warmUp().catchError((_) {});
    final supabaseFuture = SupabaseBootstrap.instance
        .initialize(SupabaseConfig.fromEnvironment())
        .catchError((e, st) {
      debugPrint('Error al inicializar Supabase: ${e.runtimeType}');
      if (kDebugMode) debugPrintStack(stackTrace: st);
    });

    // Iniciar apertura de Drift tan pronto como la ruta de documentos esté disponible,
    // solapando la apertura de SQLite en segundo plano con la inicialización de Supabase y SharedPreferences.
    final docsDir = await docsDirFuture;
    final tDriftStart = DateTime.now().millisecondsSinceEpoch;
    final Future<CatalogInfrastructure?> driftFuture =
        initializeCatalogInfrastructure(
      databaseFile: File('${docsDir.path}/hourtv_catalog.db'),
    ).then<CatalogInfrastructure?>((infra) => infra).catchError((e, st) {
      debugPrint('Error al inicializar infraestructura de catálogo: ${e.runtimeType}');
      if (kDebugMode) debugPrintStack(stackTrace: st);
      return null;
    });

    // Esperar almacenamiento y sesión
    await Future.wait([storageFuture, supabaseFuture, deviceProfileFuture]);
    final tSessionEnd = DateTime.now().millisecondsSinceEpoch;
    debugPrint('[PERF_TTI] SESSION_RESTORE_DONE: time=$tSessionEnd elapsedMs=${tSessionEnd - tInitStart}');

    // Esperar finalización de Drift (que corrió en paralelo)
    final catalogInfra = await driftFuture;
    final tDriftEnd = DateTime.now().millisecondsSinceEpoch;
    debugPrint('[PERF_TTI] DRIFT_OPEN_DONE: time=$tDriftEnd elapsedMs=${tDriftEnd - tDriftStart}');

    // Configuración de pantalla no bloqueante
    unawaited(SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]));
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Color(0xFF0C0C0E),
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );

    final tDartInitEnd = DateTime.now().millisecondsSinceEpoch;
    debugPrint('[PERF_TTI] DART_INIT_DONE: time=$tDartInitEnd totalDartMs=${tDartInitEnd - tDartStart}');
    runApp(HourTVApp(catalogInfrastructure: catalogInfra));

    if (StorageService.getSetting('iptv_server_enabled', defaultValue: false) ==
        true) {
      unawaited(IptvServerService.instance.start().catchError((_) {}));
    }
  }, (error, stack) => runApp(HourTVApp(fatalError: '$error')));
}

class HourTVApp extends StatelessWidget {
  const HourTVApp({super.key, this.fatalError, this.catalogInfrastructure});
  final String? fatalError;
  final CatalogInfrastructure? catalogInfrastructure;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HourTV',
      debugShowCheckedModeBanner: false,
      theme: HourTvMobileTheme.build(),
      // Respeta "Texto grande" del sistema, pero acotado: esta UI tiene
      // carruseles y grillas de alto fijo que se rompen mucho antes de
      // llegar al 200% que Android permite. Sin este limite, activar la
      // accesibilidad de texto grande dejaria la app inusable en vez de
      // mas legible.
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        return MediaQuery(
          data: mediaQuery.copyWith(
            textScaler: mediaQuery.textScaler.clamp(
              minScaleFactor: 0.85,
              maxScaleFactor: 1.3,
            ),
          ),
          child: child!,
        );
      },
      home: fatalError == null
          ? _ResponsiveRoot(catalogInfrastructure: catalogInfrastructure)
          : _FatalError(fatalError!),
    );
  }
}

class _ResponsiveRoot extends StatelessWidget {
  const _ResponsiveRoot({this.catalogInfrastructure});
  final CatalogInfrastructure? catalogInfrastructure;

  @override
  Widget build(BuildContext context) {
    // Recien instalada o tras "Cerrar sesión": obliga a elegir perfil antes
    // de dejar entrar a la app, como el selector de Netflix. Se escucha con
    // un ValueNotifier (no un Navigator.push) para que cerrar sesion desde
    // cualquier pantalla profunda solo tenga que resetear el flag y volver
    // a la primera ruta; esta raiz reacciona sola.
    return HourTvAuthGate(
      guestChild: ValueListenableBuilder<bool>(
        valueListenable: StorageService.hasChosenProfile,
        builder: (context, hasChosenProfile, _) {
          if (!hasChosenProfile) return const HourTvProfileGate();
          return HourTvStartupCover(
            child: _AppShell(catalogInfrastructure: catalogInfrastructure),
          );
        },
      ),
      authenticatedChild: ValueListenableBuilder<bool>(
        valueListenable: StorageService.hasChosenProfile,
        builder: (context, hasChosenProfile, _) {
          if (!hasChosenProfile) {
            return HourTvCloudProfileGate(
              repository: SupabaseProfileRepository(
                client: SupabaseBootstrap.instance.client,
                currentUserId: () =>
                    SupabaseBootstrap.instance.client?.auth.currentUser?.id,
              ),
              onSignOut: () async {
                await ProfileSyncEngine.instance?.flush();
                await SupabaseBootstrap.instance.authGateway.signOut();
                await StorageService.clearCloudProfileContext();
                ContentStore.instance.refreshProfileData();
              },
            );
          }
          return HourTvStartupCover(
            child: _AppShell(catalogInfrastructure: catalogInfrastructure),
          );
        },
      ),
    );
  }
}

/// La app normal, mas la revisión de actualizaciones automática: antes
/// habia que entrar a Perfil > Actualizaciones y tocar "Buscar" a mano para
/// enterarse de un release nuevo. Ahora se revisa sola una vez por sesión
/// al entrar, y si hay una version mas nueva se avisa con un dialogo en vez
/// de dejarlo escondido en un menu.
class _AppShell extends StatefulWidget {
  const _AppShell({this.catalogInfrastructure});
  final CatalogInfrastructure? catalogInfrastructure;

  @override
  State<_AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<_AppShell> with WidgetsBindingObserver {
  var _checkedForUpdate = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(ContentStore.instance.maybeRefresh());
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      unawaited(ProfileSyncEngine.instance?.flush());
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_checkedForUpdate) return;
    _checkedForUpdate = true;
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => unawaited(_checkForUpdate()),
    );
  }

  Future<void> _checkForUpdate() async {
    final result = await UpdateService.instance.checkForUpdate();
    if (!mounted) return;
    if (result case UpdateAvailable(:final info)) {
      UpdateService.instance.hasUpdateAvailable.value = true;
      _showUpdateDialog(info);
    }
  }

  void _showUpdateDialog(UpdateInfo info) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF111113),
        title: const Text(
          'Actualización disponible',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'HourTV ${info.version} ya está lista para instalar.',
          style: const TextStyle(color: Color(0xFFA6A6B0)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Más tarde'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => HourTvUpdatePage(preloadedInfo: info),
                ),
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF00C781),
              foregroundColor: Colors.black,
            ),
            child: const Text('ACTUALIZAR'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<DeviceType?>(
      valueListenable: DeviceProfile.overrideType,
      builder: (context, _, _) {
        final isPhone = DeviceProfile.isPhone(context);
        final size = MediaQuery.sizeOf(context);

        final recEngine = widget.catalogInfrastructure?.recommendationEngine ??
            CatalogInfrastructure.current?.recommendationEngine ??
            (ProfileSyncEngine.instance != null
                ? RecommendationEngine(
                    userDataDao: ProfileSyncEngine.instance!.userDataDao,
                  )
                : null);

        if (kIsWeb && isPhone && size.width > 600) {
          return Scaffold(
            backgroundColor: const Color(0xFF070709),
            body: Stack(
              children: [
                Center(
                  child: Container(
                    width: 440,
                    height: size.height,
                    decoration: BoxDecoration(
                      color: const Color(0xFF050505),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.85),
                          blurRadius: 32,
                          spreadRadius: 6,
                        ),
                      ],
                    ),
                    child: ClipRect(
                      child: HourTvMobileShell(
                        recommendationEngine: recEngine,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 14,
                  right: 16,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF151917),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFF27302C)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton.icon(
                          onPressed: () => DeviceProfile.overrideType.value =
                              DeviceType.phone,
                          icon: const Icon(
                            Icons.phone_android_rounded,
                            size: 16,
                          ),
                          label: const Text('Móvil Android'),
                          style: TextButton.styleFrom(
                            foregroundColor: isPhone
                                ? const Color(0xFF00C781)
                                : const Color(0xFFA8ADAB),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () =>
                              DeviceProfile.overrideType.value = DeviceType.tv,
                          icon: const Icon(Icons.tv_rounded, size: 16),
                          label: const Text('Android TV'),
                          style: TextButton.styleFrom(
                            foregroundColor: !isPhone
                                ? const Color(0xFF00C781)
                                : const Color(0xFFA8ADAB),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        if (isPhone) {
          return HourTvMobileShell(recommendationEngine: recEngine);
        }
        return HourTvNewShell(recommendationEngine: recEngine);
      },
    );
  }
}

class _FatalError extends StatelessWidget {
  const _FatalError(this.message);
  final String message;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
        color: const Color(0xFF050505),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: Color(0xFFF20A1A),
                size: 48,
              ),
              const SizedBox(height: 16),
              const Text(
                'Ocurrió un error',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFFA6A6B0), fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
