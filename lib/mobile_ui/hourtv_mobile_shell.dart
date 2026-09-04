import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/channel.dart';
import '../new_ui/hourtv_detail_page.dart';
import '../new_ui/hourtv_live_page.dart';
import '../new_ui/hourtv_new_shell.dart' show PreviewCatalog;
import '../new_ui/hourtv_profile_avatar.dart';
import '../new_ui/hourtv_profile_page.dart';
import '../new_ui/hourtv_settings_language_page.dart';
import '../new_ui/hourtv_settings_page.dart';
import '../new_ui/hourtv_settings_parental_page.dart';
import '../new_ui/hourtv_settings_playback_page.dart';
import '../services/content_store.dart';
import '../services/device_type.dart';
import '../services/storage_service.dart';
import 'hourtv_mobile_components.dart';
import 'hourtv_mobile_theme.dart';

enum HourTvMobileDestination { home, live, search, library, profile }

enum HourTvSearchSort { newest, oldest, titleAscending }

abstract interface class HourTvSearchHistoryStore {
  Future<List<String>> load();
  Future<void> save(List<String> history);
}

class SharedPreferencesHourTvSearchHistoryStore
    implements HourTvSearchHistoryStore {
  static const _key = 'hourtv.mobile.search.history';

  @override
  Future<List<String>> load() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getStringList(_key) ?? const <String>[];
  }

  @override
  Future<void> save(List<String> history) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(_key, history);
  }
}

class HourTvMobileShell extends StatefulWidget {
  const HourTvMobileShell({super.key});

  @override
  State<HourTvMobileShell> createState() => _HourTvMobileShellState();
}

class _HourTvMobileShellState extends State<HourTvMobileShell> {
  final store = ContentStore.instance;
  var destination = HourTvMobileDestination.home;
  // La guia En Vivo reproduce miniaturas en vivo (video real) apenas se
  // monta. El IndexedStack del shell monta las cinco pestañas de una,
  // asi que sin esto se abriria una conexion de streaming en segundo plano
  // desde el arranque aunque el usuario nunca toque "En vivo". Se retrasa
  // su construccion hasta la primera vez que se visita esa pestaña.
  var _liveVisited = false;

  @override
  void initState() {
    super.initState();
    store.addListener(_refresh);
    unawaited(store.ensureLoaded());
  }

  @override
  void dispose() {
    store.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  // El catalogo de muestra es para cuando de verdad no hay nada que mostrar
  // (recien instalado, sin fuentes configuradas) — NO para taparse mientras
  // el catalogo real todavia esta cargando. Antes se usaba en ambos casos,
  // asi que el Inicio siempre abria mostrando peliculas de muestra que un
  // instante despues se reemplazaban por las reales: un salto visible en
  // cada arranque. Mientras `store.loading` es true, se deja la lista vacia
  // y el Inicio muestra un indicador de carga en su lugar.
  List<Channel> get _movies {
    if (store.movies.isNotEmpty) return store.movies;
    return store.loading ? const [] : PreviewCatalog.movies;
  }

  List<Channel> get _allContent {
    final content = store.visibleAll
        .where((item) => item.type != MediaType.live)
        .toList();
    if (content.isNotEmpty) return content;
    return store.loading ? const [] : PreviewCatalog.movies;
  }

  List<Channel> get _liveChannels =>
      store.visibleAll.where((item) => item.type == MediaType.live).toList();

  // La guia (HourTvLivePage) hace `channels.first` en su initState y no
  // tolera una lista vacia (p. ej. antes de que cargue el catalogo real):
  // mismo respaldo que ya usa el shell de TV/desktop para esta seccion.
  List<Channel> get _liveChannelsOrPreview =>
      _liveChannels.isNotEmpty ? _liveChannels : PreviewCatalog.live;

  void _openDetails(Channel channel) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => HourTvDetailPage(
          channel: channel,
          preview: PreviewCatalog.movies.any((item) => item.url == channel.url),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (destination == HourTvMobileDestination.live) _liveVisited = true;
    final pages = <Widget>[
      HourTvMobileHome(
        movies: _movies,
        allContent: _allContent,
        store: store,
        onOpen: _openDetails,
        onSearch: () =>
            setState(() => destination = HourTvMobileDestination.search),
        onProfile: () =>
            setState(() => destination = HourTvMobileDestination.profile),
      ),
      // Antes esta pestaña mostraba una vista previa recortada (chips +
      // "En vivo ahora" con solo 12 canales) y habia que tocar "Guía
      // completa" para llegar a la guia real. Ahora la guia completa ES la
      // pestaña: se muestra directo al entrar y no hay ninguna otra vista a
      // la que volver. Construida recien al primer visitarla (ver
      // _liveVisited) para no abrir una miniatura en vivo en segundo plano
      // desde el arranque del app.
      if (_liveVisited)
        HourTvLivePage(
          channels: _liveChannelsOrPreview,
          preview: _liveChannels.isEmpty,
          phone: !DeviceProfile.isTablet(context),
          tablet: DeviceProfile.isTablet(context),
          tv: false,
          active: destination == HourTvMobileDestination.live,
        )
      else
        const SizedBox.shrink(),
      HourTvMobileSearch(content: _allContent, onOpen: _openDetails),
      HourTvMobileLibrary(store: store, onOpen: _openDetails),
      HourTvMobileProfile(
        onOpenAccount: () {
          final isTablet = DeviceProfile.isTablet(context);
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              // HourTvProfilePage no trae su propio Scaffold: en el shell de
              // TV/desktop vive embebida dentro de uno ya existente, pero
              // aca se empuja como pantalla propia y sin Scaffold no hay
              // Material ancestor -> el selector de perfil (InkWell) crashea
              // con "No Material widget found" al tocarlo.
              builder: (_) => Scaffold(
                backgroundColor: HourTvMobileTokens.deepBlack,
                body: HourTvProfilePage(
                  phone: !isTablet,
                  tablet: isTablet,
                  tv: false,
                  // _logout() ya hace popUntil(isFirst) sobre el navigator
                  // raiz: nada que hacer aca, o se intentaria un segundo pop
                  // sobre una ruta que ya no existe.
                  onLoggedOut: () {},
                ),
              ),
            ),
          );
        },
        onOpenSetting: (label) {
          // Cada tarjeta abre SU pantalla directo, sin pasar antes por el
          // hub de Perfil (antes las 4 abrian siempre lo mismo).
          final page = switch (label) {
            'Reproducción y calidad' => const HourTvPlaybackSettingsPage(),
            'Idioma y subtítulos' => const HourTvLanguageSettingsPage(),
            'Control parental' => const HourTvParentalSettingsPage(),
            _ => const HourTvSettingsPage(),
          };
          Navigator.of(
            context,
          ).push(MaterialPageRoute<void>(builder: (_) => page));
        },
      ),
    ];

    return Scaffold(
      backgroundColor: HourTvMobileTokens.deepBlack,
      body: SafeArea(
        bottom: false,
        child: IndexedStack(index: destination.index, children: pages),
      ),
      bottomNavigationBar: HourTvBottomNavigation(
        index: destination.index,
        onChanged: (index) =>
            setState(() => destination = HourTvMobileDestination.values[index]),
      ),
    );
  }
}

class HourTvMobileHome extends StatefulWidget {
  const HourTvMobileHome({
    super.key,
    required this.movies,
    required this.allContent,
    required this.store,
    required this.onOpen,
    required this.onSearch,
    required this.onProfile,
  });

  final List<Channel> movies;
  final List<Channel> allContent;
  final ContentStore store;
  final ValueChanged<Channel> onOpen;
  final VoidCallback onSearch;
  final VoidCallback onProfile;

  @override
  State<HourTvMobileHome> createState() => _HourTvMobileHomeState();
}

class _HourTvMobileHomeState extends State<HourTvMobileHome> {
  @override
  Widget build(BuildContext context) {
    final continueWatching = widget.store.continueWatching;
    final activeProfile = StorageService.getSetting(
      'activeProfile',
      defaultValue: 'Invitado',
    ).toString();

    return CustomScrollView(
      key: const PageStorageKey('hourtv-mobile-home'),
      slivers: [
        SliverToBoxAdapter(
          child: HourTvMobileHeader(
            onAvatarTap: widget.onProfile,
            profileName: activeProfile,
            avatarSeed: StorageService.activeProfileAvatarId,
            trailing: IconButton(
              tooltip: 'Buscar',
              onPressed: widget.onSearch,
              icon: const Icon(
                Icons.search_rounded,
                color: HourTvMobileTokens.textSecondary,
              ),
            ),
          ),
        ),
        if (widget.store.error != null && widget.store.movies.isEmpty)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            sliver: SliverToBoxAdapter(child: _LoadErrorBanner()),
          ),
        // Catalogo real todavia sin llegar: un spinner en vez del contenido
        // de muestra evita el salto de "sale lo de prototipo y despues lo
        // real" en cada arranque.
        if (widget.store.loading && widget.movies.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: HourTvBootLoading(),
          )
        else ...[
          SliverToBoxAdapter(
            child: _HeroCarousel(
              channels: widget.movies.take(5).toList(),
              onPlay: widget.onOpen,
              onFavorite: widget.store.toggleFavorite,
            ),
          ),
          if (continueWatching.isNotEmpty) ...[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
              sliver: SliverToBoxAdapter(
                child: HourTvSectionHeader(title: 'Continuar viendo'),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 172,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: continueWatching.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (_, index) => _ContinueCard(
                    channel: continueWatching[index],
                    onTap: () => widget.onOpen(continueWatching[index]),
                    assetFallback: _fallbackArtwork(index),
                  ),
                ),
              ),
            ),
          ],
          ..._homeRows(context),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ],
    );
  }

  static const _rowPreview = 8;

  List<Widget> _homeRows(BuildContext context) {
    // Cada fila guarda la lista completa: la horizontal solo muestra las
    // primeras `_rowPreview` y "Ver más" abre el resto en una cuadricula.
    // Antes estas tres filas repartian el mismo catalogo con distinto orden
    // (una era literalmente la lista al reves) para simular variedad; ahora
    // cada una es una categoria real filtrada por el catalogo.
    final rows = <(String, List<Channel>)>[
      ('Películas', widget.store.movies),
      ('Series', widget.store.seriesChannels),
      ('Animes', widget.store.anime),
      ('K-Drama', widget.store.kDramas),
      ('Tendencia', widget.store.trending),
    ].where((row) => row.$2.isNotEmpty).toList();
    return [
      for (final row in rows) ...[
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
          sliver: SliverToBoxAdapter(
            child: HourTvSectionHeader(
              title: row.$1,
              actionLabel: row.$2.length > _rowPreview ? 'Ver más' : null,
              onAction: row.$2.length > _rowPreview
                  ? () => _openRow(context, row.$1, row.$2)
                  : null,
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 220,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: math.min(row.$2.length, _rowPreview),
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (_, index) => HourTvPosterCard(
                channel: row.$2[index],
                onTap: () => widget.onOpen(row.$2[index]),
                assetFallback: _fallbackArtwork(index + 1),
              ),
            ),
          ),
        ),
      ],
    ];
  }

  void _openRow(BuildContext context, String title, List<Channel> items) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => HourTvMobileRowPage(
          title: title,
          items: items,
          onOpen: widget.onOpen,
        ),
      ),
    );
  }
}

/// Cuadricula completa de una fila del Inicio, detras de "Ver más". Antes las
/// filas cortaban en 8 titulos y no habia forma de llegar al resto.
class HourTvMobileRowPage extends StatelessWidget {
  const HourTvMobileRowPage({
    super.key,
    required this.title,
    required this.items,
    required this.onOpen,
  });

  final String title;
  final List<Channel> items;
  final ValueChanged<Channel> onOpen;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HourTvMobileTokens.deepBlack,
      appBar: AppBar(
        backgroundColor: HourTvMobileTokens.deepBlack,
        title: Text(title.toUpperCase()),
      ),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            sliver: SliverGrid.builder(
              itemCount: items.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 16,
                crossAxisSpacing: 10,
                childAspectRatio: 120 / 218,
              ),
              itemBuilder: (_, index) => HourTvPosterCard(
                channel: items[index],
                onTap: () => onOpen(items[index]),
                width: double.infinity,
                assetFallback: _fallbackArtwork(index),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Se muestra cuando el catalogo real no pudo cargar y la app cae al
/// contenido de muestra: antes eso pasaba en silencio y el usuario no tenia
/// forma de saber si su fuente esta rota o si la app no tiene fuentes.
class _LoadErrorBanner extends StatelessWidget {
  const _LoadErrorBanner();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: HourTvMobileTokens.error.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: HourTvMobileTokens.error.withValues(alpha: .4)),
    ),
    child: Row(
      children: [
        const Icon(Icons.wifi_off_rounded, color: HourTvMobileTokens.error),
        const SizedBox(width: 12),
        const Expanded(
          child: Text(
            'No pudimos cargar el catálogo real. Mostrando contenido de '
            'muestra: revisá tu conexión o tus fuentes en Perfil.',
            style: TextStyle(color: Colors.white, fontSize: 12.5, height: 1.3),
          ),
        ),
        const SizedBox(width: 8),
        TextButton(
          onPressed: () => unawaited(ContentStore.instance.reload()),
          child: const Text('Reintentar'),
        ),
      ],
    ),
  );
}

/// Rota entre varias destacadas cada pocos segundos (como en Netflix/Xuper).
/// Antes el hero mostraba siempre `movies.first`, fijo, sin moverse nunca.
class _HeroCarousel extends StatefulWidget {
  const _HeroCarousel({
    required this.channels,
    required this.onPlay,
    required this.onFavorite,
  });

  final List<Channel> channels;
  final ValueChanged<Channel> onPlay;
  final ValueChanged<Channel> onFavorite;

  @override
  State<_HeroCarousel> createState() => _HeroCarouselState();
}

class _HeroCarouselState extends State<_HeroCarousel> {
  final _controller = PageController();
  Timer? _timer;
  var _page = 0;

  @override
  void initState() {
    super.initState();
    _scheduleAutoAdvance();
  }

  void _scheduleAutoAdvance() {
    _timer?.cancel();
    if (widget.channels.length < 2) return;
    _timer = Timer.periodic(const Duration(seconds: 7), (_) {
      if (!mounted || !_controller.hasClients) return;
      final next = (_page + 1) % widget.channels.length;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.channels.isEmpty) return const SizedBox.shrink();
    // Antes 430px fijos en _HourTvHero: en pantallas cortas (celulares de
    // gama media/baja) ocupaba demasiado del alto visible y el titulo/
    // botones de abajo quedaban apenas fuera de vista hasta hacer scroll.
    // Proporcional al alto real, con un techo para no crecer de mas en
    // pantallas grandes.
    final height = (MediaQuery.sizeOf(context).height * 0.48).clamp(
      300.0,
      430.0,
    );
    return SizedBox(
      height: height,
      child: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: widget.channels.length,
            onPageChanged: (index) => setState(() => _page = index),
            itemBuilder: (_, index) {
              final channel = widget.channels[index];
              return _HourTvHero(
                channel: channel,
                onPlay: () => widget.onPlay(channel),
                onFavorite: () => widget.onFavorite(channel),
              );
            },
          ),
          if (widget.channels.length > 1)
            Positioned(
              bottom: 12,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < widget.channels.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: i == _page ? 18 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: i == _page
                            ? HourTvMobileTokens.emerald
                            : Colors.white38,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _HourTvHero extends StatelessWidget {
  const _HourTvHero({
    required this.channel,
    required this.onPlay,
    required this.onFavorite,
  });

  final Channel channel;
  final VoidCallback onPlay;
  final VoidCallback onFavorite;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      HourTvArtwork(
        url: channel.backdrop ?? channel.logo,
        asset: 'assets/figma/phase-3-1/hero-el-ultimo-amanecer.png',
        alignment: Alignment.topCenter,
      ),
      const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0x0D050505),
              Color(0x40050505),
              HourTvMobileTokens.deepBlack,
            ],
            stops: [0, 0.52, 1],
          ),
        ),
      ),
      Positioned(
        left: 16,
        right: 16,
        bottom: 28,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              channel.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            if ((channel.genre ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                channel.genre!.trim(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
            const SizedBox(height: 12),
            // Antes eran dos rectangulos identicos lado a lado, iguales en
            // cada slide del carrusel: parecia la misma plantilla repetida.
            // Ahora "Reproducir" domina como pildora y Favorito es un
            // circulo compacto, mismo lenguaje que ya usan las fichas de
            // detalle para esta accion.
            Row(
              children: [
                Expanded(
                  child: HourTvButton(
                    label: 'Reproducir',
                    icon: Icons.play_arrow_rounded,
                    onPressed: onPlay,
                  ),
                ),
                const SizedBox(width: 12),
                _HeroFavoriteButton(
                  active: channel.isFavorite,
                  onTap: onFavorite,
                ),
              ],
            ),
          ],
        ),
      ),
    ],
  );
}

/// Icono circular compacto para "Favorito" en el hero: relleno y sombra
/// cuando esta activo, contorno sutil cuando no. Mismo lenguaje visual que
/// el boton de favorito en la ficha de detalle.
class _HeroFavoriteButton extends StatelessWidget {
  const _HeroFavoriteButton({required this.active, required this.onTap});

  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: active ? 'Quitar de favoritos' : 'Favorito',
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          width: HourTvMobileTokens.minimumTouchTarget,
          height: HourTvMobileTokens.minimumTouchTarget,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active
                ? HourTvMobileTokens.emerald
                : HourTvMobileTokens.surfaceControl,
            border: Border.all(
              color: active
                  ? HourTvMobileTokens.emerald
                  : HourTvMobileTokens.borderSubtle,
            ),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: HourTvMobileTokens.emerald.withValues(alpha: .45),
                      blurRadius: 14,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: Icon(
            active ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            color: active
                ? HourTvMobileTokens.deepBlack
                : HourTvMobileTokens.textPrimary,
          ),
        ),
      ),
    ),
  );
}

class _ContinueCard extends StatefulWidget {
  const _ContinueCard({
    required this.channel,
    required this.onTap,
    required this.assetFallback,
  });

  final Channel channel;
  final VoidCallback onTap;
  final String assetFallback;

  @override
  State<_ContinueCard> createState() => _ContinueCardState();
}

class _ContinueCardState extends State<_ContinueCard> {
  bool _pressed = false;

  /// Minutos restantes reales a partir de la duracion total (TMDB/Xtream) y
  /// el progreso guardado. Sin esos datos, no se inventa un tiempo.
  String? get _remainingLabel {
    final fraction = widget.channel.progressFraction;
    final raw = widget.channel.duration?.trim();
    if (fraction == null || raw == null || raw.isEmpty) return null;
    final totalMinutes = int.tryParse(
      RegExp(r'^(\d+)').firstMatch(raw)?.group(1) ?? '',
    );
    if (totalMinutes == null || totalMinutes <= 0) return null;
    final remaining = (totalMinutes * (1 - fraction)).round();
    return remaining <= 0 ? null : 'Quedan $remaining min';
  }

  @override
  Widget build(BuildContext context) => AnimatedScale(
    scale: _pressed ? 0.98 : 1.0,
    duration: const Duration(milliseconds: 150),
    curve: Curves.easeOut,
    child: SizedBox(
      width: 230,
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 129,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  HourTvArtwork(
                    url: widget.channel.backdrop ?? widget.channel.logo,
                    asset: widget.assetFallback,
                    borderRadius: BorderRadius.circular(12),
                    alignment: Alignment.topCenter,
                  ),
                  const Center(
                    child: CircleAvatar(
                      radius: 22,
                      backgroundColor: HourTvMobileTokens.emerald,
                      child: Icon(
                        Icons.play_arrow_rounded,
                        color: HourTvMobileTokens.deepBlack,
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: LinearProgressIndicator(
                      minHeight: 3,
                      value: widget.channel.progressFraction ?? 0,
                      backgroundColor: HourTvMobileTokens.borderSubtle,
                      color: HourTvMobileTokens.emerald,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 7),
            Text(
              widget.channel.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (_remainingLabel != null)
              Text(
                _remainingLabel!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
      ),
    ),
  );
}

class HourTvMobileSearch extends StatefulWidget {
  const HourTvMobileSearch({
    super.key,
    required this.content,
    required this.onOpen,
    this.historyStore,
  });
  final List<Channel> content;
  final ValueChanged<Channel> onOpen;
  final HourTvSearchHistoryStore? historyStore;
  @override
  State<HourTvMobileSearch> createState() => _HourTvMobileSearchState();
}

class _HourTvMobileSearchState extends State<HourTvMobileSearch> {
  static const _initialVisible = 18;
  static const _revealStep = 12;
  static const _genres = ['Todo', 'Películas', 'Series', 'Anime', 'Novelas'];
  final controller = TextEditingController();
  final _scrollController = ScrollController();
  late final HourTvSearchHistoryStore _historyStore;
  Timer? _debounce;
  List<String> _history = const <String>[];
  var _query = '';
  var genre = 'Todo';
  var _sort = HourTvSearchSort.newest;
  var _visibleCount = _initialVisible;
  @override
  void initState() {
    super.initState();
    _historyStore =
        widget.historyStore ?? SharedPreferencesHourTvSearchHistoryStore();
    _scrollController.addListener(_onScroll);
    unawaited(_loadHistory());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    controller.dispose();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    final values = await _historyStore.load();
    if (!mounted) return;
    setState(() => _history = values.take(10).toList(growable: false));
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      setState(() {
        _query = value.trim();
        _visibleCount = _initialVisible;
      });
    });
  }

  Future<void> _submit([String? value]) async {
    _debounce?.cancel();
    final query = (value ?? controller.text).trim();
    if (value != null) {
      controller
        ..text = value
        ..selection = TextSelection.collapsed(offset: value.length);
    }
    setState(() {
      _query = query;
      _visibleCount = _initialVisible;
    });
    if (query.isEmpty) return;
    final normalized = _normalize(query);
    final next = <String>[
      ..._history.where((item) => _normalize(item) != normalized),
      query,
    ];
    if (next.length > 10) next.removeRange(0, next.length - 10);
    setState(() => _history = List<String>.unmodifiable(next));
    await _historyStore.save(_history);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.extentAfter >= 600) return;
    final total = _results().length;
    if (_visibleCount >= total) return;
    setState(() {
      _visibleCount = math.min(_visibleCount + _revealStep, total);
    });
  }

  List<Channel> _results() {
    final terms = _normalize(
      _query,
    ).split(' ').where((term) => term.isNotEmpty).toList(growable: false);
    final results = widget.content.where((item) {
      if (!_matchesGenre(item)) return false;
      final haystack = _normalize(
        [
          item.name,
          item.genre,
          item.group,
          ...item.categories,
        ].whereType<String>().join(' '),
      );
      return terms.every(haystack.contains);
    }).toList();
    results.sort(switch (_sort) {
      HourTvSearchSort.newest => (a, b) => _year(b).compareTo(_year(a)),
      HourTvSearchSort.oldest => (a, b) => _year(a).compareTo(_year(b)),
      HourTvSearchSort.titleAscending => (a, b) => _normalize(
        a.name,
      ).compareTo(_normalize(b.name)),
    });
    return results;
  }

  bool _matchesGenre(Channel item) => switch (genre) {
    'Películas' => item.type == MediaType.movie,
    'Series' => item.type == MediaType.series,
    'Anime' => _metadata(item).contains('anime'),
    'Novelas' =>
      _metadata(item).contains('novela') ||
          _metadata(item).contains('telenovela'),
    _ => true,
  };
  String _metadata(Channel item) => _normalize(
    [item.genre, item.group, ...item.categories].whereType<String>().join(' '),
  );
  @override
  Widget build(BuildContext context) {
    final results = _results();
    final visible = results.take(_visibleCount).toList(growable: false);
    return CustomScrollView(
      key: const PageStorageKey('hourtv-mobile-search'),
      controller: _scrollController,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
          sliver: SliverToBoxAdapter(
            child: Row(
              children: [
                const Icon(
                  Icons.search_rounded,
                  color: HourTvMobileTokens.emerald,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Text(
                  'BUSCAR',
                  style: Theme.of(
                    context,
                  ).textTheme.headlineMedium?.copyWith(letterSpacing: .3),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverToBoxAdapter(
            child: TextField(
              key: const ValueKey('hourtv-mobile-search-field'),
              controller: controller,
              onChanged: _onChanged,
              onSubmitted: _submit,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Películas, series, novelas…',
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: HourTvMobileTokens.textSecondary,
                ),
                suffixIcon: IconButton(
                  tooltip: 'Buscar',
                  onPressed: () => _submit(),
                  icon: const Icon(
                    Icons.arrow_forward_rounded,
                    color: HourTvMobileTokens.emerald,
                  ),
                ),
              ),
            ),
          ),
        ),
        // `_genres` es una lista fija y chica (5): antes era un carrusel
        // horizontal que obligaba a arrastrar para llegar a "Novelas".
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          sliver: SliverToBoxAdapter(
            child: HourTvEvenTabs(
              labels: _genres,
              selected: genre,
              onSelected: (value) => setState(() {
                genre = value;
                _visibleCount = _initialVisible;
              }),
            ),
          ),
        ),
        if (_query.isEmpty && _history.isNotEmpty)
          SliverToBoxAdapter(
            child: SizedBox(
              height: 52,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                scrollDirection: Axis.horizontal,
                itemCount: _history.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, index) => ActionChip(
                  avatar: const Icon(Icons.history_rounded, size: 16),
                  label: Text(_history.reversed.elementAt(index)),
                  onPressed: () => _submit(_history.reversed.elementAt(index)),
                ),
              ),
            ),
          ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
          sliver: SliverToBoxAdapter(
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _query.isEmpty
                        ? 'Descubre'
                        : '${results.length} ${results.length == 1 ? 'resultado' : 'resultados'}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                _sortMenu(),
              ],
            ),
          ),
        ),
        if (results.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Text(
                'No encontramos resultados',
                style: TextStyle(color: HourTvMobileTokens.textSecondary),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            sliver: SliverGrid(
              key: const ValueKey('hourtv-mobile-search-results-grid'),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 16,
                crossAxisSpacing: 10,
                childAspectRatio: 120 / 218,
              ),
              delegate: SliverChildBuilderDelegate(
                (_, index) => HourTvPosterCard(
                  channel: visible[index],
                  onTap: () => widget.onOpen(visible[index]),
                  width: double.infinity,
                  assetFallback: _fallbackArtwork(index),
                ),
                childCount: visible.length,
              ),
            ),
          ),
      ],
    );
  }

  Widget _sortMenu() => MenuAnchor(
    alignmentOffset: const Offset(0, 4),
    style: MenuStyle(
      backgroundColor: const WidgetStatePropertyAll(
        HourTvMobileTokens.surfaceControl,
      ),
      surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: HourTvMobileTokens.borderSubtle),
        ),
      ),
    ),
    menuChildren: [
      for (final value in HourTvSearchSort.values)
        MenuItemButton(
          onPressed: () => setState(() {
            _sort = value;
            _visibleCount = _initialVisible;
          }),
          trailingIcon: value == _sort
              ? const Icon(
                  Icons.check_rounded,
                  color: HourTvMobileTokens.emerald,
                )
              : null,
          child: Text(_sortLabel(value)),
        ),
    ],
    builder: (_, menu, _) => SizedBox(
      height: HourTvMobileTokens.minimumTouchTarget,
      child: OutlinedButton.icon(
        onPressed: menu.isOpen ? menu.close : menu.open,
        icon: const Icon(Icons.swap_vert_rounded, size: 18),
        label: Text(_sortLabel(_sort)),
      ),
    ),
  );
  static int _year(Channel item) => int.tryParse(item.year ?? '') ?? 0;
  static String _sortLabel(HourTvSearchSort value) => switch (value) {
    HourTvSearchSort.newest => 'Más recientes',
    HourTvSearchSort.oldest => 'Más antiguos',
    HourTvSearchSort.titleAscending => 'Orden A–Z',
  };
  static String _normalize(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp('[áàäâã]'), 'a')
      .replaceAll(RegExp('[éèëê]'), 'e')
      .replaceAll(RegExp('[íìïî]'), 'i')
      .replaceAll(RegExp('[óòöôõ]'), 'o')
      .replaceAll(RegExp('[úùüû]'), 'u')
      .replaceAll('ñ', 'n')
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .trim();
}

/// Selector compacto de tipo de contenido para Mi Biblioteca: antes era una
/// fila de chips (Todo/Películas/Series) que ocupaba una franja completa
/// para solo tres opciones. Mismo lenguaje que el selector de categorías de
/// En Vivo: un botón chico que abre una hoja inferior.
class _LibraryFilterSelector extends StatelessWidget {
  const _LibraryFilterSelector({required this.value, required this.onChanged});

  static const _options = ['Todo', 'Películas', 'Series'];

  final String value;
  final ValueChanged<String> onChanged;

  Future<void> _open(BuildContext context) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: HourTvMobileTokens.surfacePrimary,
      barrierColor: Colors.black.withValues(alpha: .72),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: HourTvMobileTokens.borderSubtle,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'TIPO DE CONTENIDO',
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(letterSpacing: .3),
                ),
                const SizedBox(height: 14),
                for (final option in _options)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Material(
                      color: option == value
                          ? HourTvMobileTokens.emerald
                          : HourTvMobileTokens.surfaceControl,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        onTap: () => Navigator.pop(sheetContext, option),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          height: 48,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: option == value
                                  ? HourTvMobileTokens.emerald
                                  : HourTvMobileTokens.borderSubtle,
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  option.toUpperCase(),
                                  style: TextStyle(
                                    color: option == value
                                        ? HourTvMobileTokens.deepBlack
                                        : HourTvMobileTokens.textPrimary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              if (option == value)
                                Icon(
                                  Icons.check_rounded,
                                  color: HourTvMobileTokens.deepBlack,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
    if (selected != null) onChanged(selected);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: HourTvMobileTokens.surfacePrimary,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => unawaited(_open(context)),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: HourTvMobileTokens.borderSubtle),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.filter_list_rounded,
                color: HourTvMobileTokens.emerald,
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  value.toUpperCase(),
                  style: const TextStyle(
                    color: HourTvMobileTokens.textPrimary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: .2,
                  ),
                ),
              ),
              const Icon(
                Icons.expand_more_rounded,
                color: HourTvMobileTokens.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HourTvMobileLibrary extends StatefulWidget {
  const HourTvMobileLibrary({
    super.key,
    required this.store,
    required this.onOpen,
  });
  final ContentStore store;
  final ValueChanged<Channel> onOpen;

  @override
  State<HourTvMobileLibrary> createState() => _HourTvMobileLibraryState();
}

class _HourTvMobileLibraryState extends State<HourTvMobileLibrary> {
  var tab = 'Mi Lista';
  var filter = 'Todo';

  List<Channel> get _tabItems {
    switch (tab) {
      case 'Continuar viendo':
        return widget.store.continueWatching;
      case 'Historial':
        return widget.store.history;
      default:
        return widget.store.favorites;
    }
  }

  List<Channel> get _items {
    final base = _tabItems;
    switch (filter) {
      case 'Películas':
        return base.where((c) => c.type == MediaType.movie).toList();
      case 'Series':
        return base.where((c) => c.type == MediaType.series).toList();
      default:
        return base;
    }
  }

  (IconData, String, String) get _emptyState {
    switch (tab) {
      case 'Continuar viendo':
        return (
          Icons.play_circle_outline_rounded,
          'Nada en progreso',
          'Lo que empieces a ver aparece aquí para retomarlo.',
        );
      case 'Historial':
        return (
          Icons.history_rounded,
          'Sin reproducciones aún',
          'Lo que veas queda registrado aquí.',
        );
      default:
        return (
          Icons.bookmark_add_outlined,
          'Tu biblioteca está vacía',
          'Añade títulos desde Inicio para verlos aquí.',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    return CustomScrollView(
      key: const PageStorageKey('hourtv-mobile-library'),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
          sliver: SliverToBoxAdapter(
            child: Row(
              children: [
                const Icon(
                  Icons.bookmark_border_rounded,
                  color: HourTvMobileTokens.emerald,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'MI BIBLIOTECA',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(
                      context,
                    ).textTheme.headlineMedium?.copyWith(letterSpacing: .3),
                  ),
                ),
                const SizedBox(width: 8),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: HourTvMobileTokens.surfacePrimary,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    child: Text(
                      '${items.length} ${items.length == 1 ? 'TÍTULO' : 'TÍTULOS'}',
                      style: const TextStyle(
                        color: HourTvMobileTokens.emerald,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Antes era un carrusel horizontal: con solo 3 opciones, obligaba a
        // arrastrar para ver "Historial" en vez de mostrar las tres de una.
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          sliver: SliverToBoxAdapter(
            child: HourTvEvenTabs(
              labels: const ['Mi Lista', 'Continuar viendo', 'Historial'],
              selected: tab,
              onSelected: (value) => setState(() => tab = value),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          sliver: SliverToBoxAdapter(
            child: _LibraryFilterSelector(
              value: filter,
              onChanged: (value) => setState(() => filter = value),
            ),
          ),
        ),
        if (items.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _emptyState.$1,
                    color: HourTvMobileTokens.textMuted,
                    size: 44,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _emptyState.$2,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _emptyState.$3,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            sliver: SliverGrid.builder(
              itemCount: items.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 16,
                crossAxisSpacing: 10,
                childAspectRatio: 120 / 218,
              ),
              itemBuilder: (_, index) => HourTvPosterCard(
                channel: items[index],
                onTap: () => widget.onOpen(items[index]),
                width: double.infinity,
                assetFallback: _fallbackArtwork(index),
              ),
            ),
          ),
      ],
    );
  }
}

class HourTvMobileProfile extends StatelessWidget {
  const HourTvMobileProfile({
    super.key,
    required this.onOpenSetting,
    required this.onOpenAccount,
  });
  final ValueChanged<String> onOpenSetting;
  final VoidCallback onOpenAccount;

  @override
  Widget build(BuildContext context) {
    final activeProfile = StorageService.getSetting(
      'activeProfile',
      defaultValue: 'Invitado',
    ).toString();
    const settings = [
      (
        Icons.high_quality_outlined,
        'Reproducción y calidad',
        'Streaming, video y reproducción',
      ),
      (
        Icons.closed_caption_outlined,
        'Idioma y subtítulos',
        'Audio, idioma y apariencia',
      ),
      (Icons.settings_outlined, 'Configuración', 'Actualizaciones y más'),
      (Icons.shield_outlined, 'Control parental', 'Clasificación y seguridad'),
    ];
    return CustomScrollView(
      key: const PageStorageKey('hourtv-mobile-profile'),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
          sliver: SliverToBoxAdapter(
            child: Row(
              children: [
                const Icon(
                  Icons.person_outline_rounded,
                  color: HourTvMobileTokens.emerald,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Text(
                  'PERFIL',
                  style: Theme.of(
                    context,
                  ).textTheme.headlineMedium?.copyWith(letterSpacing: .3),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverToBoxAdapter(
            child: InkWell(
              onTap: onOpenAccount,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: HourTvMobileTokens.surfacePrimary,
                  border: Border.all(color: HourTvMobileTokens.borderSubtle),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    HourTvProfileAvatar(
                      profileName: activeProfile,
                      avatarSeed: StorageService.activeProfileAvatarId,
                      radius: 28,
                      backgroundColor: HourTvMobileTokens.emerald,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            activeProfile,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 3),
                          const Text(
                            'Toca para cambiar de perfil',
                            style: TextStyle(
                              fontSize: 11,
                              color: HourTvMobileTokens.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: HourTvMobileTokens.textMuted,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          sliver: SliverToBoxAdapter(
            child: HourTvSectionHeader(title: 'Ajustes'),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          sliver: SliverList.separated(
            itemCount: settings.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (_, index) => InkWell(
              onTap: () => onOpenSetting(settings[index].$2),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                constraints: const BoxConstraints(minHeight: 72),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: HourTvMobileTokens.surfacePrimary,
                  border: Border.all(color: HourTvMobileTokens.borderSubtle),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: HourTvMobileTokens.surfaceControl,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        settings[index].$1,
                        size: 20,
                        color: HourTvMobileTokens.emerald,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            settings[index].$2,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            settings[index].$3,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: HourTvMobileTokens.textMuted,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

String _fallbackArtwork(int index) {
  const assets = [
    'assets/figma/phase-3-1/poster-eclipse.png',
    'assets/figma/phase-3-1/poster-frontera.png',
    'assets/figma/phase-3-1/poster-herencia.png',
    'assets/figma/phase-3-1/poster-nacion-sin-ley.png',
    'assets/figma/phase-3-1/poster-penitenciaria.png',
    'assets/figma/phase-3-1/poster-renacer.png',
  ];
  return assets[index % assets.length];
}
