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
import 'settings_screen.dart';

typedef _ShellDestination = ({
  IconData icon,
  String label,
  int page,
  bool search,
});

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int _index = 0;
  bool _railHovered = false;
  bool _railFocused = false;

  static const _phoneNav = <_ShellDestination>[
    (icon: Icons.home_rounded, label: 'Inicio', page: 0, search: false),
    (icon: Icons.search_rounded, label: 'Buscar', page: -1, search: true),
    (icon: Icons.live_tv_rounded, label: 'TV en Vivo', page: 1, search: false),
    (
      icon: Icons.favorite_border_rounded,
      label: 'Mi lista',
      page: 2,
      search: false,
    ),
    (
      icon: Icons.person_outline_rounded,
      label: 'Perfil',
      page: 3,
      search: false,
    ),
  ];

  static const _tabletNav = <_ShellDestination>[
    (icon: Icons.home_rounded, label: 'Inicio', page: 0, search: false),
    (icon: Icons.movie_outlined, label: 'Películas', page: 1, search: false),
    (
      icon: Icons.video_library_outlined,
      label: 'Series',
      page: 2,
      search: false,
    ),
    (icon: Icons.search_rounded, label: 'Buscar', page: -1, search: true),
    (icon: Icons.live_tv_outlined, label: 'TV Vivo', page: 3, search: false),
    (icon: Icons.add_rounded, label: 'Mi Lista', page: 4, search: false),
    (
      icon: Icons.person_outline_rounded,
      label: 'Perfil',
      page: 5,
      search: false,
    ),
  ];

  static const _desktopNav = <_ShellDestination>[
    (icon: Icons.home_rounded, label: 'Inicio', page: 0, search: false),
    (icon: Icons.movie_outlined, label: 'Películas', page: 1, search: false),
    (
      icon: Icons.video_library_outlined,
      label: 'Series',
      page: 2,
      search: false,
    ),
    (icon: Icons.search_rounded, label: 'Buscar', page: -1, search: true),
    (icon: Icons.live_tv_outlined, label: 'TV en Vivo', page: 3, search: false),
    (
      icon: Icons.favorite_border_rounded,
      label: 'Mi Lista',
      page: 4,
      search: false,
    ),
    (icon: Icons.settings_outlined, label: 'Ajustes', page: 5, search: false),
  ];

  static const _tvNav = <_ShellDestination>[
    (icon: Icons.home_rounded, label: 'Inicio', page: 0, search: false),
    (icon: Icons.movie_outlined, label: 'Películas', page: 1, search: false),
    (
      icon: Icons.video_library_outlined,
      label: 'Series',
      page: 2,
      search: false,
    ),
    (icon: Icons.live_tv_outlined, label: 'TV en Vivo', page: 3, search: false),
    (
      icon: Icons.favorite_border_rounded,
      label: 'Mi Lista',
      page: 4,
      search: false,
    ),
    (
      icon: Icons.person_outline_rounded,
      label: 'Perfil',
      page: 5,
      search: false,
    ),
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
    if (state == AppLifecycleState.resumed) {
      ContentStore.instance.maybeRefresh();
    }
  }

  List<Widget> _pages(DeviceType device) {
    final liveIndex = device == DeviceType.phone ? 1 : 3;
    final common = <Widget>[
      const CatalogScreen(initialCategory: 'all'),
      const CatalogScreen(initialCategory: 'movies'),
      const CatalogScreen(initialCategory: 'series'),
      LiveTvScreen(active: _index == liveIndex),
      const FavoritesScreen(),
    ];
    return switch (device) {
      DeviceType.phone => [
        const CatalogScreen(initialCategory: 'all'),
        LiveTvScreen(active: _index == liveIndex),
        const FavoritesScreen(),
        const ProfileScreen(),
      ],
      DeviceType.desktop => [...common, const SettingsScreen()],
      DeviceType.tablet || DeviceType.tv => [...common, const ProfileScreen()],
    };
  }

  List<_ShellDestination> _nav(DeviceType device) => switch (device) {
    DeviceType.phone => _phoneNav,
    DeviceType.tablet => _tabletNav,
    DeviceType.desktop => _desktopNav,
    DeviceType.tv => _tvNav,
  };

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

  void _activate(_ShellDestination destination) {
    if (destination.search) {
      _openSearch();
      return;
    }
    setState(() => _index = destination.page);
  }

  @override
  Widget build(BuildContext context) {
    final device = DeviceProfile.of(context);
    final pages = _pages(device);
    final safeIndex = _index.clamp(0, pages.length - 1);
    final content = IndexedStack(index: safeIndex, children: pages);

    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      body: Container(
        decoration: AppTheme.gradientBackground,
        child: device == DeviceType.phone
            ? content
            : _railLayout(device, content),
      ),
      bottomNavigationBar: device == DeviceType.phone ? _bottomBar() : null,
    );
  }

  Widget _railLayout(DeviceType device, Widget content) {
    final collapsed = switch (device) {
      DeviceType.tablet => 88.0,
      DeviceType.desktop => 82.0,
      DeviceType.tv => 96.0,
      DeviceType.phone => 0.0,
    };
    return Stack(
      children: [
        Positioned.fill(left: collapsed, child: content),
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          child: _sideRail(device, collapsed),
        ),
      ],
    );
  }

  Widget _sideRail(DeviceType device, double collapsedWidth) {
    final canExpand = device == DeviceType.desktop || device == DeviceType.tv;
    final expanded = canExpand && (_railHovered || _railFocused);
    final expandedWidth = device == DeviceType.tv ? 220.0 : 208.0;
    final width = expanded ? expandedWidth : collapsedWidth;
    final items = _nav(device);

    return MouseRegion(
      onEnter: (_) => setState(() => _railHovered = true),
      onExit: (_) => setState(() => _railHovered = false),
      child: Focus(
        onFocusChange: (focused) {
          if (_railFocused != focused) {
            setState(() => _railFocused = focused);
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          width: width,
          decoration: BoxDecoration(
            color: const Color(0xF7000000),
            border: Border(
              right: BorderSide(
                color: AppColors.accent.withValues(alpha: 0.12),
              ),
            ),
            boxShadow: expanded
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.75),
                      blurRadius: 28,
                      offset: const Offset(10, 0),
                    ),
                  ]
                : null,
          ),
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                device == DeviceType.tv ? 10 : 8,
                device == DeviceType.tv ? 24 : 16,
                device == DeviceType.tv ? 10 : 8,
                12,
              ),
              child: Column(
                children: [
                  AnimatedAlign(
                    duration: const Duration(milliseconds: 180),
                    alignment: expanded
                        ? Alignment.centerLeft
                        : Alignment.center,
                    child: HourTvLogo(
                      size: device == DeviceType.tv ? 54 : 44,
                      width: expanded
                          ? (device == DeviceType.tv ? 112 : 104)
                          : collapsedWidth - 16,
                    ),
                  ),
                  SizedBox(height: device == DeviceType.tv ? 22 : 14),
                  Expanded(
                    child: ListView.separated(
                      padding: EdgeInsets.zero,
                      itemCount: items.length,
                      separatorBuilder: (_, _) =>
                          SizedBox(height: device == DeviceType.tv ? 7 : 5),
                      itemBuilder: (_, index) =>
                          _railTab(device, items[index], expanded, index == 0),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _railTab(
    DeviceType device,
    _ShellDestination item,
    bool expanded,
    bool autofocus,
  ) {
    final selected = !item.search && item.page == _index;
    final compactTablet = device == DeviceType.tablet;

    final child = AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: double.infinity,
      height: compactTablet ? 54 : (device == DeviceType.tv ? 56 : 50),
      padding: EdgeInsets.symmetric(horizontal: expanded ? 13 : 0),
      decoration: BoxDecoration(
        color: selected ? AppColors.accent : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: selected
              ? AppColors.accentSecondary
              : Colors.white.withValues(alpha: 0.02),
        ),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: AppColors.accent.withValues(alpha: 0.32),
                  blurRadius: 14,
                ),
              ]
            : null,
      ),
      child: compactTablet
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  item.icon,
                  size: 21,
                  color: selected ? Colors.white : AppColors.textSecondary,
                ),
                const SizedBox(height: 3),
                Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? Colors.white : AppColors.textMuted,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            )
          : Row(
              mainAxisAlignment: expanded
                  ? MainAxisAlignment.start
                  : MainAxisAlignment.center,
              children: [
                Icon(
                  item.icon,
                  size: device == DeviceType.tv ? 25 : 22,
                  color: selected ? Colors.white : AppColors.textSecondary,
                ),
                if (expanded) ...[
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: selected
                            ? Colors.white
                            : AppColors.textSecondary,
                        fontSize: device == DeviceType.tv ? 15 : 14,
                        fontWeight: selected
                            ? FontWeight.w800
                            : FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
    );

    if (device == DeviceType.tv) {
      return TvFocusable(
        onTap: () => _activate(item),
        autofocus: autofocus,
        borderRadius: BorderRadius.circular(14),
        child: child,
      );
    }
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _activate(item),
        borderRadius: BorderRadius.circular(14),
        child: child,
      ),
    );
  }

  Widget _bottomBar() {
    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            for (final item in _phoneNav) Expanded(child: _bottomTab(item)),
          ],
        ),
      ),
    );
  }

  Widget _bottomTab(_ShellDestination item) {
    final selected = !item.search && item.page == _index;
    return InkWell(
      onTap: () => _activate(item),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                item.icon,
                size: 21,
                color: selected ? AppColors.accent : AppColors.textMuted,
              ),
              const SizedBox(height: 3),
              Text(
                item.label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: selected ? AppColors.accent : AppColors.textMuted,
                ),
              ),
            ],
          ),
          if (selected)
            const Positioned(
              bottom: 2,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.all(Radius.circular(3)),
                ),
                child: SizedBox(width: 20, height: 3),
              ),
            ),
        ],
      ),
    );
  }
}
