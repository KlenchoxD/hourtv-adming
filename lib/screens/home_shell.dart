import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/device_type.dart';
import '../services/content_store.dart';
import '../services/xtream_service.dart';
import '../models/channel.dart';
import '../widgets/tv_focusable.dart';
import '../widgets/hourtv_brand.dart';
import 'catalog_screen.dart';
import 'live_tv_screen.dart';
import 'profile_screen.dart';
import 'favorites_screen.dart';
import 'search_screen.dart';
import 'movie_detail_screen.dart';
import 'series_detail_screen.dart';

/// Estructura principal. Navegación adaptativa (diseño rojo/negro de referencia):
///   - Móvil/tablet: barra inferior de 5 (Inicio, Buscar, TV en Vivo, Mi lista,
///     Perfil). "Buscar" abre el buscador a pantalla completa.
///   - Android TV/Google TV: riel lateral de 6 navegable con D-pad (Inicio,
///     Películas, Series, TV en Vivo, Mi Lista, Perfil); Películas/Series abren
///     el catálogo directo en esa categoría.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int _index = 0;
  bool _railExpanded = false;

  // --- Destinos por dispositivo (íconos + páginas del IndexedStack) ---

  // TV: 6 destinos, uno por página.
  static const _tvItems = [
    (icon: Icons.home_rounded, label: 'Inicio'),
    (icon: Icons.movie_rounded, label: 'Películas'),
    (icon: Icons.video_library_rounded, label: 'Series'),
    (icon: Icons.live_tv_rounded, label: 'TV en Vivo'),
    (icon: Icons.favorite_rounded, label: 'Mi Lista'),
    (icon: Icons.person_rounded, label: 'Perfil'),
  ];
  static const _tvLiveIndex = 3;

  List<Widget> get _tvPages => [
    const CatalogScreen(initialCategory: 'all'),
    const CatalogScreen(initialCategory: 'movies'),
    const CatalogScreen(initialCategory: 'series'),
    LiveTvScreen(active: _index == _tvLiveIndex),
    const FavoritesScreen(),
    const ProfileScreen(),
  ];

  // Móvil: 4 páginas; "Buscar" es una acción (push), no una página.
  static const _mobileLiveIndex = 1;
  List<Widget> get _mobilePages => [
    const CatalogScreen(),
    LiveTvScreen(active: _index == _mobileLiveIndex),
    const FavoritesScreen(),
    const ProfileScreen(),
  ];

  // Orden visual de la barra inferior: page = índice de página; search = acción.
  static const _mobileNav = [
    (icon: Icons.home_rounded, label: 'Inicio', page: 0),
    (icon: Icons.search_rounded, label: 'Buscar', page: -1),
    (icon: Icons.live_tv_rounded, label: 'TV en Vivo', page: 1),
    (icon: Icons.favorite_rounded, label: 'Mi lista', page: 2),
    (icon: Icons.person_rounded, label: 'Perfil', page: 3),
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

  /// Buscador a pantalla completa (móvil). Construye la lista de contenido y
  /// navega al detalle de lo elegido.
  Future<void> _openSearch() async {
    final store = ContentStore.instance;
    final seriesByUrl = <String, XtreamSeries>{
      for (final item in store.series) 'hourtv-series:${item.seriesId}': item,
    };
    final searchItems = <Channel>[
      ...store.movies,
      for (final item in store.series)
        Channel(
          name: item.name,
          url: 'hourtv-series:${item.seriesId}',
          logo: item.cover,
          backdrop: item.backdrop,
          forcedType: 'series',
          plot: item.plot,
          year: item.year,
          rating: item.rating,
          duration: item.duration,
          genre: item.genre,
          categories: item.categories,
        ),
    ];
    final picked = await Navigator.push<Channel>(
      context,
      MaterialPageRoute(builder: (_) => SearchScreen(all: searchItems)),
    );
    if (picked == null || !mounted) return;
    final selectedSeries = seriesByUrl[picked.url];
    if (selectedSeries != null) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SeriesDetailScreen(series: selectedSeries),
        ),
      );
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            MovieDetailScreen(channel: picked, allChannels: store.movies),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isTv = DeviceProfile.isTv(context);
    final landscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final pages = isTv ? _tvPages : _mobilePages;
    final content = IndexedStack(index: _index, children: pages);
    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      body: Container(
        decoration: AppTheme.gradientBackground,
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

  // ======================= TV: riel lateral (6) =======================

  /// Menú overlay: colapsado es una franja delgada de íconos sobre un degradado;
  /// al enfocarlo con el D-pad se expande sobre el contenido.
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
          width: expanded ? 250 : 66,
          decoration: BoxDecoration(
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
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: expanded ? 16 : 0),
                    child: Row(
                      mainAxisAlignment: expanded
                          ? MainAxisAlignment.start
                          : MainAxisAlignment.center,
                      children: [
                        const HourTvLogo(size: 36),
                        if (expanded) ...[
                          const SizedBox(width: 11),
                          const Expanded(child: HourTvWordmark(fontSize: 18)),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 26),
                  for (var i = 0; i < _tvItems.length; i++) _railTab(i),
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
    final item = _tvItems[i];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: TvFocusable(
        onTap: () => setState(() => _index = i),
        autofocus: i == 0,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: double.infinity,
          height: 52,
          padding: EdgeInsets.symmetric(horizontal: _railExpanded ? 14 : 0),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? AppColors.accent.withValues(alpha: 0.18)
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

  // ==================== Móvil: barra inferior (5) ====================

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
          height: 58,
          child: Row(
            children: [
              for (final it in _mobileNav) Expanded(child: _bottomTab(it)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bottomTab(({IconData icon, String label, int page}) it) {
    final isSearch = it.page < 0;
    final sel = !isSearch && it.page == _index;
    return InkWell(
      onTap: () {
        if (isSearch) {
          _openSearch();
        } else {
          setState(() => _index = it.page);
        }
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            it.icon,
            size: 22,
            color: sel ? AppColors.accent : Colors.white.withValues(alpha: 0.6),
          ),
          const SizedBox(height: 3),
          Text(
            it.label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
              color: sel
                  ? AppColors.accent
                  : Colors.white.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}
