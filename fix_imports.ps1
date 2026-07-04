# Fix imports - remove double spaces at start of import lines
$files = @(
    "C:\Users\Kleiner\proyectos\mi_app\lib\main.dart",
    "C:\Users\Kleiner\proyectos\mi_app\lib\screens\player_screen.dart"
)

foreach ($f in $files) {
    $content = Get-Content $f -Raw
    # Remove double-space import prefix
    $content = $content -replace "import '  ", "import '"
    # Remove leading/trailing whitespace
    $content = $content.Trim()
    [System.IO.File]::WriteAllText($f, $content)
    Write-Host "Fixed: $f"
}

# Rewrite main.dart correctly
$mainContent = @"
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/storage_service.dart';
import 'theme/app_theme.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await StorageService.init();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: AppColors.surfaceDark,
  ));
  runApp(const StreamTVApp());
}

class StreamTVApp extends StatelessWidget {
  const StreamTVApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'StreamTV',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
    _fade = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeIn));
    _scale = Tween<double>(begin: 0.7, end: 1).animate(CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut));
    _ctrl.forward();
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const HomeScreen(),
            transitionDuration: const Duration(milliseconds: 500),
            transitionsBuilder: (_, animation, __, child) => FadeTransition(opacity: animation, child: child),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: AppTheme.gradientBackground,
        child: Center(
          child: AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) {
              return Opacity(
                opacity: _fade.value,
                child: Transform.scale(
                  scale: _scale.value,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 100, height: 100,
                        decoration: BoxDecoration(
                          color: AppColors.accent,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [BoxShadow(color: AppColors.accent.withValues(alpha: 0.4), blurRadius: 30, spreadRadius: 5)],
                        ),
                        child: const Icon(Icons.live_tv, color: Colors.white, size: 50),
                      ),
                      const SizedBox(height: 24),
                      const Text('StreamTV', style: TextStyle(color: AppColors.textPrimary, fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 1)),
                      const SizedBox(height: 8),
                      const Text('Tu TV personal', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                      const SizedBox(height: 48),
                      const SizedBox(width: 32, height: 32, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
"@

[System.IO.File]::WriteAllText("C:\Users\Kleiner\proyectos\mi_app\lib\main.dart", $mainContent)
Write-Host "main.dart rewritten"
