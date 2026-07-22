import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'new_ui/hourtv_new_shell.dart';
import 'services/device_type.dart';
import 'services/iptv_server_service.dart';
import 'services/storage_service.dart';

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
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF050505),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFF20A1A),
          surface: Color(0xFF101012),
        ),
        splashFactory: InkRipple.splashFactory,
      ),
      home: fatalError == null
          ? const HourTvNewShell()
          : _FatalError(fatalError!),
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
