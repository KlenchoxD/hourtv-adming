import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/device_type.dart';
import '../services/content_store.dart';
import '../widgets/tv_focusable.dart';
import '../widgets/hourtv_brand.dart';
import 'catalog_screen.dart';
import 'live_tv_screen.dart';
import 'profile_screen.dart';

/// Estructura principal: Inicio (catálogo), En Vivo (solo canales) y Perfil.
/// En móvil/tablet usa barra inferior; en Android TV/Google TV usa un riel
/// lateral navegable con D-pad (nunca requiere pantalla táctil).
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int _index = 0;
  bool _railExpanded = false;

  static const _items = [
    (icon: Icons.home_rounded, label: 'Inicio'),
    (icon: Icons.live_tv_rounded, label: 'En Vivo'),
    (icon: Icons.person_rounded, label: 'Perfil'),
  ];

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
    // Al volver la app al frente, refresca el catálogo remoto en segundo
    // plano para reflejar lo que se publicó desde el panel de admin.
    if (state == AppLifecycleState.resumed) {
      ContentStore.instance.maybeRefresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTv = DeviceProfile.isTv(context);
    // En horizontal (viendo a pantalla completa) ocultamos la barra inferior.
    final landscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final content = IndexedStack(
      index: _index,
      children: [
        const CatalogScreen(),
        LiveTvScreen(active: _index == 1),
        const ProfileScreen(),
      ],
    );
    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      body: Container(
        decoration: AppTheme.gradientBackground,
        // TV estilo Netflix: contenido a pantalla completa (inmersivo) con el
        // menú como overlay que solo se expande al enfocarlo con el D-pad.
        child: isTv
            ? Stack(
                children: [
                  Positioned.fill(child: content),
                  _sideRail(),
                ],
              )
            : content,
      ),
      bottomNavigationBar: (!isTv && !landscape) ? _bottomBar() : null,
    );
  }

  /// Menú overlay estilo Netflix TV: colapsado es una franja delgada casi
  /// invisible (solo íconos sobre un degradado sutil, sin panel sólido ni
  /// etiquetas). Al enfocarlo con el D-pad se desliza sobre el contenido.
  Widget _sideRail() {
    final expanded = _railExpanded;
    return Positioned(
      top: 0,
      bottom: 0,
      left: 0,
      child: Focus(
        onFocusChange: (focused) {
          if (_railExpanded != focused) {
            setState(() => _railExpanded = focused);
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          width: expanded ? 250 : 62,
          decoration: BoxDecoration(
            // Colapsado: sin panel, solo un degradado que funde con el fondo
            // para que el hero se vea a sangre completa. Expandido: panel.
            color: expanded ? const Color(0xF5121212) : null,
            gradient: expanded
                ? null
                : const LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [Color(0xC0000000), Colors.transparent],
                  ),
            boxShadow: expanded
                ? const [
                    BoxShadow(
                      color: Colors.black87,
                      blurRadius: 30,
                      offset: Offset(10, 0),
                    ),
                  ]
                : null,
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 22),
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: expanded ? 16 : 0),
                    child: Row(
                      mainAxisAlignment: expanded
                          ? MainAxisAlignment.start
                          : MainAxisAlignment.center,
                      children: [
                        const HourTvLogo(size: 38),
                        if (expanded) ...[
                          const SizedBox(width: 11),
                          const Expanded(child: HourTvWordmark(fontSize: 18)),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 34),
                  for (var i = 0; i < _items.length; i++) _railTab(i),
                  const Spacer(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _railTab(int i) {
    final selected = i == _index;
    final item = _items[i];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: TvFocusable(
        onTap: () => setState(() => _index = i),
        autofocus: i == 0,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: double.infinity,
          height: 58,
          padding: EdgeInsets.symmetric(horizontal: _railExpanded ? 14 : 0),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? AppColors.accent.withValues(alpha: 0.17)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: Border(
              left: BorderSide(
                color: selected ? AppColors.accent : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: _railExpanded
                ? MainAxisAlignment.start
                : MainAxisAlignment.center,
            children: [
              Icon(
                item.icon,
                size: 24,
                color: selected ? AppColors.accent : AppColors.textSecondary,
              ),
              if (_railExpanded) ...[
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                      fontSize: 14,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
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

  /// Barra inferior solo iconos, estilo UltraPelis: el activo en rojo.
  Widget _bottomBar() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1B1B1C),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 54,
          child: Row(
            children: [
              for (var i = 0; i < _items.length; i++) Expanded(child: _tab(i)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tab(int i) {
    final sel = i == _index;
    final it = _items[i];
    return InkWell(
      onTap: () => setState(() => _index = i),
      child: AnimatedScale(
        scale: sel ? 1.0 : 0.95,
        duration: const Duration(milliseconds: 160),
        child: Icon(
          it.icon,
          size: 24,
          color: sel ? AppColors.accent : Colors.white.withValues(alpha: 0.6),
        ),
      ),
    );
  }
}
