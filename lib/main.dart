import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/storage_service.dart';
import 'services/device_type.dart';
import 'theme/app_theme.dart';
import 'screens/home_shell.dart';

void main() {
  // Captura cualquier error no controlado y lo muestra en pantalla en vez de
  // cerrar la app, para poder diagnosticar fallos en dispositivos reales.
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    ErrorWidget.builder = (details) => _FatalError(details.exceptionAsString());
    try {
      await StorageService.init();
    } catch (_) {}
    await DeviceProfile.warmUp();
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.light, systemNavigationBarColor: AppColors.surfaceDark, systemNavigationBarIconBrightness: Brightness.light));
    runApp(const HourTVApp());
  }, (error, stack) {
    runApp(HourTVApp(fatalError: '$error'));
  });
}

/// Pantalla de error legible (en vez de cerrarse en silencio).
class _FatalError extends StatelessWidget {
  final String message;
  const _FatalError(this.message);
  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.ltr,
    child: Container(
      color: const Color(0xFF04060C),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.warning_amber_rounded, color: Color(0xFFFFB23E), size: 48),
          const SizedBox(height: 16),
          const Text('Ocurrió un error', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFAEB6C6), fontSize: 12)),
        ]),
      ),
    ),
  );
}

class HourTVApp extends StatelessWidget {
 final String? fatalError;
 const HourTVApp({super.key, this.fatalError});
 @override
 Widget build(BuildContext context) => MaterialApp(
   title: 'HourTV',
   debugShowCheckedModeBanner: false,
   theme: AppTheme.darkTheme,
   home: fatalError != null ? _FatalError(fatalError!) : const SplashScreen(),
 );
}

class SplashScreen extends StatefulWidget {
 const SplashScreen({super.key});
 @override State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
 late AnimationController _ctrl;
 late Animation<double> _fade;
 late Animation<double> _scale;
 late Animation<double> _glow;

 @override void initState() {
 super.initState();
 _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
 _fade = CurvedAnimation(parent: _ctrl, curve: const Interval(0.0, 0.6, curve: Curves.easeOut));
 _scale = Tween<double>(begin: 0.85, end: 1).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));
 _glow = Tween<double>(begin: 0.2, end: 0.55).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
 _ctrl.forward();
 Future.delayed(const Duration(milliseconds: 2400), () { if (mounted) Navigator.pushReplacement(context, PageRouteBuilder(pageBuilder: (_, _, _) => const HomeShell(), transitionDuration: const Duration(milliseconds: 600), transitionsBuilder: (_, animation, _, child) => FadeTransition(opacity: animation, child: child))); });
 }

 @override void dispose() { _ctrl.dispose(); super.dispose(); }

 @override Widget build(BuildContext context) => Scaffold(
 body: Container(
   decoration: AppTheme.gradientBackground,
   child: Center(
     child: AnimatedBuilder(
       animation: _ctrl,
       builder: (_, _) => Opacity(
         opacity: _fade.value,
         child: Transform.scale(
           scale: _scale.value,
           child: Column(mainAxisSize: MainAxisSize.min, children: [
             Container(
               width: 104, height: 104,
               decoration: BoxDecoration(
                 gradient: AppTheme.accentGradient,
                 borderRadius: BorderRadius.circular(28),
                 boxShadow: [BoxShadow(color: AppColors.accent.withValues(alpha: _glow.value), blurRadius: 48, spreadRadius: 4)],
               ),
               child: const Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 58),
             ),
             const SizedBox(height: 28),
             ShaderMask(
               shaderCallback: (b) => AppTheme.accentGradient.createShader(b),
               child: const Text('HourTV', style: TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w800, letterSpacing: -1)),
             ),
             const SizedBox(height: 6),
             Text('TU TELEVISIÓN, EN TODAS PARTES', style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 2)),
             const SizedBox(height: 52),
             SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.accent.withValues(alpha: 0.9))),
           ]),
         ),
       ),
     ),
   ),
 ),
 );
}