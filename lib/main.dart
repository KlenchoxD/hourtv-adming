import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'mobile_ui/hourtv_mobile_components.dart';
import 'mobile_ui/hourtv_mobile_shell.dart';
import 'mobile_ui/hourtv_mobile_theme.dart';
import 'new_ui/hourtv_new_shell.dart';
import 'new_ui/hourtv_profile_gate.dart';
import 'new_ui/hourtv_settings_update_page.dart';
import 'services/device_type.dart';
import 'services/iptv_server_service.dart';
import 'services/storage_service.dart';
import 'services/update_service.dart';

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    ErrorWidget.builder = (details) => _FatalError(details.exceptionAsString());
    try {
      await StorageService.init();
    } catch (_) {}
    await DeviceProfile.warmUp();
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Color(0xFF0C0C0E),
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );
    runApp(const HourTVApp());
    if (StorageService.getSetting('iptv_server_enabled', defaultValue: false) ==
        true) {
      unawaited(IptvServerService.instance.start().catchError((_) {}));
    }
  }, (error, stack) => runApp(HourTVApp(fatalError: '$error')));
}

class HourTVApp extends StatelessWidget {
  const HourTVApp({super.key, this.fatalError});
  final String? fatalError;

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
          ? const _LaunchSplash()
          : _FatalError(fatalError!),
    );
  }
}

/// Momento de marca al abrir la app: reemplaza el "vuelve a aparecer el
/// icono" del arranque de Android por esta pantalla. Todo lo pesado
/// (StorageService, DeviceProfile) ya se esperó antes de runApp(), asi que
/// esto no espera ninguna carga real: es una pausa breve deliberada para
/// que la marca se vea en vez de pasar directo a Perfil/Inicio.
class _LaunchSplash extends StatefulWidget {
  const _LaunchSplash();

  @override
  State<_LaunchSplash> createState() => _LaunchSplashState();
}

class _LaunchSplashState extends State<_LaunchSplash> {
  var _ready = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _ready = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(
        backgroundColor: HourTvMobileTokens.deepBlack,
        body: HourTvBootLoading(
          title: 'Preparando el app para usar',
          subtitle: 'Un momento, ya casi está listo.',
        ),
      );
    }
    return const _ResponsiveRoot();
  }
}

class _ResponsiveRoot extends StatelessWidget {
  const _ResponsiveRoot();

  @override
  Widget build(BuildContext context) {
    // Recien instalada o tras "Cerrar sesión": obliga a elegir perfil antes
    // de dejar entrar a la app, como el selector de Netflix. Se escucha con
    // un ValueNotifier (no un Navigator.push) para que cerrar sesion desde
    // cualquier pantalla profunda solo tenga que resetear el flag y volver
    // a la primera ruta; esta raiz reacciona sola.
    return ValueListenableBuilder<bool>(
      valueListenable: StorageService.hasChosenProfile,
      builder: (context, hasChosenProfile, _) {
        if (!hasChosenProfile) return const HourTvProfileGate();
        return const _AppShell();
      },
    );
  }
}

/// La app normal, mas la revisión de actualizaciones automática: antes
/// habia que entrar a Perfil > Actualizaciones y tocar "Buscar" a mano para
/// enterarse de un release nuevo. Ahora se revisa sola una vez por sesión
/// al entrar, y si hay una version mas nueva se avisa con un dialogo en vez
/// de dejarlo escondido en un menu.
class _AppShell extends StatefulWidget {
  const _AppShell();

  @override
  State<_AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<_AppShell> {
  var _checkedForUpdate = false;

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
    if (DeviceProfile.isPhone(context)) return const HourTvMobileShell();
    return const HourTvNewShell();
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
