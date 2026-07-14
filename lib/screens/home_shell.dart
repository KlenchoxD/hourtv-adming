import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/device_type.dart';
import '../widgets/tv_focusable.dart';
import 'catalog_screen.dart';
import 'live_tv_screen.dart';
import 'favorites_screen.dart';
import 'profile_screen.dart';

/// Estructura principal: Inicio (catálogo), En Vivo (solo canales) y Perfil.
/// En móvil/tablet usa barra inferior; en Android TV/Google TV usa un riel
/// lateral navegable con D-pad (nunca requiere pantalla táctil).
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _items = [
    (icon: Icons.home_rounded, label: 'Inicio'),
    (icon: Icons.live_tv_rounded, label: 'En Vivo'),
    (icon: Icons.favorite_rounded, label: 'Favoritos'),
    (icon: Icons.person_rounded, label: 'Perfil'),
  ];

  @override
  Widget build(BuildContext context) {
    final isTv = DeviceProfile.isTv(context);
    // En horizontal (viendo a pantalla completa) ocultamos la barra inferior.
    final landscape = MediaQuery.of(context).orientation == Orientation.landscape;
    final content = IndexedStack(
      index: _index,
      children: [
        const CatalogScreen(),
        LiveTvScreen(active: _index == 1),
        const FavoritesScreen(),
        const ProfileScreen(),
      ],
    );
    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      body: Container(
        decoration: AppTheme.gradientBackground,
        child: isTv ? Row(children: [_sideRail(), Expanded(child: content)]) : content,
      ),
      bottomNavigationBar: (!isTv && !landscape) ? _bottomBar() : null,
    );
  }

  Widget _sideRail() {
    return Container(
      width: 88,
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        border: Border(right: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
      ),
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < _items.length; i++) _railTab(i),
          ],
        ),
      ),
    );
  }

  Widget _railTab(int i) {
    final sel = i == _index;
    final it = _items[i];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: TvFocusable(
        onTap: () => setState(() => _index = i),
        autofocus: i == 0,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 64,
          height: 64,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: sel ? AppColors.accent.withValues(alpha: 0.16) : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(it.icon, size: 22, color: sel ? AppColors.accent : AppColors.textMuted),
              const SizedBox(height: 3),
              Text(
                it.label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: sel ? AppColors.accent : AppColors.textMuted, fontSize: 9, fontWeight: sel ? FontWeight.w700 : FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bottomBar() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(children: [
            for (var i = 0; i < _items.length; i++) Expanded(child: _tab(i)),
          ]),
        ),
      ),
    );
  }

  Widget _tab(int i) {
    final sel = i == _index;
    final it = _items[i];
    return InkWell(
      onTap: () => setState(() => _index = i),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 5),
          decoration: BoxDecoration(
            color: sel ? AppColors.accent.withValues(alpha: 0.16) : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(it.icon, size: 24, color: sel ? AppColors.accent : AppColors.textMuted),
        ),
        const SizedBox(height: 3),
        Text(it.label, style: TextStyle(color: sel ? AppColors.accent : AppColors.textMuted, fontSize: 11, fontWeight: sel ? FontWeight.w700 : FontWeight.w500)),
      ]),
    );
  }
}
