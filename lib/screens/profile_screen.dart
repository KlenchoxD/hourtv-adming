import 'package:flutter/material.dart';
import '../services/content_store.dart';
import '../services/device_type.dart';
import '../theme/app_theme.dart';
import '../widgets/tv_focusable.dart';
import 'lists_screen.dart';
import 'settings_screen.dart';

/// Pestaña PERFIL: accesos a fuentes, ajustes e información.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Future<void> _open(Widget screen) async {
    final tv = DeviceProfile.isTv(context);
    await Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(
      body: Container(
        decoration: AppTheme.gradientBackground,
        // En TV: texto más grande y columna centrada (diseño 10 pies) sin
        // tocar las pantallas hijas; en móvil/tablet quedan tal cual.
        child: tv
            ? MediaQuery.withClampedTextScaling(
                minScaleFactor: 1.3,
                maxScaleFactor: 1.3,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 900),
                    child: screen,
                  ),
                ),
              )
            : screen,
      ),
    )));
    if (mounted) { ContentStore.instance.reload(); setState(() {}); }
  }

  /// Escala 10 pies: 1.0 en móvil/tablet, 1.5 en TV.
  double get _s => DeviceProfile.uiScale(context);

  @override
  Widget build(BuildContext context) {
    final store = ContentStore.instance;
    final liveCount = store.all.where((c) => c.type.index == 0).length;
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          // En TV el contenido no se estira a todo el ancho: columna centrada.
          constraints: BoxConstraints(maxWidth: DeviceProfile.isTv(context) ? 860 : double.infinity),
          child: ListView(padding: const EdgeInsets.fromLTRB(20, 18, 20, 24), children: [
            // Cabecera de marca
            Row(children: [
              Container(
                width: 56 * _s, height: 56 * _s,
                decoration: BoxDecoration(gradient: AppTheme.accentGradient, borderRadius: BorderRadius.circular(16)),
                child: Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 34 * _s),
              ),
              const SizedBox(width: 14),
              Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text('HourTV', style: TextStyle(color: AppColors.textPrimary, fontSize: 22 * _s, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text('Tu televisión, en todas partes', style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5 * _s)),
              ]),
            ]),
            const SizedBox(height: 18),
            // Resumen
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppColors.cardDark, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withValues(alpha: 0.05))),
              child: Row(children: [
                Expanded(child: _stat('${store.all.length}', 'Total')),
                Container(width: 1, height: 34 * _s, color: Colors.white12),
                Expanded(child: _stat('$liveCount', 'En vivo')),
                Container(width: 1, height: 34 * _s, color: Colors.white12),
                Expanded(child: _stat('${store.movies.length}', 'Películas')),
              ]),
            ),
            const SizedBox(height: 22),
            _item(Icons.dns_rounded, 'Mis Fuentes', 'Cuentas Xtream y listas M3U', () => _open(const ListsScreen())),
            _item(Icons.tune_rounded, 'Ajustes', 'Reproducción, red y caché', () => _open(const SettingsScreen())),
            _item(Icons.refresh_rounded, 'Recargar contenido', 'Vuelve a descargar canales y catálogo', () { ContentStore.instance.reload(); setState(() {}); }),
            const SizedBox(height: 24),
            Center(child: Text('HourTV v1.0.0', style: TextStyle(color: AppColors.textMuted, fontSize: 12 * _s))),
          ]),
        ),
      ),
    );
  }

  Widget _stat(String value, String label) => Column(children: [
    Text(value, style: TextStyle(color: AppColors.textPrimary, fontSize: 20 * _s, fontWeight: FontWeight.w800)),
    const SizedBox(height: 2),
    Text(label, style: TextStyle(color: AppColors.textMuted, fontSize: 12 * _s)),
  ]);

  Widget _item(IconData icon, String title, String subtitle, VoidCallback onTap) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TvFocusable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: EdgeInsets.all(14 * _s),
        decoration: BoxDecoration(color: AppColors.cardDark, borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white.withValues(alpha: 0.05))),
        child: Row(children: [
          Container(width: 40 * _s, height: 40 * _s, decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(11)), child: Icon(icon, color: AppColors.accent, size: 21 * _s)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(color: AppColors.textPrimary, fontSize: 15 * _s, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(subtitle, style: TextStyle(color: AppColors.textMuted, fontSize: 12 * _s)),
          ])),
          Icon(Icons.chevron_right_rounded, color: AppColors.textMuted, size: 22 * _s),
        ]),
      ),
    ),
  );
}
