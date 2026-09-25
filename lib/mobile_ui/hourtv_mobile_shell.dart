import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/channel.dart';
import '../new_ui/hourtv_live_page.dart';
import '../new_ui/hourtv_new_shell.dart' show PreviewCatalog;
import '../new_ui/hourtv_series_detail_page.dart';
import '../new_ui/hourtv_profile_avatar.dart';
import '../new_ui/hourtv_profile_page.dart';
import '../new_ui/hourtv_settings_language_page.dart';
import '../new_ui/hourtv_settings_page.dart';
import '../new_ui/hourtv_settings_parental_page.dart';
import '../new_ui/hourtv_settings_playback_page.dart';
import '../services/catalog_presentation_index.dart';
import '../services/content_store.dart';
import '../services/device_type.dart';
import '../services/storage_service.dart';
import '../services/xtream_service.dart';
import 'hourtv_compact_filter_selector.dart';
import 'hourtv_genre_service.dart';
import 'hourtv_mobile_components.dart';
import 'hourtv_mobile_theme.dart';
import '../services/recommendations/recommendation_engine.dart';
import '../services/catalog/catalog_dtos.dart';
import '../services/catalog/catalog_repository.dart';
import '../services/catalog/catalog_detail_navigator.dart';
import '../services/image_resolution_service.dart';

enum HourTvMobileDestination { home, live, search, library, profile }

enum HourTvSearchSort { newest, oldest, titleAscending }

List<Channel> hourTvMobileCatalogContent(
  Iterable<Channel> channels,
  Iterable<XtreamSeries> structuredSeries, {
  Set<String> favoriteUrls = const <String>{},
}) {
  final output = <Channel>[
    ...structuredSeries
        .map(hourTvSeriesChannel)
        .map(
          (item) => item.copyWith(isFavorite: favoriteUrls.contains(item.url)),
        ),
    ...channels.where((item) => item.type != MediaType.live),
  ];
  final seen = <String>{};
  return [
    for (final item in output)
      if (seen.add(
        '${item.type.name}:${item.displayName.trim().toLowerCase()}',
      ))
        item,
  ];
}

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
  const HourTvMobileShell({
    super.key,
    this.store,
    this.destinationBuilders,
    this.catalogRepository,
    this.catalogPageSource,
    this.seriesPageSource,
    this.recommendationEngine,
  });

  final ContentStore? store;
  final Map<HourTvMobileDestination, WidgetBuilder>? destinationBuilders;
  final CatalogRepository? catalogRepository;
  final CatalogPageSource? catalogPageSource;
  final CatalogPageSource? seriesPageSource;
  final RecommendationEngine? recommendationEngine;

  @override
  State<HourTvMobileShell> createState() => _HourTvMobileShellState();
}

class _HourTvMobileShellState extends State<HourTvMobileShell>
    with WidgetsBindingObserver {
  late final store = widget.store ?? ContentStore.instance;
  var destination = HourTvMobileDestination.home;
  final Map<HourTvMobileDestination, Widget> _cachedPages = {};
  final ValueNotifier<bool> _isLiveActive = ValueNotifier<bool>(false);
  final ValueNotifier<int> _indexRevision = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _isLiveActive.value = (destination == HourTvMobileDestination.live);
    unawaited(store.ensureLoaded());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // Una publicación remota hecha mientras la app estaba en segundo plano
      // debe llegar al catálogo sin obligar a borrar datos o reinstalar.
      unawaited(store.maybeRefresh());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _isLiveActive.dispose();
    _indexRevision.dispose();
    super.dispose();
  }

  List<Channel> get _movies {
    if (store.movies.isNotEmpty) return store.movies;
    return store.loading ? const [] : PreviewCatalog.movies;
  }

  List<Channel>? _memoizedAllContent;
  CatalogPresentationIndex? _memoizedIndex;
  List<Channel>? _memoizedFeatured;
  Object? _lastVisibleAllRef;
  Object? _lastVisibleSeriesRef;
  int _lastFavoritesCount = -1;
  Object? _indexBuildTicket;

  List<Channel> get _allContent {
    final currentVisibleAll = store.visibleAll;
    final currentFavCount = store.favorites.length;
    final currentVisibleSeries = store.visibleSeries;

    if (_memoizedAllContent != null &&
        identical(_lastVisibleAllRef, currentVisibleAll) &&
        identical(_lastVisibleSeriesRef, currentVisibleSeries) &&
        _lastFavoritesCount == currentFavCount) {
      return _memoizedAllContent!;
    }

    final content = hourTvMobileCatalogContent(
      currentVisibleAll,
      currentVisibleSeries,
      favoriteUrls: store.favorites.map((item) => item.url).toSet(),
    );
    final resolved = content.isNotEmpty
        ? content
        : (store.loading ? const <Channel>[] : PreviewCatalog.movies);
    _memoizedAllContent = List<Channel>.unmodifiable(resolved);
    _lastVisibleAllRef = currentVisibleAll;
    _lastVisibleSeriesRef = currentVisibleSeries;
    _lastFavoritesCount = currentFavCount;

    _scheduleIndexRebuild(_memoizedAllContent!);

    return _memoizedAllContent!;
  }

  // El catálogo puede superar los miles de títulos (bulk publish), y
  // CatalogPresentationIndex.build() normaliza texto de cada uno. Hecho en
  // el hilo principal eso traba la navegación (Inicio/Buscar); se calcula
  // en un isolate y se aplica cuando esté listo, sin bloquear el frame.
  void _scheduleIndexRebuild(List<Channel> content) {
    final ticket = Object();
    _indexBuildTicket = ticket;
    _memoizedIndex = null;
    _memoizedFeatured = null;
    compute(
          CatalogPresentationIndex.build,
          content,
          debugLabel: 'catalog-index',
        )
        .then((index) {
          if (!mounted || !identical(_indexBuildTicket, ticket)) return;
          _memoizedIndex = index;
          _memoizedFeatured = index.featured(limit: 5);
          _indexRevision.value++;
        })
        .catchError((Object error, StackTrace stack) {
          if (!mounted || !identical(_indexBuildTicket, ticket)) return;
          // Search can retry asynchronously if the shared build fails.
          _indexBuildTicket = null;
          debugPrint('Catalog index failed: ${error.runtimeType}');
          _indexRevision.value++;
        });
  }

  List<Channel> get _liveChannels =>
      store.visibleAll.where((item) => item.type == MediaType.live).toList();

  List<Channel> get _liveChannelsOrPreview =>
      _liveChannels.isNotEmpty ? _liveChannels : PreviewCatalog.live;

  List<Channel> get _featured {
    if (_allContent.isEmpty) return const [];
    // El índice puede seguir construyéndose en el isolate; se actualiza
    // solo cuando esté listo (ver _scheduleIndexRebuild).
    return _memoizedFeatured ?? const [];
  }

  void _openDetails(Channel channel, {bool fromContinueWatching = false}) {
    CatalogDetailNavigator.openDetails(
      context,
      channel,
      repository: widget.catalogRepository,
      store: store,
      fromContinueWatching: fromContinueWatching,
      preview: PreviewCatalog.movies.any((item) => item.url == channel.url),
    );
  }

  void _setDestination(HourTvMobileDestination next) {
    if (destination == next) return;
    setState(() {
      destination = next;
      _isLiveActive.value = (next == HourTvMobileDestination.live);
    });
  }

  void _openAccount(BuildContext context) {
    final isTablet = DeviceProfile.isTablet(context);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          backgroundColor: HourTvMobileTokens.deepBlack,
          body: HourTvProfilePage(
            phone: !isTablet,
            tablet: isTablet,
            tv: false,
            onLoggedOut: () {},
          ),
        ),
      ),
    );
  }

  void _openSetting(BuildContext context, String label) {
    final page = switch (label) {
      'Reproducción y calidad' => const HourTvPlaybackSettingsPage(),
      'Idioma y subtítulos' => const HourTvLanguageSettingsPage(),
      'Control parental' => const HourTvParentalSettingsPage(),
      _ => const HourTvSettingsPage(),
    };
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }

  Widget _buildDestination(HourTvMobileDestination target) {
    if (widget.destinationBuilders != null &&
        widget.destinationBuilders!.containsKey(target)) {
      return widget.destinationBuilders![target]!(context);
    }
    return switch (target) {
      HourTvMobileDestination.home => ListenableBuilder(
        listenable: Listenable.merge([store, _indexRevision]),
        builder: (context, _) => HourTvMobileHome(
          movies: _movies,
          allContent: _allContent,
          featured: _featured,
          store: store,
          onOpen: _openDetails,
          onOpenContinue: (channel) =>
              _openDetails(channel, fromContinueWatching: true),
          onSearch: () => _setDestination(HourTvMobileDestination.search),
          onProfile: () => _setDestination(HourTvMobileDestination.profile),
          catalogRepository: widget.catalogRepository,
          moviesPageSource: widget.catalogPageSource,
          seriesPageSource: widget.seriesPageSource,
          recommendationEngine: widget.recommendationEngine,
        ),
      ),
      HourTvMobileDestination.live => ValueListenableBuilder<bool>(
        valueListenable: _isLiveActive,
        builder: (context, active, _) => HourTvLivePage(
          channels: _liveChannelsOrPreview,
          preview: _liveChannels.isEmpty,
          phone: !DeviceProfile.isTablet(context),
          tablet: DeviceProfile.isTablet(context),
          tv: false,
          active: active,
        ),
      ),
      HourTvMobileDestination.search => ListenableBuilder(
        listenable: Listenable.merge([store, _indexRevision]),
        builder: (context, _) => HourTvMobileSearch(
          content: _allContent,
          presentationIndex: _memoizedIndex,
          indexPending: _memoizedIndex == null && _indexBuildTicket != null,
          onOpen: _openDetails,
          catalogRepository: widget.catalogRepository,
          catalogPageSource: widget.catalogPageSource,
        ),
      ),
      HourTvMobileDestination.library => ListenableBuilder(
        listenable: store,
        builder: (context, _) => HourTvMobileLibrary(
          store: store,
          onOpen: _openDetails,
          onOpenContinue: (channel) =>
              _openDetails(channel, fromContinueWatching: true),
          catalogRepository: widget.catalogRepository,
        ),
      ),
      HourTvMobileDestination.profile => HourTvMobileProfile(
        onOpenAccount: () => _openAccount(context),
        onOpenSetting: (label) => _openSetting(context, label),
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    _cachedPages.putIfAbsent(destination, () => _buildDestination(destination));

    return Scaffold(
      backgroundColor: HourTvMobileTokens.deepBlack,
      body: SafeArea(
        bottom: false,
        child: Stack(
          fit: StackFit.expand,
          children: [
            for (final entry in _cachedPages.entries)
              Offstage(
                offstage: destination != entry.key,
                child: TickerMode(
                  enabled: destination == entry.key,
                  child: entry.value,
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: HourTvBottomNavigation(
        index: destination.index,
        onChanged: (index) =>
            _setDestination(HourTvMobileDestination.values[index]),
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
    this.featured,
    this.onOpenContinue,
    this.catalogRepository,
    this.moviesPageSource,
    this.seriesPageSource,
    this.recommendationEngine,
    this.initialRecommendations,
  });

  final List<Channel> movies;
  final List<Channel> allContent;
  final List<Channel>? featured;
  final ContentStore store;
  final ValueChanged<Channel> onOpen;

  /// Apertura desde la fila "Continuar viendo": si se provee, reanuda la
  /// posicion guardada directamente (sin dialogo de decision).
  final ValueChanged<Channel>? onOpenContinue;
  final VoidCallback onSearch;
  final VoidCallback onProfile;
  final CatalogRepository? catalogRepository;
  final CatalogPageSource? moviesPageSource;
  final CatalogPageSource? seriesPageSource;
  final RecommendationEngine? recommendationEngine;
  final List<RecommendationItem>? initialRecommendations;

  @override
  State<HourTvMobileHome> createState() => _HourTvMobileHomeState();
}

class _HourTvMobileHomeState extends State<HourTvMobileHome> {
  final ScrollController _scrollController = ScrollController();
  CatalogPageSource? _moviesPageSource;
  CatalogPageSource? _seriesPageSource;
  List<RecommendationItem> _recommendations = [];
  List<Channel> _cachedDriftMovies = const [];
  List<Channel> _cachedDriftSeries = const [];
  Timer? _genreWarmupTimer;
  List<Channel>? _memoizedFallbackFeatured;
  Object? _lastAllContentRef;

  List<Channel> _getFallbackFeatured(List<Channel> allContent) {
    if (allContent.isEmpty) return const <Channel>[];
    if (_memoizedFallbackFeatured != null &&
        identical(_lastAllContentRef, allContent)) {
      return _memoizedFallbackFeatured!;
    }
    _lastAllContentRef = allContent;
    _memoizedFallbackFeatured = const [];
    compute(CatalogPresentationIndex.build, allContent)
        .then((index) {
          if (!mounted || !identical(_lastAllContentRef, allContent)) return;
          setState(() => _memoizedFallbackFeatured = index.featured(limit: 5));
        })
        .catchError((Object error) {
          debugPrint('Featured index failed: ${error.runtimeType}');
        });
    return const [];
  }

  @override
  void initState() {
    super.initState();
    // Las filas de Inicio son previews virtualizadas. No paginar mientras el
    // usuario desliza: esa consulta provocaba reconstrucciones y jank. La
    // paginación completa vive en la pantalla de cada fila (Ver más).
    _initPageSources();
    // Las filas de Anime/K-Drama/Tendencia consultan todo el catálogo la
    // primera vez que se acceden. Prepararlas después del primer frame evita
    // que ese recorrido ocurra justo durante el gesto de scroll del usuario.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _genreWarmupTimer = Timer(const Duration(milliseconds: 250), () {
        if (!mounted) return;
        widget.store.anime;
        widget.store.kDramas;
        widget.store.trending;
      });
    });
    if (widget.initialRecommendations != null) {
      _recommendations = widget.initialRecommendations!;
    } else {
      _loadRecommendations();
    }
  }

  Future<void> _loadRecommendations() async {
    final engine = widget.recommendationEngine;
    if (engine == null) return;
    try {
      final activeProfileId = StorageService.activeProfileId;
      final isKids = StorageService.activeProfileIsKids;
      final recs = await engine.getRecommendations(
        profileId: activeProfileId,
        isKids: isKids,
        catalog: widget.allContent.isNotEmpty
            ? widget.allContent
            : widget.movies,
      );
      if (mounted) {
        setState(() => _recommendations = recs);
      }
    } catch (_) {}
  }

  void _initPageSources() {
    final repo =
        widget.catalogRepository ??
        (CatalogRepository.hasInstance ? CatalogRepository.instance : null);

    if (widget.moviesPageSource != null) {
      _moviesPageSource = widget.moviesPageSource;
    } else if (repo != null) {
      _moviesPageSource = CatalogPageSource(
        dao: repo.dao,
        mediaType: 'movie',
        pageSize: 20,
      );
      unawaited(_moviesPageSource!.loadInitialPage());
    }

    if (widget.seriesPageSource != null) {
      _seriesPageSource = widget.seriesPageSource;
    } else if (repo != null) {
      _seriesPageSource = CatalogPageSource(
        dao: repo.dao,
        mediaType: 'series',
        pageSize: 20,
      );
      unawaited(_seriesPageSource!.loadInitialPage());
    }

    _moviesPageSource?.addListener(_onSourceChanged);
    _seriesPageSource?.addListener(_onSourceChanged);
    _updateCachedChannels();
  }

  void _onSourceChanged() {
    if (!mounted) return;
    _updateCachedChannels();
    setState(() {});
  }

  void _updateCachedChannels() {
    if (_moviesPageSource != null && _moviesPageSource!.items.isNotEmpty) {
      _cachedDriftMovies = _moviesPageSource!.items
          .map(CatalogRepository.titleToChannel)
          .toList(growable: false);
    } else {
      _cachedDriftMovies = const [];
    }

    if (_seriesPageSource != null && _seriesPageSource!.items.isNotEmpty) {
      _cachedDriftSeries = _seriesPageSource!.items
          .map(CatalogRepository.titleToChannel)
          .toList(growable: false);
    } else {
      _cachedDriftSeries = const [];
    }
  }

  void _onHomeScroll() {
    // Compatibilidad con callers antiguos; deliberadamente no hace I/O.
  }

  @override
  void dispose() {
    _genreWarmupTimer?.cancel();
    _scrollController.dispose();
    _moviesPageSource?.removeListener(_onSourceChanged);
    _seriesPageSource?.removeListener(_onSourceChanged);
    if (widget.moviesPageSource == null) {
      _moviesPageSource?.dispose();
    }
    if (widget.seriesPageSource == null) {
      _seriesPageSource?.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final continueWatching = widget.store.continueWatching;
    final activeProfile = StorageService.getSetting(
      'activeProfile',
      defaultValue: 'Invitado',
    ).toString();

    final driftMovies = _cachedDriftMovies;
    final driftSeries = _cachedDriftSeries;

    // Las tablas Drift se sincronizan desde Supabase; el panel publica en el
    // catálogo JSON. Prioriza el catálogo publicado cuando ya está cargado y
    // conserva Drift como fallback de arranque/offline para no ocultar títulos
    // nuevos que todavía no existan en las tablas relacionales.
    final publishedMovies = widget.store.movies;
    final effectiveMovies = publishedMovies.isNotEmpty
        ? publishedMovies
        : driftMovies;
    final publishedSeries = widget.allContent
        .where((item) => item.type == MediaType.series)
        .toList(growable: false);
    final effectiveSeries = publishedSeries.isNotEmpty
        ? publishedSeries
        : driftSeries;

    final featuredChannels =
        widget.featured ?? _getFallbackFeatured(widget.allContent);

    final hasError =
        (_moviesPageSource != null && _moviesPageSource!.hasError) ||
        (widget.store.error != null &&
            widget.store.movies.isEmpty &&
            driftMovies.isEmpty &&
            driftSeries.isEmpty);

    final isLoading =
        (_moviesPageSource != null &&
            _moviesPageSource!.isLoading &&
            driftMovies.isEmpty &&
            driftSeries.isEmpty) ||
        (widget.store.loading &&
            widget.movies.isEmpty &&
            driftMovies.isEmpty &&
            driftSeries.isEmpty);

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        // Si la primera página todavía no llena la pantalla no habrá cambio
        // de posición en el ScrollController; el overscroll sigue siendo una
        // intención válida de pedir exactamente una página adicional.
        if (notification is OverscrollNotification) {
          _onHomeScroll();
        }
        return false;
      },
      child: CustomScrollView(
        key: const PageStorageKey('hourtv-mobile-home'),
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
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
          if (hasError)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              sliver: SliverToBoxAdapter(
                child: _LoadErrorBanner(
                  onRetry:
                      _moviesPageSource != null && _moviesPageSource!.hasError
                      ? () => unawaited(_moviesPageSource!.retry())
                      : null,
                ),
              ),
            ),
          // Catalogo real todavia sin llegar: un spinner en vez del contenido
          // de muestra evita el salto de "sale lo de prototipo y despues lo
          // real" en cada arranque.
          if (isLoading)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: HourTvBootLoading(),
            )
          else if (!hasError &&
              effectiveMovies.isEmpty &&
              effectiveSeries.isEmpty &&
              featuredChannels.isEmpty &&
              continueWatching.isEmpty &&
              _recommendations.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.tv_off_rounded,
                        color: HourTvMobileTokens.textMuted,
                        size: 48,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No hay contenido disponible',
                        style: TextStyle(
                          color: HourTvMobileTokens.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'El catálogo se encuentra vacío en este momento.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: HourTvMobileTokens.textMuted,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: () {
                          widget.store.retry();
                          widget.catalogRepository?.initialize();
                        },
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('Reintentar'),
                        style: FilledButton.styleFrom(
                          backgroundColor: HourTvMobileTokens.emerald,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else ...[
            if (featuredChannels.isNotEmpty)
              SliverToBoxAdapter(
                child: RepaintBoundary(
                  child: _HeroCarousel(
                    channels: featuredChannels,
                    onPlay: widget.onOpen,
                    onFavorite: widget.store.toggleFavorite,
                  ),
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
                child: RepaintBoundary(
                  child: SizedBox(
                    height: 220,
                    child: ListView.separated(
                      key: const PageStorageKey(
                        'hourtv-home-continue-watching',
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      scrollDirection: Axis.horizontal,
                      itemCount: continueWatching.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 12),
                      itemBuilder: (_, index) {
                        final item = continueWatching[index];
                        return HourTvPosterCard(
                          key: ValueKey('continue-${item.url}'),
                          channel: item,
                          progress: item.progressFraction,
                          secondaryProgressLabel: remainingLabel(item),
                          onTap: () =>
                              (widget.onOpenContinue ?? widget.onOpen)(item),
                          assetFallback: _fallbackArtwork(index),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
            if (_recommendations.isNotEmpty) ...[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                sliver: SliverToBoxAdapter(
                  child: HourTvSectionHeader(
                    title: 'Recomendado para ti',
                    actionLabel: _recommendations.first.reason,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: RepaintBoundary(
                  child: SizedBox(
                    height: 220,
                    child: ListView.separated(
                      key: const PageStorageKey('hourtv-home-recommendations'),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      scrollDirection: Axis.horizontal,
                      itemCount: _recommendations.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 12),
                      itemBuilder: (_, index) {
                        final item = _recommendations[index].channel;
                        return HourTvPosterCard(
                          key: ValueKey('rec-${item.url}'),
                          channel: item,
                          onTap: () => widget.onOpen(item),
                          assetFallback: _fallbackArtwork(index),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
            ..._homeRows(
              context,
              effectiveMovies: effectiveMovies,
              effectiveSeries: effectiveSeries,
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ],
      ),
    );
  }

  static const _rowPreview = 8;

  List<Widget> _homeRows(
    BuildContext context, {
    required List<Channel> effectiveMovies,
    required List<Channel> effectiveSeries,
  }) {
    final rows = <(String, List<Channel>)>[
      ('Películas', effectiveMovies),
      ('Series', effectiveSeries),
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
          child: RepaintBoundary(
            child: SizedBox(
              height: 220,
              child: ListView.separated(
                key: PageStorageKey('hourtv-home-row-${row.$1}'),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: math.min(row.$2.length, _rowPreview),
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (_, index) {
                  final channel = row.$2[index];
                  return HourTvPosterCard(
                    key: ValueKey('row-${row.$1}-${channel.url}'),
                    channel: channel,
                    onTap: () => widget.onOpen(channel),
                    assetFallback: _fallbackArtwork(index + 1),
                  );
                },
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

  /// Minutos restantes reales a partir de la duracion total (TMDB/Xtream) y
  /// el progreso guardado. Sin esos datos, no se inventa un tiempo.
  static String? remainingLabel(Channel channel) {
    final fraction = channel.progressFraction;
    final raw = channel.duration?.trim();
    if (fraction == null || raw == null || raw.isEmpty) return null;
    final totalMinutes = int.tryParse(
      RegExp(r'^(\d+)').firstMatch(raw)?.group(1) ?? '',
    );
    if (totalMinutes == null || totalMinutes <= 0) return null;
    final remaining = (totalMinutes * (1 - fraction)).round();
    return remaining <= 0 ? null : 'Quedan $remaining min';
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
  const _LoadErrorBanner({this.onRetry});

  final VoidCallback? onRetry;

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
          onPressed: onRetry ?? () => unawaited(ContentStore.instance.reload()),
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
  void didUpdateWidget(covariant _HeroCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.channels.isEmpty) {
      _page = 0;
      _timer?.cancel();
      return;
    }

    final bool identitiesChanged =
        widget.channels.length != oldWidget.channels.length ||
        !_sameChannels(widget.channels, oldWidget.channels);

    if (_page >= widget.channels.length) {
      _page = widget.channels.length - 1;
      if (_controller.hasClients) {
        _controller.jumpToPage(_page);
      }
    }

    if (identitiesChanged) {
      _page = _page.clamp(0, widget.channels.length - 1);
      if (_controller.hasClients) {
        _controller.jumpToPage(_page);
      }
      _scheduleAutoAdvance();
    }
  }

  bool _sameChannels(List<Channel> a, List<Channel> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].url != b[i].url) return false;
    }
    return true;
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
      key: const ValueKey('hourtv-hero-carousel'),
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
        variant: ImageResolutionVariant.heroBackdrop,
        memCacheWidth: 780,
        memCacheHeight: 439,
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

class HourTvMobileSearch extends StatefulWidget {
  const HourTvMobileSearch({
    super.key,
    required this.content,
    required this.onOpen,
    this.presentationIndex,
    this.indexPending = false,
    this.historyStore,
    this.catalogRepository,
    this.catalogPageSource,
  });
  final List<Channel> content;
  final ValueChanged<Channel> onOpen;
  final CatalogPresentationIndex? presentationIndex;
  final bool indexPending;
  final HourTvSearchHistoryStore? historyStore;
  final CatalogRepository? catalogRepository;
  final CatalogPageSource? catalogPageSource;

  @override
  State<HourTvMobileSearch> createState() => _HourTvMobileSearchState();
}

class _HourTvMobileSearchState extends State<HourTvMobileSearch> {
  static const _initialVisible = 18;
  static const _revealStep = 12;
  static const _types = ['Todo', 'Películas', 'Series', 'Anime', 'Novelas'];
  final controller = TextEditingController();
  final _scrollController = ScrollController();
  late final HourTvSearchHistoryStore _historyStore;
  CatalogPresentationIndex? _index;
  Object? _localIndexTicket;
  bool _indexFailed = false;
  List<Channel> _currentResults = const [];
  int _queryGeneration = 0;
  Timer? _debounce;
  List<String> _history = const <String>[];
  var _query = '';
  var _type = 'Todo';
  var _genre = HourTvGenreService.defaultGenre;
  var _sort = HourTvSearchSort.newest;
  var _visibleCount = _initialVisible;
  CatalogPageSource? _driftPageSource;
  List<Channel> _cachedDriftResults = const [];
  List<String> _cachedGenres = const [];

  @override
  void initState() {
    super.initState();
    _historyStore =
        widget.historyStore ?? SharedPreferencesHourTvSearchHistoryStore();
    _scrollController.addListener(_onScroll);

    final repo =
        widget.catalogRepository ??
        (CatalogRepository.hasInstance ? CatalogRepository.instance : null);

    if (widget.catalogPageSource != null) {
      _driftPageSource = widget.catalogPageSource;
      _driftPageSource!.addListener(_onDriftSourceChanged);
    } else if (repo != null) {
      _driftPageSource = CatalogPageSource(dao: repo.dao, pageSize: 20);
      _driftPageSource!.addListener(_onDriftSourceChanged);
      unawaited(_driftPageSource!.loadInitialPage());
    }

    _refreshIndex();
    _cachedGenres = _availableGenresForType(_type);
    _executeSearchSync();
    _updateDriftResults();
    unawaited(_loadHistory());
  }

  void _onDriftSourceChanged() {
    if (!mounted) return;
    _updateDriftResults();
    setState(() {});
  }

  void _updateDriftResults() {
    if (_driftPageSource != null && _driftPageSource!.items.isNotEmpty) {
      _cachedDriftResults = _driftPageSource!.items
          .map(CatalogRepository.titleToChannel)
          .toList(growable: false);
    } else {
      _cachedDriftResults = const [];
    }
  }

  static String? _toDriftMediaType(String type) => switch (type) {
    'Películas' => 'movie',
    'Series' => 'series',
    'Anime' => 'anime',
    _ => null,
  };

  String? get _driftGenreSlug => _genre == HourTvGenreService.defaultGenre
      ? null
      : HourTvGenreService.normalize(_genre);

  static CatalogSortOrder _toCatalogSortOrder(HourTvSearchSort sort) =>
      switch (sort) {
        HourTvSearchSort.newest => CatalogSortOrder.recent,
        HourTvSearchSort.oldest => CatalogSortOrder.recent,
        HourTvSearchSort.titleAscending => CatalogSortOrder.titleAsc,
      };

  void _executeDriftSearch() {
    if (_driftPageSource == null) return;
    _driftPageSource!.updateFilters(
      mediaType: _toDriftMediaType(_type),
      genreSlug: _driftGenreSlug,
      sort: _toCatalogSortOrder(_sort),
    );
    if (_query.isNotEmpty) {
      unawaited(_driftPageSource!.search(_query));
    } else {
      unawaited(_driftPageSource!.loadInitialPage());
    }
  }

  @override
  void didUpdateWidget(covariant HourTvMobileSearch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.presentationIndex != oldWidget.presentationIndex ||
        widget.indexPending != oldWidget.indexPending ||
        !identical(widget.content, oldWidget.content)) {
      _refreshIndex();
      _cachedGenres = _availableGenresForType(_type);
      if (_index != null &&
          _genre != HourTvGenreService.defaultGenre &&
          !_cachedGenres.contains(_genre)) {
        _genre = HourTvGenreService.defaultGenre;
        _visibleCount = _initialVisible;
      }
      _query = controller.text.trim();
      _executeSearchSync();
    }
  }

  void _refreshIndex() {
    final ticket = Object();
    _localIndexTicket = ticket;
    _index = widget.presentationIndex;
    _indexFailed = false;
    if (_index != null || widget.indexPending) return;
    compute(
          CatalogPresentationIndex.build,
          widget.content,
          debugLabel: 'search-index',
        )
        .then((index) {
          if (!mounted || !identical(_localIndexTicket, ticket)) return;
          setState(() {
            _index = index;
            _cachedGenres = _availableGenresForType(_type);
            _query = controller.text.trim();
            _executeSearchSync();
          });
        })
        .catchError((Object error) {
          if (!mounted || !identical(_localIndexTicket, ticket)) return;
          setState(() => _indexFailed = true);
        });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    controller.dispose();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    _driftPageSource?.removeListener(_onDriftSourceChanged);
    if (widget.catalogPageSource == null) {
      _driftPageSource?.dispose();
    }
    super.dispose();
  }

  Future<void> _loadHistory() async {
    final values = await _historyStore.load();
    if (!mounted) return;
    setState(() => _history = values.take(10).toList(growable: false));
  }

  static ContentTypeFilter _toContentTypeFilter(String type) => switch (type) {
    'Películas' => ContentTypeFilter.movies,
    'Series' => ContentTypeFilter.series,
    'Anime' => ContentTypeFilter.anime,
    'Novelas' => ContentTypeFilter.novels,
    _ => ContentTypeFilter.all,
  };

  static CatalogSort _toCatalogSort(HourTvSearchSort sort) => switch (sort) {
    HourTvSearchSort.newest => CatalogSort.newest,
    HourTvSearchSort.oldest => CatalogSort.oldest,
    HourTvSearchSort.titleAscending => CatalogSort.titleAscending,
  };

  void _executeSearchSync() {
    final currentGen = ++_queryGeneration;
    final query = CatalogQuery(
      text: _query,
      type: _toContentTypeFilter(_type),
      genre: _genre,
      sort: _toCatalogSort(_sort),
    );
    final results = _index?.search(query) ?? const <Channel>[];
    if (currentGen == _queryGeneration) {
      _currentResults = results;
    }
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    if (_history.isNotEmpty) {
      setState(() {});
    }
    final currentGen = ++_queryGeneration;
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted || currentGen != _queryGeneration) return;
      setState(() {
        _query = value.trim();
        _visibleCount = _initialVisible;
        _executeSearchSync();
        if (_driftPageSource != null) {
          _executeDriftSearch();
        }
      });
    });
  }

  Future<void> _clearHistory() async {
    if (_history.isEmpty) return;
    setState(() => _history = const <String>[]);
    await _historyStore.save(const <String>[]);
  }

  Future<void> _removeHistoryItem(String item) async {
    final next = _history
        .where((element) => element != item)
        .toList(growable: false);
    setState(() => _history = next);
    await _historyStore.save(next);
  }

  Future<void> _submit([String? value]) async {
    _debounce?.cancel();
    final queryText = (value ?? controller.text).trim();
    if (value != null) {
      controller
        ..text = value
        ..selection = TextSelection.collapsed(offset: value.length);
    }
    setState(() {
      _query = queryText;
      _visibleCount = _initialVisible;
      _executeSearchSync();
      if (_driftPageSource != null) {
        _executeDriftSearch();
      }
    });
    debugPrint(
      '[PERF_SEARCH] QUERY_SUBMITTED: "$queryText" time=${DateTime.now().millisecondsSinceEpoch}',
    );
    if (queryText.isEmpty) return;
    final normalized = HourTvGenreService.normalize(queryText);
    final next = <String>[
      ..._history.where(
        (item) => HourTvGenreService.normalize(item) != normalized,
      ),
      queryText,
    ];
    if (next.length > 10) next.removeRange(0, next.length - 10);
    setState(() => _history = List<String>.unmodifiable(next));
    await _historyStore.save(_history);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.extentAfter >= 600) return;
    final bool useDrift =
        _driftPageSource != null &&
        _query.isEmpty &&
        (_hasActiveFilters || _cachedDriftResults.isNotEmpty);
    if (useDrift) {
      if (_driftPageSource!.hasMore && !_driftPageSource!.isLoading) {
        unawaited(_driftPageSource!.loadNextPage());
      }
      return;
    }
    final total = _currentResults.length;
    if (_visibleCount >= total) return;
    setState(() {
      _visibleCount = math.min(_visibleCount + _revealStep, total);
    });
  }

  List<String> _availableGenresForType(String type) {
    return _index?.genresFor(_toContentTypeFilter(type)) ??
        const [HourTvGenreService.defaultGenre];
  }

  void _onTypeChanged(String newType) {
    setState(() {
      _type = newType;
      _visibleCount = _initialVisible;
      _cachedGenres = _availableGenresForType(newType);
      if (_genre != HourTvGenreService.defaultGenre &&
          !_cachedGenres.contains(_genre)) {
        _genre = HourTvGenreService.defaultGenre;
      }
      _executeSearchSync();
      if (_driftPageSource != null) {
        _executeDriftSearch();
      }
    });
  }

  void _onGenreChanged(String newGenre) {
    setState(() {
      _genre = newGenre;
      _visibleCount = _initialVisible;
      _executeSearchSync();
      if (_driftPageSource != null) {
        _executeDriftSearch();
      }
    });
  }

  bool get _hasActiveFilters =>
      _query.isNotEmpty ||
      _type != 'Todo' ||
      _genre != HourTvGenreService.defaultGenre;

  @override
  Widget build(BuildContext context) {
    // La búsqueda por texto nunca debe usar Drift: esa base local solo se
    // sincroniza desde las tablas relacionales de Supabase (titles/sources),
    // que el panel no llena al publicar (solo actualiza catalog.json). Un
    // título nuevo puede tardar indefinidamente en llegar ahí, o no llegar
    // nunca. El índice en memoria (_currentResults) sí se arma desde el
    // catálogo real que el panel publica, así que es la única fuente
    // confiable en cuanto hay texto escrito.
    final bool useDrift =
        _driftPageSource != null &&
        _query.isEmpty &&
        (_hasActiveFilters || _cachedDriftResults.isNotEmpty);
    final List<Channel> resultsList = useDrift
        ? _cachedDriftResults
        : _currentResults;
    final visible = useDrift
        ? resultsList
        : resultsList.take(_visibleCount).toList(growable: false);

    if (_query.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        debugPrint(
          '[PERF_SEARCH] SEARCH_RENDERED: query="$_query" count=${visible.length} time=${DateTime.now().millisecondsSinceEpoch}',
        );
      });
    }

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
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          sliver: SliverToBoxAdapter(
            child: Row(
              children: [
                Expanded(
                  child: HourTvCompactFilterSelector(
                    key: const ValueKey('hourtv-filter-type-selector'),
                    label: 'TIPO',
                    value: _type,
                    options: _types,
                    icon: Icons.layers_rounded,
                    sheetTitle: 'Tipo de contenido',
                    sheetSubtitle: 'Selecciona un tipo',
                    onChanged: _onTypeChanged,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: HourTvCompactFilterSelector(
                    key: const ValueKey('hourtv-filter-genre-selector'),
                    label: 'GÉNERO',
                    value: _genre,
                    options: _cachedGenres,
                    icon: Icons.category_rounded,
                    sheetTitle: 'Géneros',
                    sheetSubtitle: 'Selecciona un género',
                    onChanged: _onGenreChanged,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (controller.text.trim().isEmpty && _history.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.history_rounded,
                        size: 16,
                        color: HourTvMobileTokens.textMuted,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'BÚSQUEDAS RECIENTES',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: HourTvMobileTokens.textMuted,
                          letterSpacing: .4,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        key: const ValueKey('hourtv-search-clear-history'),
                        onPressed: _clearHistory,
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(40, 24),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          'Borrar',
                          style: TextStyle(
                            color: HourTvMobileTokens.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final item in _history.reversed)
                        InputChip(
                          key: ValueKey('hourtv-search-history-$item'),
                          label: Text(
                            item,
                            style: const TextStyle(
                              color: HourTvMobileTokens.textPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          avatar: const Icon(
                            Icons.history_rounded,
                            size: 16,
                            color: HourTvMobileTokens.emerald,
                          ),
                          deleteIcon: const Icon(
                            Icons.close_rounded,
                            size: 14,
                            color: HourTvMobileTokens.textMuted,
                          ),
                          onDeleted: () => unawaited(_removeHistoryItem(item)),
                          onPressed: () => _submit(item),
                          backgroundColor: HourTvMobileTokens.surfaceControl,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                            side: const BorderSide(
                              color: HourTvMobileTokens.borderSubtle,
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                        ),
                    ],
                  ),
                ],
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
                    !_hasActiveFilters
                        ? 'Descubre'
                        : '${resultsList.length} ${resultsList.length == 1 ? 'resultado' : 'resultados'}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                _sortMenu(),
              ],
            ),
          ),
        ),
        if (_index == null && !useDrift)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: _indexFailed
                  ? TextButton(
                      onPressed: () => setState(_refreshIndex),
                      child: const Text('Reintentar cargar catálogo'),
                    )
                  : const CircularProgressIndicator(
                      key: ValueKey('catalog-index-loading'),
                      color: HourTvMobileTokens.emerald,
                    ),
            ),
          )
        else if (useDrift && _driftPageSource!.hasError)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            sliver: SliverToBoxAdapter(
              child: _LoadErrorBanner(
                onRetry: () => unawaited(_driftPageSource!.retry()),
              ),
            ),
          )
        else if (useDrift && _driftPageSource!.isLoading && resultsList.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: CircularProgressIndicator(
                color: HourTvMobileTokens.emerald,
              ),
            ),
          )
        else if (resultsList.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.search_off_rounded,
                      color: HourTvMobileTokens.textMuted,
                      size: 40,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'No hay coincidencias con los filtros actuales',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: HourTvMobileTokens.textSecondary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
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
                (_, index) => RepaintBoundary(
                  child: HourTvPosterCard(
                    channel: visible[index],
                    onTap: () => widget.onOpen(visible[index]),
                    width: double.infinity,
                    assetFallback: _fallbackArtwork(index),
                  ),
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
            if (_driftPageSource != null) {
              _executeDriftSearch();
            } else {
              _executeSearchSync();
            }
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
  static String _sortLabel(HourTvSearchSort value) => switch (value) {
    HourTvSearchSort.newest => 'Más recientes',
    HourTvSearchSort.oldest => 'Más antiguos',
    HourTvSearchSort.titleAscending => 'Orden A–Z',
  };
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
    this.onOpenContinue,
    this.catalogRepository,
  });
  final ContentStore store;
  final ValueChanged<Channel> onOpen;
  final ValueChanged<Channel>? onOpenContinue;
  final CatalogRepository? catalogRepository;

  @override
  State<HourTvMobileLibrary> createState() => _HourTvMobileLibraryState();
}

class _HourTvMobileLibraryState extends State<HourTvMobileLibrary> {
  var tab = 'Mi Lista';
  var filter = 'Todo';
  final Map<String, Channel> _driftResolved = {};

  @override
  void initState() {
    super.initState();
    _resolveDriftItems();
  }

  @override
  void didUpdateWidget(HourTvMobileLibrary oldWidget) {
    super.didUpdateWidget(oldWidget);
    _resolveDriftItems();
  }

  Future<void> _resolveDriftItems() async {
    final repo =
        widget.catalogRepository ??
        (CatalogRepository.hasInstance ? CatalogRepository.instance : null);
    if (repo == null) return;

    final base = _tabRawItems;
    var updated = false;

    for (final ch in base) {
      final stable = ch.stableTitleId;
      final titleId = (stable != null && stable.isNotEmpty)
          ? stable
          : (ch.tvgId?.isNotEmpty == true ? ch.tvgId! : ch.name);
      if (_driftResolved.containsKey(titleId)) continue;

      try {
        final title = await repo.dao.getTitleById(titleId);
        if (title != null) {
          if (title.mediaType == 'series') {
            final series = await repo.hydrateSeries(title.id);
            if (series != null) {
              _driftResolved[titleId] = Channel(
                name: series.name,
                url:
                    series.episodes?.isNotEmpty == true &&
                        series.episodes!.first.url.isNotEmpty
                    ? series.episodes!.first.url
                    : 'catalog://${series.seriesId}',
                logo: series.cover ?? title.posterUrl,
                backdrop: series.backdrop ?? title.backdropUrl,
                tvgId: series.seriesId,
                plot: series.plot ?? title.plot,
                year: series.year ?? title.year?.toString(),
                rating: series.rating ?? title.rating?.toString(),
                duration: series.duration ?? title.duration,
                cast: series.cast ?? title.castMembers,
                director: series.director ?? title.director,
                writer: series.writer ?? title.writer,
                forcedType: 'series',
                catalogTitleId: series.seriesId,
                isFavorite: ch.isFavorite,
                progressFraction: ch.progressFraction,
                lastWatched: ch.lastWatched,
              );
              updated = true;
            }
          } else {
            final hydratedCh = await repo.hydrateChannel(title.id);
            if (hydratedCh != null) {
              _driftResolved[titleId] = hydratedCh.copyWith(
                isFavorite: ch.isFavorite,
                progressFraction: ch.progressFraction,
                lastWatched: ch.lastWatched,
              );
              updated = true;
            }
          }
        }
      } catch (_) {}
    }

    if (updated && mounted) {
      setState(() {});
    }
  }

  List<Channel> get _tabRawItems {
    switch (tab) {
      case 'Continuar viendo':
        return widget.store.continueWatching;
      case 'Historial':
        return widget.store.history;
      default:
        return widget.store.favorites;
    }
  }

  List<Channel> get _tabItems {
    final raw = _tabRawItems;
    return raw.map((ch) {
      final stable = ch.stableTitleId;
      final titleId = (stable != null && stable.isNotEmpty)
          ? stable
          : (ch.tvgId?.isNotEmpty == true ? ch.tvgId! : ch.name);
      final resolved = _driftResolved[titleId];
      if (resolved != null) {
        return resolved.copyWith(
          isFavorite: ch.isFavorite,
          progressFraction: ch.progressFraction,
          lastWatched: ch.lastWatched,
        );
      }
      return ch;
    }).toList();
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
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'MI BIBLIOTECA',
                      maxLines: 1,
                      style: Theme.of(
                        context,
                      ).textTheme.headlineMedium?.copyWith(letterSpacing: .3),
                    ),
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
              onSelected: (value) {
                setState(() => tab = value);
                _resolveDriftItems();
              },
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
                onTap: () {
                  final channel = items[index];
                  if (tab == 'Continuar viendo' &&
                      widget.onOpenContinue != null) {
                    widget.onOpenContinue!(channel);
                  } else {
                    widget.onOpen(channel);
                  }
                },
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
