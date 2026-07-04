import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'catalog_screen.dart';
import 'live_tv_screen.dart';
import 'profile_screen.dart';

/// Estructura principal con barra inferior: Inicio (catálogo), En Vivo
/// (solo canales) y Perfil. Estilo MagisTV/Xuper, sin ser copia calcada.
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
    (icon: Icons.person_rounded, label: 'Perfil'),
  ];

  @override
  Widget build(BuildContext context) {
    // En horizontal (viendo a pantalla completa) ocultamos la barra inferior.
    final landscape = MediaQuery.of(context).orientation == Orientation.landscape;
    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      body: Container(
        decoration: AppTheme.gradientBackground,
        child: IndexedStack(
          index: _index,
          children: [
            const CatalogScreen(),
            LiveTvScreen(active: _index == 1),
            const ProfileScreen(),
          ],
        ),
      ),
      bottomNavigationBar: landscape ? null : _bottomBar(),
    );
  }

  Widget _bottomBar() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF080C14),
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
