import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/channel.dart';
import '../services/content_store.dart';
import '../services/device_type.dart';

import 'hourtv_focusable.dart';
import 'hourtv_detail_page.dart';
import 'hourtv_live_page.dart';
import 'hourtv_profile_page.dart';
import 'hourtv_series_detail_page.dart';

const _red = Color(0xFFF20A1A);
const _black = Color(0xFF050505);
const _surface = Color(0xFF101012);
const _line = Color(0xFF25252A);
const _muted = Color(0xFFA6A6B0);
const _green = Color(0xFF00D6A0);

enum _Section { home, movies, series, search, live, list, profile }

class HourTvNewShell extends StatefulWidget {
  const HourTvNewShell({super.key});

  @override
  State<HourTvNewShell> createState() => _HourTvNewShellState();
}

class _HourTvNewShellState extends State<HourTvNewShell> {
  final ContentStore store = ContentStore.instance;
  _Section section = _Section.home;
  bool railHovered = false;

  @override
  void initState() {
    super.initState();
    store.addListener(_refresh);
    store.ensureLoaded();
  }

  @override
  void dispose() {
    store.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  List<Channel> get movies =>
      store.movies.isEmpty ? PreviewCatalog.movies : store.movies;

  List<Channel> get series {
    final direct = store.all
        .where((item) => item.type == MediaType.series)
        .toList();
    final favoriteUrls = store.favorites.map((item) => item.url).toSet();
    final converted = store.series
        .map(hourTvSeriesChannel)
        .map(
          (item) => item.copyWith(isFavorite: favoriteUrls.contains(item.url)),
        );
    final seen = <String>{};
    final real = <Channel>[
      for (final item in [...direct, ...converted])
        if (seen.add(item.displayName.trim().toLowerCase())) item,
    ];
    return real.isEmpty ? PreviewCatalog.series : real;
  }

  bool get showingSeriesPreview =>
      store.series.isEmpty &&
      store.all.where((item) => item.type == MediaType.series).isEmpty;

  List<Channel> get live {
    final real = store.all
        .where((item) => item.type == MediaType.live)
        .toList();
    return real.isEmpty ? PreviewCatalog.live : real;
  }

  bool get showingPreview => store.movies.isEmpty;

  @override
  Widget build(BuildContext context) {
    final phone = DeviceProfile.isPhone(context);
    final tablet = DeviceProfile.isTablet(context);
    final tv = DeviceProfile.isTv(context);
    final body = _sectionBody(phone: phone, tablet: tablet, tv: tv);

    return Scaffold(
      backgroundColor: _black,
      body: phone
          ? SafeArea(bottom: false, child: body)
          : Row(
              children: [
                _SideRail(
                  current: section,
                  expanded: !tv && railHovered,
                  tv: tv,
                  onHover: (value) => setState(() => railHovered = value),
                  onSelect: (value) => setState(() => section = value),
                ),
                Expanded(child: body),
              ],
            ),
      bottomNavigationBar: phone
          ? _BottomNav(
              current: section,
              onSelect: (value) => setState(() => section = value),
            )
          : null,
    );
  }

  Widget _sectionBody({
    required bool phone,
    required bool tablet,
    required bool tv,
  }) {
    switch (section) {
      case _Section.home:
        return _HomePage(
          movies: movies,
          series: series,
          store: store,
          preview: showingPreview,
          phone: phone,
          tablet: tablet,
          onSearch: () => setState(() => section = _Section.search),
          tv: tv,
        );
      case _Section.movies:
        return _CatalogPage(
          title: 'Películas',
          items: movies,
          store: store,
          preview: showingPreview,
          phone: phone,
          tablet: tablet,
          tv: tv,
        );
      case _Section.series:
        return _CatalogPage(
          title: 'Series',

          items: series,

          store: store,
          preview: showingSeriesPreview,
          phone: phone,
          tablet: tablet,
          tv: tv,
        );
      case _Section.search:
        return _CatalogPage(
          title: 'Buscar',
          subtitle: 'Películas, series o géneros',
          items: [...movies, ...series],
          store: store,
          preview: showingPreview,
          phone: phone,
          tablet: tablet,
          tv: tv,
          searchAutofocus: true,
        );
      case _Section.live:
        return HourTvLivePage(
          channels: live,
          preview: store.all.where((c) => c.type == MediaType.live).isEmpty,
          phone: phone,
          tablet: tablet,
          tv: tv,
        );
      case _Section.list:
        return _CatalogPage(
          title: 'Mi lista',
          subtitle: 'Tus favoritos, siempre a mano',
          items: store.favorites,
          store: store,
          preview: false,
          phone: phone,
          tablet: tablet,
          tv: tv,
          emptyMessage: 'Todavía no agregaste contenido a Mi lista.',
        );
      case _Section.profile:
        return HourTvProfilePage(phone: phone, tablet: tablet, tv: tv);
    }
  }
}

class _SideRail extends StatelessWidget {
  const _SideRail({
    required this.current,
    required this.expanded,
    required this.tv,
    required this.onHover,
    required this.onSelect,
  });

  final _Section current;
  final bool expanded;
  final bool tv;
  final ValueChanged<bool> onHover;
  final ValueChanged<_Section> onSelect;

  static const entries = <(_Section, IconData, String)>[
    (_Section.home, Icons.home_rounded, 'Inicio'),
    (_Section.movies, Icons.movie_creation_outlined, 'Películas'),
    (_Section.series, Icons.video_library_outlined, 'Series'),
    (_Section.search, Icons.search_rounded, 'Buscar'),
    (_Section.live, Icons.sensors_rounded, 'TV en vivo'),
    (_Section.list, Icons.favorite_border_rounded, 'Mi lista'),
    (_Section.profile, Icons.person_outline_rounded, 'Perfil'),
  ];

  @override
  Widget build(BuildContext context) {
    final width = tv ? 180.0 : (expanded ? 208.0 : 88.0);
    return MouseRegion(
      onEnter: (_) => onHover(true),
      onExit: (_) => onHover(false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        width: width,
        decoration: const BoxDecoration(
          color: Color(0xFF070708),
          border: Border(right: BorderSide(color: _line)),
        ),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(tv ? 20 : 14, 22, tv ? 16 : 14, 18),
            child: Column(
              children: [
                SizedBox(
                  height: tv ? 76 : 70,
                  child: Align(
                    alignment: tv || expanded
                        ? Alignment.centerLeft
                        : Alignment.center,
                    child: const HourTvLogo(height: 54),
                  ),
                ),
                const SizedBox(height: 12),
                for (final entry in entries) ...[
                  _RailItem(
                    icon: entry.$2,
                    label: entry.$3,
                    selected: current == entry.$1,
                    showLabel: tv || expanded,
                    autofocus: tv && current == entry.$1,
                    onTap: () => onSelect(entry.$1),
                  ),
                  const SizedBox(height: 8),
                ],
                const Spacer(),
                if (tv || expanded)
                  const Text(
                    'HOURTV  •  ENTRETENIMIENTO SIN LÍMITES',
                    style: TextStyle(color: Color(0xFF55555E), fontSize: 8.5),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RailItem extends StatefulWidget {
  const _RailItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.showLabel,
    required this.onTap,
    this.autofocus = false,
  });
  final IconData icon;
  final String label;
  final bool selected;
  final bool showLabel;
  final VoidCallback onTap;
  final bool autofocus;

  @override
  State<_RailItem> createState() => _RailItemState();
}

class _RailItemState extends State<_RailItem> {
  bool _focused = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    // Resalte claro estilo Xuper: el item enfocado (D-pad) o seleccionado se
    // RELLENA de rojo; con mouse encima muestra un relleno tenue. El foco es un
    // bloque que se mueve, no solo un borde.
    // Solo el item ENFOCADO se rellena de rojo (bloque que se mueve con el
    // D-pad). La seccion actual, cuando el foco esta en otro lado, se marca con
    // texto rojo. Con mouse encima, relleno tenue.
    final Color bg = _focused
        ? _red
        : (_hovered ? const Color(0xFF1E1E23) : Colors.transparent);
    final Color fg = _focused
        ? Colors.white
        : (widget.selected ? _red : _muted);
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: TvFocusable(
        onTap: widget.onTap,
        autofocus: widget.autofocus,
        decorated: false,
        scale: 1.0,
        borderRadius: BorderRadius.circular(14),
        onFocusChange: (value) => setState(() => _focused = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
          ),
          child: SizedBox(
            height: 48,
            child: Row(
              mainAxisAlignment: widget.showLabel
                  ? MainAxisAlignment.start
                  : MainAxisAlignment.center,
              children: [
                if (widget.showLabel) const SizedBox(width: 14),
                Icon(widget.icon, color: fg, size: 22),
                if (widget.showLabel) ...[
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      widget.label,
                      maxLines: 1,
                      style: TextStyle(
                        color: fg,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.current, required this.onSelect});
  final _Section current;
  final ValueChanged<_Section> onSelect;

  @override
  Widget build(BuildContext context) {
    const items = <(_Section, IconData, String)>[
      (_Section.home, Icons.home_rounded, 'Inicio'),
      (_Section.search, Icons.search_rounded, 'Buscar'),
      (_Section.live, Icons.live_tv_rounded, 'TV'),
      (_Section.list, Icons.favorite_border_rounded, 'Mi lista'),
      (_Section.profile, Icons.person_outline_rounded, 'Perfil'),
    ];
    return Container(
      height: 72 + MediaQuery.paddingOf(context).bottom,
      padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
      decoration: const BoxDecoration(
        color: Color(0xFF0C0C0E),
        border: Border(top: BorderSide(color: _line)),
      ),
      child: Row(
        children: [
          for (final item in items)
            Expanded(
              child: InkWell(
                onTap: () => onSelect(item.$1),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      item.$2,
                      color: current == item.$1 ? _red : _muted,
                      size: 24,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.$3,
                      style: TextStyle(
                        color: current == item.$1 ? Colors.white : _muted,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _HomePage extends StatelessWidget {
  const _HomePage({
    required this.movies,
    required this.series,
    required this.store,
    required this.preview,
    required this.phone,
    required this.tablet,
    required this.tv,
    required this.onSearch,
  });
  final List<Channel> movies;
  final List<Channel> series;
  final ContentStore store;
  final bool preview;
  final bool phone;
  final bool tablet;
  final bool tv;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    final featured = movies.first;
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: _TopBar(phone: phone, onSearch: onSearch),
        ),
        SliverToBoxAdapter(
          child: _Hero(
            channel: featured,
            store: store,
            preview: preview,
            phone: phone,
            tablet: tablet,
            tv: tv,
          ),
        ),
        SliverToBoxAdapter(
          child: _MediaRow(
            title: 'HourTV Originals',
            items: movies.take(10).toList(),
            store: store,
            preview: preview,
            phone: phone,
            tablet: tablet,
            tv: tv,
          ),
        ),
        SliverToBoxAdapter(
          child: _MediaRow(
            title: 'Tendencias ahora',
            items: movies.reversed.take(10).toList(),
            store: store,
            preview: preview,
            phone: phone,
            tablet: tablet,
            tv: tv,
          ),
        ),
        SliverToBoxAdapter(
          child: _MediaRow(
            title: 'Series para ti',
            items: series.take(10).toList(),
            store: store,
            preview: series == PreviewCatalog.series,
            phone: phone,
            tablet: tablet,
            tv: tv,
          ),
        ),
        // Regla de oro HourTV: Inicio es SOLO VOD. Los canales en vivo viven
        // exclusivamente en la seccion "TV en vivo", nunca en Home.
        const SliverToBoxAdapter(child: SizedBox(height: 48)),
      ],
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.phone, required this.onSearch});
  final bool phone;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    if (!phone) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          const HourTvLogo(height: 42),
          const Spacer(),
          _RoundButton(icon: Icons.search_rounded, onTap: onSearch),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({
    required this.channel,
    required this.store,
    required this.preview,
    required this.phone,
    required this.tablet,
    required this.tv,
  });
  final Channel channel;
  final ContentStore store;
  final bool preview;
  final bool phone;
  final bool tablet;
  final bool tv;

  @override
  Widget build(BuildContext context) {
    final side = phone ? 16.0 : (tv ? 34.0 : 28.0);
    final height = phone ? 380.0 : (tablet ? 260.0 : (tv ? 300.0 : 340.0));
    return Container(
      height: height,
      margin: EdgeInsets.fromLTRB(side, phone ? 2 : 12, side, phone ? 14 : 14),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(phone ? 18 : 22),
        border: Border.all(color: _line),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          _Artwork(
            url: channel.backdrop ?? channel.logo,
            fit: BoxFit.cover,
            cacheWidth: 900,
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Color(0x33000000),
                  Color(0xF9000000),
                ],
                stops: [0.2, 0.55, 1],
              ),
            ),
          ),
          if (!phone)
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Color(0xE6000000),
                    Color(0x33000000),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          Positioned(
            left: phone ? 18 : (tv ? 46 : 34),
            right: phone ? 18 : 34,
            bottom: phone ? 18 : (tv ? 48 : 34),
            child: Align(
              alignment: phone ? Alignment.bottomCenter : Alignment.bottomLeft,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: phone ? 420 : 520),
                child: Column(
                  crossAxisAlignment: phone
                      ? CrossAxisAlignment.center
                      : CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Wrap(
                      alignment: phone
                          ? WrapAlignment.center
                          : WrapAlignment.start,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 10,
                      runSpacing: 6,
                      children: [
                        const _Badge(text: 'HOURTV ORIGINAL'),
                        const Text(
                          '98% COINCIDENCIA',
                          style: TextStyle(
                            color: _green,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 9),
                    Text(
                      channel.displayName,
                      textAlign: phone ? TextAlign.center : TextAlign.left,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: phone ? 30 : (tv ? 46 : 40),
                        height: .98,
                        letterSpacing: -1.3,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      [
                        channel.year ?? '2026',
                        '16+',
                        channel.duration ?? '2h 15m',
                      ].join('   •   '),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .82),
                        fontSize: phone ? 11 : 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisSize: phone ? MainAxisSize.max : MainAxisSize.min,
                      children: [
                        Expanded(
                          flex: phone ? 1 : 0,
                          child: _PrimaryButton(
                            label: 'Reproducir',
                            icon: Icons.play_arrow_rounded,
                            onTap: () =>
                                _open(context, channel, store, preview),
                          ),
                        ),
                        const SizedBox(width: 10),
                        _OutlineButton(
                          label: phone ? '' : 'Mi lista',
                          icon: channel.isFavorite
                              ? Icons.check_rounded
                              : Icons.add_rounded,
                          onTap: preview
                              ? null
                              : () => store.toggleFavorite(channel),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MediaRow extends StatelessWidget {
  const _MediaRow({
    required this.title,
    required this.items,
    required this.store,
    required this.preview,
    required this.phone,
    required this.tablet,
    required this.tv,
  });
  final String title;
  final List<Channel> items;
  final ContentStore store;
  final bool preview;
  final bool phone;
  final bool tablet;
  final bool tv;

  @override
  Widget build(BuildContext context) {
    final portrait = phone || tablet || tv;
    final width = phone ? 104.0 : (tablet ? 118.0 : (tv ? 118.0 : 180.0));
    final imageHeight = portrait ? width * 1.5 : width * .56;
    final side = phone ? 12.0 : (tv ? 34.0 : 28.0);
    return Padding(
      padding: EdgeInsets.only(bottom: phone ? 14 : 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(side, 0, side, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: phone ? 17 : (tv ? 24 : 20),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white54,
                  size: phone ? 22 : 28,
                ),
              ],
            ),
          ),
          SizedBox(
            height: imageHeight + (phone ? 31 : 38),
            child: ListView.separated(
              padding: EdgeInsets.symmetric(horizontal: side),
              scrollDirection: Axis.horizontal,
              itemCount: items.length,
              separatorBuilder: (_, _) => SizedBox(width: phone ? 8 : 12),
              itemBuilder: (context, index) {
                final item = items[index];
                return _MediaCard(
                  channel: item,
                  width: width,
                  imageHeight: imageHeight,
                  landscape: !portrait,
                  onTap: () => _open(context, item, store, preview),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MediaCard extends StatefulWidget {
  const _MediaCard({
    required this.channel,
    required this.width,
    required this.imageHeight,
    required this.landscape,
    required this.onTap,
  });
  final Channel channel;
  final double width;
  final double imageHeight;
  final bool landscape;
  final VoidCallback onTap;

  @override
  State<_MediaCard> createState() => _MediaCardState();
}

class _MediaCardState extends State<_MediaCard> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    // El resalte de foco va SOLO en la caratula (borde rojo limpio), nunca
    // alrededor del titulo. Escala suave para que no desborde a las vecinas.
    // RepaintBoundary aisla el repintado por tarjeta (menos jank al desplazar).
    return RepaintBoundary(
      child: SizedBox(
      width: widget.width,
      child: TvFocusable(
        onTap: widget.onTap,
        decorated: false,
        scale: 1.04,
        borderRadius: BorderRadius.circular(9),
        onFocusChange: (value) => setState(() => _focused = value),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: widget.width,
              height: widget.imageHeight,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(
                  color: _focused ? _red : _line,
                  width: _focused ? 2.5 : 1,
                ),
              ),
              child: _Artwork(
                url: widget.landscape
                    ? (widget.channel.backdrop ?? widget.channel.logo)
                    : widget.channel.logo,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              widget.channel.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: _focused ? Colors.white : const Color(0xFFD6D6DB),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }
}

class _CatalogPage extends StatefulWidget {
  const _CatalogPage({
    required this.title,
    required this.items,
    required this.store,
    required this.preview,
    required this.phone,
    required this.tablet,
    required this.tv,
    this.subtitle,
    this.emptyMessage = 'No hay contenido disponible.',
    this.searchAutofocus = false,
  });
  final String title;
  final String? subtitle;
  final List<Channel> items;
  final ContentStore store;
  final bool preview;
  final bool phone;
  final bool tablet;
  final bool tv;
  final String emptyMessage;
  final bool searchAutofocus;

  @override
  State<_CatalogPage> createState() => _CatalogPageState();
}

class _CatalogPageState extends State<_CatalogPage> {
  String query = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.items
        .where(
          (item) =>
              item.displayName.toLowerCase().contains(query.toLowerCase()),
        )
        .toList();
    final columns = widget.phone
        ? 3
        : (widget.tablet ? 4 : (widget.tv ? 6 : 5));
    final portrait = widget.phone || widget.tablet || widget.tv;
    final padding = widget.phone ? 14.0 : 30.0;
    final railWidth = widget.phone ? 0.0 : (widget.tv ? 180.0 : 88.0);
    final gap = widget.phone ? 8.0 : 14.0;
    final gridWidth =
        MediaQuery.sizeOf(context).width - railWidth - (padding * 2);
    final cardWidth = (gridWidth - (gap * (columns - 1))) / columns;
    final cardImageHeight = portrait ? cardWidth * 1.5 : cardWidth * .56;
    final cardAspectRatio = cardWidth / (cardImageHeight + 27);
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              padding,
              widget.phone ? 16 : 34,
              padding,
              20,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.phone) const HourTvLogo(height: 42),
                if (widget.phone) const SizedBox(height: 22),
                Text(
                  widget.title,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: widget.phone ? 28 : (widget.tv ? 38 : 34),
                    letterSpacing: -1,
                  ),
                ),
                if (widget.subtitle != null) ...[
                  const SizedBox(height: 5),
                  Text(widget.subtitle!, style: const TextStyle(color: _muted)),
                ],
                const SizedBox(height: 18),
                SizedBox(
                  width: widget.phone ? double.infinity : 420,
                  child: TextField(
                    autofocus: widget.searchAutofocus,
                    onChanged: (value) => setState(() => query = value),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Buscar en ${widget.title.toLowerCase()}',
                      hintStyle: const TextStyle(color: _muted),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: _muted,
                      ),
                      filled: true,
                      fillColor: _surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: _line),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: _line),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (filtered.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _EmptyState(message: widget.emptyMessage),
          )
        else
          SliverPadding(
            padding: EdgeInsets.fromLTRB(padding, 0, padding, 40),
            sliver: SliverGrid.builder(
              itemCount: filtered.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: gap,
                mainAxisSpacing: widget.phone ? 14 : 20,
                childAspectRatio: cardAspectRatio,
              ),
              itemBuilder: (context, index) {
                final item = filtered[index];
                return _MediaCard(
                  channel: item,
                  width: double.infinity,
                  imageHeight: cardImageHeight,
                  landscape: !portrait,
                  onTap: () =>
                      _open(context, item, widget.store, widget.preview),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.favorite_border_rounded, color: _muted, size: 48),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _muted),
            ),
          ],
        ),
      ),
    );
  }
}

class HourTvLogo extends StatelessWidget {
  const HourTvLogo({super.key, this.height = 48});
  final double height;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/branding/hourtv_logo.png',
      height: height,
      fit: BoxFit.contain,
      alignment: Alignment.centerLeft,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, _, _) => Text(
        'HOUR TV',
        style: GoogleFonts.inter(
          color: Colors.white,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _Artwork extends StatelessWidget {
  const _Artwork({required this.url, required this.fit, this.cacheWidth = 260});
  final String? url;
  final BoxFit fit;

  /// Ancho de decodificacion: las imagenes se cachean/decodifican a esta
  /// resolucion en vez de la original. Clave para el rendimiento en TV Box
  /// arm32 (evita saturar memoria/GPU con caratulas a tamano completo).
  final int cacheWidth;

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.trim().isEmpty) return const _ArtworkFallback();
    return CachedNetworkImage(
      imageUrl: url!,
      fit: fit,
      memCacheWidth: cacheWidth,
      fadeInDuration: const Duration(milliseconds: 200),
      placeholder: (_, _) => const _ArtworkFallback(),
      errorWidget: (_, _, _) => const _ArtworkFallback(),
    );
  }
}

class _ArtworkFallback extends StatelessWidget {
  const _ArtworkFallback();
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF341018), Color(0xFF12080C), Color(0xFF13002B)],
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.play_arrow_rounded,
          color: Color(0x55FFFFFF),
          size: 46,
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: _red,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w900,
          letterSpacing: .6,
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) =>
      _HeroButton(label: label, icon: icon, onTap: onTap, primary: true);
}

class _OutlineButton extends StatelessWidget {
  const _OutlineButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) =>
      _HeroButton(label: label, icon: icon, onTap: onTap, primary: false);
}

/// Boton del hero operable con control remoto: al enfocar muestra un anillo
/// blanco + escala y auto-desplaza para que el hero entre completo a la vista.
class _HeroButton extends StatefulWidget {
  const _HeroButton({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.primary,
  });
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool primary;

  @override
  State<_HeroButton> createState() => _HeroButtonState();
}

class _HeroButtonState extends State<_HeroButton> {
  final _node = FocusNode();
  bool _focused = false;

  @override
  void dispose() {
    _node.dispose();
    super.dispose();
  }

  void _onFocusChange(bool value) {
    if (mounted) setState(() => _focused = value);
    if (!value) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_node.hasFocus) return;
      Scrollable.ensureVisible(
        context,
        alignment: .5,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
      );
    });
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final keys = {
      LogicalKeyboardKey.select,
      LogicalKeyboardKey.enter,
      LogicalKeyboardKey.numpadEnter,
      LogicalKeyboardKey.space,
      LogicalKeyboardKey.gameButtonA,
    };
    if (!keys.contains(event.logicalKey) || widget.onTap == null) {
      return KeyEventResult.ignored;
    }
    widget.onTap!();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final iconOnly = widget.label.isEmpty;
    final bg = widget.primary ? _red : const Color(0x2EFFFFFF);
    final border = _focused
        ? Colors.white
        : (widget.primary ? Colors.transparent : const Color(0x66FFFFFF));
    return Focus(
      focusNode: _node,
      onKeyEvent: _onKey,
      onFocusChange: _onFocusChange,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _focused ? 1.05 : 1,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: 48,
            padding: EdgeInsets.symmetric(horizontal: iconOnly ? 12 : 20),
            constraints: BoxConstraints(minWidth: iconOnly ? 50 : 132),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: border, width: _focused ? 2.5 : 1.4),
              boxShadow: _focused
                  ? const [BoxShadow(color: Color(0x66000000), blurRadius: 14)]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(widget.icon, size: 21, color: Colors.white),
                if (!iconOnly) ...[
                  const SizedBox(width: 9),
                  Text(
                    widget.label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xAA17171A),
      shape: const CircleBorder(side: BorderSide(color: _line)),
      child: IconButton(
        onPressed: onTap,
        icon: Icon(icon, color: Colors.white),
        tooltip: '',
      ),
    );
  }
}

void _open(
  BuildContext context,
  Channel channel,
  ContentStore store,
  bool preview,
) {
  final series = hourTvResolveSeries(channel, store.series);
  if (series != null) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => HourTvSeriesDetailPage(series: series)),
    );
    return;
  }
  if (preview) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => HourTvDetailPage(channel: channel, preview: true),
      ),
    );
    return;
  }
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => HourTvDetailPage(channel: channel, preview: false),
    ),
  );
}

class PreviewCatalog {
  static Channel item(
    String name,
    String poster,
    String backdrop, {
    String genre = 'Sci-Fi',
    String year = '2026',
  }) => Channel(
    name: name,
    url: 'preview://${name.toLowerCase().replaceAll(' ', '-')}',
    logo: poster,
    backdrop: backdrop,
    genre: genre,
    year: year,
    duration: '2h 15m',
    plot:
        'Una historia original de HourTV donde el misterio, la emoción y la aventura cambian todo.',
    forcedType: 'movie',
  );

  static final movies = <Channel>[
    item(
      'Project Nova',
      'https://images.unsplash.com/photo-1578301978693-85fa9c0320b9?q=80&w=600&auto=format&fit=crop',
      'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?q=80&w=1400&auto=format&fit=crop',
    ),
    item(
      'Ecos del Ayer',
      'https://images.unsplash.com/photo-1489599849927-2ee91cede3ba?q=80&w=600&auto=format&fit=crop',
      'https://images.unsplash.com/photo-1498837167922-ddd27525d352?q=80&w=1400&auto=format&fit=crop',
      genre: 'Drama',
    ),
    item(
      'Legado de Honor',
      'https://images.unsplash.com/photo-1533928298208-27ff66555d8d?q=80&w=600&auto=format&fit=crop',
      'https://images.unsplash.com/photo-1519074069444-1ba4e6664104?q=80&w=1400&auto=format&fit=crop',
      genre: 'Acción',
    ),
    item(
      'Shadow City',
      'https://images.unsplash.com/photo-1511447333015-45b65e60f6d5?q=80&w=600&auto=format&fit=crop',
      'https://images.unsplash.com/photo-1509198397868-475647b2a1e5?q=80&w=1400&auto=format&fit=crop',
      genre: 'Misterio',
    ),
    item(
      'Cosmos Odyssey',
      'https://images.unsplash.com/photo-1462331940025-496dfbfc7564?q=80&w=600&auto=format&fit=crop',
      'https://images.unsplash.com/photo-1451187580459-43490279c0fa?q=80&w=1400&auto=format&fit=crop',
    ),
    item(
      'Neon Hearts',
      'https://images.unsplash.com/photo-1550745165-9bc0b252726f?q=80&w=600&auto=format&fit=crop',
      'https://images.unsplash.com/photo-1542751371-adc38448a05e?q=80&w=1400&auto=format&fit=crop',
      genre: 'Romance',
    ),
    item(
      'The Silent Peak',
      'https://images.unsplash.com/photo-1519681393784-d120267933ba?q=80&w=600&auto=format&fit=crop',
      'https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?q=80&w=1400&auto=format&fit=crop',
      genre: 'Aventura',
    ),
    item(
      'The Grid Matrix',
      'https://images.unsplash.com/photo-1518770660439-4636190af475?q=80&w=600&auto=format&fit=crop',
      'https://images.unsplash.com/photo-1515879218367-8466d910aaa4?q=80&w=1400&auto=format&fit=crop',
    ),
    item(
      'Lluvia de Medianoche',
      'https://images.unsplash.com/photo-1485846234645-a62644f84728?q=80&w=600&auto=format&fit=crop',
      'https://images.unsplash.com/photo-1428908728789-d2de25dbd4e2?q=80&w=1400&auto=format&fit=crop',
      genre: 'Suspenso',
    ),
  ];

  static final series = movies.reversed
      .take(7)
      .map((item) => item.copyWith(forcedType: 'series'))
      .toList();

  static final live = <Channel>[
    item(
      'HourTV Noticias',
      'https://images.unsplash.com/photo-1495020689067-958852a7765e?q=80&w=600&auto=format&fit=crop',
      'https://images.unsplash.com/photo-1495020689067-958852a7765e?q=80&w=1200&auto=format&fit=crop',
      genre: 'Noticias',
    ).copyWith(forcedType: 'live'),
    item(
      'HourTV Deportes',
      'https://images.unsplash.com/photo-1517649763962-0c623066013b?q=80&w=600&auto=format&fit=crop',
      'https://images.unsplash.com/photo-1517649763962-0c623066013b?q=80&w=1200&auto=format&fit=crop',
      genre: 'Deportes',
    ).copyWith(forcedType: 'live'),
    item(
      'HourTV Cine',
      'https://images.unsplash.com/photo-1489599849927-2ee91cede3ba?q=80&w=600&auto=format&fit=crop',
      'https://images.unsplash.com/photo-1489599849927-2ee91cede3ba?q=80&w=1200&auto=format&fit=crop',
      genre: 'Cine',
    ).copyWith(forcedType: 'live'),
  ];
}
