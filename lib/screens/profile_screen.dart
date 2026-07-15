import 'package:flutter/material.dart';
import '../services/content_store.dart';
import '../services/device_type.dart';
import '../theme/app_theme.dart';
import '../widgets/tv_focusable.dart';
import '../widgets/hourtv_brand.dart';
import 'favorites_screen.dart';
import 'history_screen.dart';
import 'lists_screen.dart';
import 'settings_screen.dart';

/// Perfil al estilo Xuper: accesos personales arriba y funciones debajo.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _reloading = false;

  Future<void> _open(Widget screen) async {
    final tv = DeviceProfile.isTv(context);
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          body: Container(
            decoration: AppTheme.gradientBackground,
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
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _reload() async {
    if (_reloading) return;
    setState(() => _reloading = true);
    try {
      await ContentStore.instance.reload();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Contenido actualizado.')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo recargar el contenido.')),
      );
    } finally {
      if (mounted) setState(() => _reloading = false);
    }
  }

  double get _s => DeviceProfile.uiScale(context);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: DeviceProfile.isTv(context) ? 860 : double.infinity,
          ),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
            children: [
              Row(
                children: [
                  HourTvLogo(size: 56 * _s),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      HourTvWordmark(fontSize: 22 * _s),
                      const SizedBox(height: 2),
                      Text(
                        'Tu televisión, en todas partes',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12.5 * _s,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: _shortcut(
                      Icons.favorite_rounded,
                      'Favoritos',
                      'Lo que guardaste',
                      () => _open(const FavoritesScreen()),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _shortcut(
                      Icons.history_rounded,
                      'Historial',
                      'Visto recientemente',
                      () => _open(const HistoryScreen()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Text(
                'MÁS FUNCIONES',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11 * _s,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 10),
              _item(
                Icons.dns_rounded,
                'Mis Fuentes',
                'Cuentas Xtream, Stalker y listas M3U',
                () => _open(const ListsScreen()),
              ),
              _item(
                Icons.tune_rounded,
                'Ajustes',
                'Reproducción, red y catálogo',
                () => _open(const SettingsScreen()),
              ),
              _item(
                Icons.refresh_rounded,
                _reloading ? 'Recargando…' : 'Recargar contenido',
                'Actualiza canales y catálogo',
                _reload,
                trailing: _reloading
                    ? SizedBox(
                        width: 20 * _s,
                        height: 20 * _s,
                        child: const CircularProgressIndicator(strokeWidth: 2),
                      )
                    : null,
              ),
              const SizedBox(height: 24),
              Center(
                child: Text(
                  'HourTV v1.0.0',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12 * _s,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _shortcut(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    return TvFocusable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        constraints: BoxConstraints(minHeight: 128 * _s),
        padding: EdgeInsets.all(16 * _s),
        decoration: BoxDecoration(
          color: AppColors.cardDark,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42 * _s,
              height: 42 * _s,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: AppColors.accent, size: 23 * _s),
            ),
            SizedBox(height: 13 * _s),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15 * _s,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: AppColors.textMuted, fontSize: 11.5 * _s),
            ),
          ],
        ),
      ),
    );
  }

  Widget _item(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap, {
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TvFocusable(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: EdgeInsets.all(14 * _s),
          decoration: BoxDecoration(
            color: AppColors.cardDark,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Row(
            children: [
              Container(
                width: 40 * _s,
                height: 40 * _s,
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: AppColors.accent, size: 21 * _s),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15 * _s,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12 * _s,
                      ),
                    ),
                  ],
                ),
              ),
              trailing ??
                  Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.textMuted,
                    size: 22 * _s,
                  ),
            ],
          ),
        ),
      ),
    );
  }
}
