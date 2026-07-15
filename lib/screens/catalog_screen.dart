import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/channel.dart';
import '../services/content_store.dart';
import '../services/device_type.dart';
import '../services/storage_service.dart';
import '../services/tmdb_service.dart';
import '../services/xtream_service.dart';
import '../theme/app_theme.dart';
import '../widgets/tv_focusable.dart';
import 'movie_detail_screen.dart';
import 'player_screen.dart';
import 'search_screen.dart';
import 'series_detail_screen.dart';

/// Pestaña INICIO: catálogo de VIDEO BAJO DEMANDA (películas y series) estilo
/// Netflix/Stremio. NO muestra canales en vivo (eso vive en la pestaña En Vivo).
class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key});
  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  final _store = ContentStore.instance;

  double get _posterWidth {
    if (DeviceProfile.isTv(context)) return 118 * _s;
    final available = MediaQuery.sizeOf(context).width - 28;
    return (available / 3.2).clamp(96.0, 132.0);
  }

  double get _posterHeight => _posterWidth * 1.5;
  double get _posterRowHeight => _posterHeight + 30 * _s;

  /// Categoría activa: 'all' (Recomendado), un género de película, o 'series'.
  String _cat = 'all';

  /// Banner rotativo del Inicio en móvil/tablet (estilo UltraPelis).
  Timer? _bannerTimer;
  int _bannerIdx = 0;

  /// Contenido que muestra el billboard en TV: el último póster enfocado
  /// con D-pad (estilo Netflix). Null = la primera película destacada.
  Channel? _spotlight;
  Timer? _spotlightDebounce;
  int _spotlightRequest = 0;

  @override
  void initState() {
    super.initState();
    _store.addListener(_onChange);
    _store.ensureLoaded();
    _bannerTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || _cat == 'series') return;
      if (DeviceProfile.isTv(context)) {
        return; // en TV el billboard sigue al foco
      }
      final n = _store.movies.where((m) => m.logo != null).length;
      if (n > 1) setState(() => _bannerIdx = (_bannerIdx + 1) % n);
    });
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _spotlightDebounce?.cancel();
    _spotlightRequest++;
    _store.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  void _onPosterFocus(Channel channel, bool focused) {
    if (!DeviceProfile.isTv(context)) return;

    _spotlightDebounce?.cancel();
    final request = ++_spotlightRequest;
    if (!focused) return;

    if (!identical(_spotlight, channel)) {
      setState(() => _spotlight = channel);
    }

    _spotlightDebounce = Timer(const Duration(milliseconds: 400), () async {
      var changed = await XtreamService.enrichMovieMetadata(channel);
      changed = await TmdbService.enrich(channel) || changed;
      if (!mounted ||
          request != _spotlightRequest ||
          !identical(_spotlight, channel)) {
        return;
      }
      if (changed) setState(() {});
    });
  }

  void _play(Channel ch, List<Channel> ctx) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            PlayerScreen(channel: ch, allChannels: ctx.isEmpty ? [ch] : ctx),
      ),
    );
  }

  void _openDetails(Channel ch, List<Channel> ctx) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MovieDetailScreen(channel: ch, allChannels: ctx),
      ),
    );
  }

  Future<void> _openSearch() async {
    final seriesByUrl = <String, XtreamSeries>{
      for (final item in _store.series) 'hourtv-series:${item.seriesId}': item,
    };
    final searchItems = <Channel>[
      ..._store.movies,
      for (final item in _store.series)
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
    _openDetails(picked, _store.movies);
  }

  bool get _vodLoading => _store.moviesLoading || _store.vodLoading;

  /// Escala 10 pies (1.0 en móvil/tablet, 1.5 en TV) y margen de overscan.
  double get _s => DeviceProfile.uiScale(context);
  double get _pad => DeviceProfile.overscan(context);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: _pad),
        child: Column(
          children: [
            _topBar(),
            _categoryChips(),
            Expanded(child: _content()),
          ],
        ),
      ),
    );
  }

  Widget _topBar() => Padding(
    padding: EdgeInsets.fromLTRB(18, 12 * _s, 12, 6),
    child: Row(
      children: [
        Container(
          width: 30 * _s,
          height: 30 * _s,
          decoration: BoxDecoration(
            gradient: AppTheme.accentGradient,
            borderRadius: BorderRadius.circular(8 * _s),
          ),
          child: Icon(
            Icons.play_arrow_rounded,
            color: Colors.white,
            size: 20 * _s,
          ),
        ),
        const SizedBox(width: 9),
        ShaderMask(
          shaderCallback: (b) => AppTheme.accentGradient.createShader(b),
          child: Text(
            'Hour',
            style: TextStyle(
              color: Colors.white,
              fontSize: 19 * _s,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Text(
          'TV',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 19 * _s,
            fontWeight: FontWeight.w300,
          ),
        ),
        const Spacer(),
        if (_vodLoading)
          const Padding(
            padding: EdgeInsets.only(right: 6),
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.accent,
              ),
            ),
          ),
        IconButton(
          icon: Icon(
            Icons.filter_list_rounded,
            color: AppColors.textPrimary,
            size: 24 * _s,
          ),
          onPressed: _openFilter,
        ),
        IconButton(
          icon: Icon(
            Icons.search_rounded,
            color: AppColors.textPrimary,
            size: 24 * _s,
          ),
          onPressed: _openSearch,
        ),
      ],
    ),
  );

  /// Panel de filtros estilo UltraPelis: lista de categorías a pantalla.
  Future<void> _openFilter() async {
    final cats = _cats;
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surfaceDark,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(ctx).height * 0.75,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 8, 4),
                child: Row(
                  children: [
                    Text(
                      'Categorías',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 18 * _s,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        color: AppColors.textPrimary,
                      ),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final c in cats)
                      ListTile(
                        autofocus: c.id == _cat && DeviceProfile.isTv(context),
                        leading: Icon(
                          _catIcon(c.id),
                          color: c.id == _cat
                              ? AppColors.accent
                              : AppColors.textSecondary,
                          size: 20 * _s,
                        ),
                        title: Text(
                          c.label,
                          style: TextStyle(
                            color: c.id == _cat
                                ? AppColors.accent
                                : AppColors.textPrimary,
                            fontSize: 15 * _s,
                          ),
                        ),
                        onTap: () => Navigator.pop(ctx, c.id),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (picked != null && mounted) setState(() => _cat = picked);
  }

  IconData _catIcon(String id) {
    final k = id.toLowerCase();
    if (id == 'all') return Icons.recommend_rounded;
    if (id == 'movies') return Icons.local_movies_rounded;
    if (id == 'series') return Icons.tv_rounded;
    if (k.contains('terror')) return Icons.dark_mode_rounded;
    if (k.contains('acci')) return Icons.local_fire_department_rounded;
    if (k.contains('comedia')) return Icons.sentiment_very_satisfied_rounded;
    if (k.contains('roman')) return Icons.favorite_rounded;
    if (k.contains('aventura')) return Icons.terrain_rounded;
    if (k.contains('infantil') ||
        k.contains('anima') ||
        k.contains('familia')) {
      return Icons.child_care_rounded;
    }
    if (k.contains('documental')) return Icons.video_library_rounded;
    if (k.contains('cienc')) return Icons.rocket_launch_rounded;
    return Icons.local_movies_rounded;
  }

  /// Inicio conserva cinco destinos editoriales, sin categorías de fuentes.
  List<({String id, String label})> get _cats => const [
    (id: 'all', label: 'Recomendado'),
    (id: 'movies', label: 'Películas'),
    (id: 'series', label: 'Series'),
    (id: 'Infantil', label: 'Infantil'),
    (id: 'Anime', label: 'Anime'),
  ];

  /// Fila de categorías estilo UltraPelis: texto plano, la activa en rojo.
  Widget _categoryChips() {
    final cats = _cats;
    return SizedBox(
      height: 40 * _s,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        itemCount: cats.length,
        itemBuilder: (ctx, i) {
          final c = cats[i];
          final sel = c.id == _cat;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
            child: TvFocusable(
              onTap: () => setState(() => _cat = c.id),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 10 * _s),
                alignment: Alignment.center,
                child: Text(
                  c.label,
                  style: TextStyle(
                    color: sel ? AppColors.accent : AppColors.textSecondary,
                    fontSize: 14 * _s,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // --------- Filtros por año/calificación (usa metadata cuando existe) ---------

  List<Channel> _byYear(List<Channel> src, {int? min, int? max}) =>
      src.where((m) {
        final y = int.tryParse(m.year?.trim() ?? '');
        if (y == null) return false;
        if (min != null && y < min) return false;
        if (max != null && y > max) return false;
        return true;
      }).toList();

  List<Channel> _byRating(List<Channel> src, double min) => src
      .where((m) => (double.tryParse(m.rating?.trim() ?? '') ?? 0) >= min)
      .toList();

  List<XtreamSeries> _seriesForCategory(String category) {
    final target = category.toLowerCase();
    return _store.series
        .where((item) {
          final values = [
            item.genre ?? '',
            ...item.categories,
          ].join(' ').toLowerCase();
          if (target == 'anime') return values.contains('anime');
          if (target == 'infantil') {
            return values.contains('infantil') ||
                values.contains('kids') ||
                values.contains('children') ||
                values.contains('famil');
          }
          return false;
        })
        .toList(growable: false);
  }

  Widget _content() {
    if (_cat == 'series') return _seriesTab();
    final movies = _store.movies;
    if (movies.isEmpty && _store.series.isEmpty) {
      if (_vodLoading) return _loading('Cargando catálogo...');
      return _vodEmpty('contenido');
    }

    final recommended = _cat == 'all';
    final moviesTab = _cat == 'movies';
    final editorialCategory = _cat == 'Infantil' || _cat == 'Anime';
    final catMovies = editorialCategory ? _store.moviesByGenre(_cat) : movies;
    final catSeries = editorialCategory
        ? _seriesForCategory(_cat)
        : const <XtreamSeries>[];
    if (editorialCategory && catMovies.isEmpty && catSeries.isEmpty) {
      if (_vodLoading) return _loading('Cargando $_cat...');
      return _vodEmpty(_cat.toLowerCase());
    }

    final recent = recommended
        ? StorageService.loadRecent()
              .where((channel) => channel.type != MediaType.live)
              .toList(growable: false)
        : const <Channel>[];
    final year = DateTime.now().year;
    final terror = recommended
        ? _store.moviesByGenre('Terror')
        : const <Channel>[];

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        if (recommended || moviesTab) _hero(),
        if (editorialCategory && catMovies.isNotEmpty)
          _movieRow(
            _cat == 'Anime' ? 'Películas de anime' : 'Películas infantiles',
            catMovies,
          ),
        if (editorialCategory && catSeries.isNotEmpty)
          _seriesRow(
            title: _cat == 'Anime' ? 'Series de anime' : 'Series infantiles',
            items: catSeries,
          ),
        if (recent.isNotEmpty) _movieRow('Continuar viendo', recent),
        if (recommended || moviesTab) ...[
          _movieRow('Estrenos $year', _byYear(movies, min: year - 1)),
          _movieRow('Películas Más Populares', _byRating(movies, 7.5)),
          _movieRow('Películas Antiguas', _byYear(movies, max: 2010)),
        ],
        if (terror.isNotEmpty) _movieRow('Para No Dormir', terror),
        if (recommended && _store.series.isNotEmpty) _seriesRow(),
      ],
    );
  }

  // --------- Hero: banner rotativo (móvil/tablet) o billboard (TV) ---------
  Widget _hero() {
    final candidates = _store.movies.where((m) => m.logo != null).toList();
    final movies = [
      ...candidates.where((movie) => movie.isFeatured),
      ...candidates.where((movie) => !movie.isFeatured),
    ];
    if (movies.isEmpty) return const SizedBox.shrink();
    if (DeviceProfile.isTv(context)) {
      return _tvBillboard(_spotlight ?? movies.first);
    }
    // Banner estilo UltraPelis: imagen a lo ancho, rota sola y es clickeable.
    final f = movies[_bannerIdx % movies.length];
    return Padding(
      padding: const EdgeInsets.fromLTRB(15, 8, 15, 6),
      child: TvFocusable(
        onTap: () => _openDetails(f, movies),
        borderRadius: BorderRadius.circular(6),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 220 * _s,
            width: double.infinity,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 700),
              switchInCurve: Curves.easeOut,
              child: Stack(
                key: ValueKey(f.url),
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: f.backdrop ?? f.logo!,
                    fit: BoxFit.cover,
                    // Si la imagen falla, un gradiente de marca en vez de un
                    // rectangulo negro que parece roto.
                    errorWidget: (_, _, _) => Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppColors.accent.withValues(alpha: 0.55),
                            AppColors.cardDark,
                            AppColors.primaryDark,
                          ],
                        ),
                      ),
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        f.displayName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20 * _s,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  // Franja inferior con el título, legible sobre la imagen
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(14, 26, 14, 10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.85),
                            Colors.transparent,
                          ],
                        ),
                      ),
                      child: Text(
                        f.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16 * _s,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
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

  /// Billboard de TV a sangre completa (estilo Netflix): la imagen del
  /// contenido enfocado ocupa el ancho, con degradado hacia el fondo y el
  /// texto a la izquierda. Cambia al mover el foco por los pósters.
  Widget _tvBillboard(Channel f) {
    final h = MediaQuery.sizeOf(context).height * 0.42;
    return SizedBox(
      height: h,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Imagen alineada a la derecha (el póster no se estira de más)
          Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              width: MediaQuery.sizeOf(context).width * 0.62,
              child: (f.backdrop ?? f.logo) != null
                  ? CachedNetworkImage(
                      imageUrl: (f.backdrop ?? f.logo)!,
                      fit: BoxFit.cover,
                      fadeInDuration: const Duration(milliseconds: 220),
                      errorWidget: (_, _, _) => const SizedBox(),
                    )
                  : const SizedBox(),
            ),
          ),
          // Degradado horizontal (texto legible) y vertical (funde con el fondo)
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  AppColors.primaryDark,
                  AppColors.primaryDark,
                  Colors.transparent,
                ],
                stops: [0.0, 0.38, 0.75],
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  AppColors.primaryDark,
                  AppColors.primaryDark.withValues(alpha: 0.0),
                ],
                stops: const [0.0, 0.45],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _heroBadge(),
                const SizedBox(height: 12),
                SizedBox(
                  width: MediaQuery.sizeOf(context).width * 0.45,
                  child: Text(
                    f.displayName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                    ),
                  ),
                ),
                _billboardMetadata(f),
                if (f.plot?.trim().isNotEmpty == true) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: MediaQuery.sizeOf(context).width * 0.45,
                    child: Text(
                      f.plot!,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12.5 * _s,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                _heroPlayButton(f),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _billboardMetadata(Channel content) {
    final parts = <String>[];
    final year = content.year?.trim();
    final duration = content.duration?.trim();
    final rating = content.rating?.trim();
    final genre = content.genre?.trim();

    if (year?.isNotEmpty == true) parts.add(year!);
    if (duration?.isNotEmpty == true) parts.add(duration!);
    if (rating?.isNotEmpty == true) parts.add('★ $rating');
    if (genre?.isNotEmpty == true) parts.add(genre!.toUpperCase());
    if (parts.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        parts.join('  •  '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: AppColors.accentLight,
          fontSize: 12 * _s,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.35,
        ),
      ),
    );
  }

  Widget _heroBadge() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: AppColors.accent,
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      'DESTACADA',
      style: TextStyle(
        color: Colors.white,
        fontSize: 10 * _s,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.5,
      ),
    ),
  );

  Widget _heroPlayButton(Channel f) => TvFocusable(
    onTap: () => _play(f, _store.movies),
    borderRadius: BorderRadius.circular(10),
    child: Container(
      padding: EdgeInsets.symmetric(horizontal: 18 * _s, vertical: 9 * _s),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.play_arrow_rounded, color: Colors.black, size: 20 * _s),
          const SizedBox(width: 6),
          Text(
            'Reproducir',
            style: TextStyle(
              color: Colors.black,
              fontSize: 14 * _s,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    ),
  );

  // --------- Fila de películas ---------
  Widget _movieRow(String title, List<Channel> items) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
          child: Row(
            children: [
              Text(
                title,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16 * _s,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${items.length}',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12 * _s),
              ),
            ],
          ),
        ),
        SizedBox(
          height: _posterRowHeight,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            itemCount: items.length > 40 ? 40 : items.length,
            itemBuilder: (ctx, i) => _posterCard(items[i], items),
          ),
        ),
      ],
    );
  }

  Widget _posterCard(Channel ch, List<Channel> ctx) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 5),
    child: TvFocusable(
      onTap: () => _openDetails(ch, ctx),
      onFocusChange: (focused) => _onPosterFocus(ch, focused),
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: _posterWidth,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: _posterWidth,
                height: _posterHeight,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ColoredBox(
                      color: AppColors.cardElevated,
                      child: ch.logo != null && ch.logo!.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: ch.logo!,
                              fit: BoxFit.cover,
                              placeholder: (_, _) => _posterPh(ch),
                              errorWidget: (_, _, _) => _posterPh(ch),
                            )
                          : _posterPh(ch),
                    ),
                    if (_isAnimeMovie(ch))
                      Positioned(
                        left: 6,
                        bottom: 6,
                        child: _posterBadge('ANIME'),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              ch.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12 * _s,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    ),
  );

  bool _isAnimeMovie(Channel channel) {
    final metadata = <String>[
      channel.genre ?? '',
      channel.category ?? '',
      ...channel.categories,
    ].join(' ').toLowerCase();
    return metadata.contains('anime') || metadata.contains('animación');
  }

  Widget _posterBadge(String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: AppColors.accent.withValues(alpha: 0.94),
      borderRadius: BorderRadius.circular(5),
      boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 6)],
    ),
    child: Text(
      label,
      style: TextStyle(
        color: Colors.white,
        fontSize: 8.5 * _s,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.25,
      ),
    ),
  );
  Widget _posterPh(Channel ch) => Container(
    alignment: Alignment.center,
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [AppColors.cardElevated, AppColors.cardDark],
      ),
    ),
    padding: const EdgeInsets.all(8),
    child: Text(
      ch.displayName,
      maxLines: 4,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      style: TextStyle(
        color: AppColors.accentLight,
        fontSize: 12 * _s,
        fontWeight: FontWeight.w700,
      ),
    ),
  );

  // --------- Series ---------
  Widget _seriesRow({String title = 'Series', List<XtreamSeries>? items}) {
    final series = items ?? _store.series;
    if (series.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
          child: Text(
            title,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16 * _s,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        SizedBox(
          height: _posterRowHeight,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            itemCount: series.length > 40 ? 40 : series.length,
            itemBuilder: (ctx, i) => _seriesCard(series[i]),
          ),
        ),
      ],
    );
  }

  Widget _seriesTab() {
    final series = _store.series;
    if (series.isEmpty) {
      if (_vodLoading) return _loading('Cargando series...');
      return _vodEmpty('series');
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: _posterWidth + 12,
        childAspectRatio: _posterWidth / (_posterHeight + 28 * _s),
        crossAxisSpacing: 12,
        mainAxisSpacing: 16,
      ),
      itemCount: series.length,
      itemBuilder: (ctx, i) => _seriesCard(series[i]),
    );
  }

  Widget _seriesCard(XtreamSeries s) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 5),
    child: TvFocusable(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => SeriesDetailScreen(series: s)),
      ),
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: _posterWidth,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: _posterWidth,
                height: _posterHeight,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ColoredBox(
                      color: AppColors.cardElevated,
                      child: s.cover != null && s.cover!.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: s.cover!,
                              fit: BoxFit.cover,
                              errorWidget: (_, _, _) => _seriesPh(s.name),
                            )
                          : _seriesPh(s.name),
                    ),
                    Positioned(
                      left: 6,
                      bottom: 6,
                      child: _posterBadge(_seriesBadge(s)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              s.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12 * _s,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    ),
  );

  String _seriesBadge(XtreamSeries series) {
    final episodeCount = series.episodes?.length ?? 0;
    if (episodeCount > 0) return '$episodeCount CAP.';
    final metadata = <String>[
      series.genre ?? '',
      ...series.categories,
    ].join(' ').toLowerCase();
    if (metadata.contains('finalizada') ||
        metadata.contains('completa') ||
        metadata.contains('completed')) {
      return 'COMPLETA';
    }
    if (metadata.contains('anime')) return 'ANIME';
    return 'SERIE';
  }

  Widget _seriesPh(String name) => Container(
    alignment: Alignment.center,
    padding: const EdgeInsets.all(8),
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [AppColors.cardElevated, AppColors.cardDark],
      ),
    ),
    child: Text(
      name,
      maxLines: 4,
      textAlign: TextAlign.center,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: AppColors.accentLight,
        fontSize: 11 * _s,
        fontWeight: FontWeight.w700,
      ),
    ),
  );

  // --------- Estados ---------
  Widget _loading(String msg) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(
          width: 30,
          height: 30,
          child: CircularProgressIndicator(
            strokeWidth: 2.4,
            color: AppColors.accent,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          msg,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
      ],
    ),
  );

  Widget _vodEmpty(String tipo) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            tipo == 'series' ? Icons.tv_rounded : Icons.movie_rounded,
            color: AppColors.textMuted,
            size: 56,
          ),
          const SizedBox(height: 16),
          Text(
            'Aún no hay $tipo',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            tipo == 'series'
                ? 'Las series bajo demanda vienen de una cuenta Xtream.\nConéctala desde Perfil → Mis Fuentes.'
                : 'Conéctate a internet para cargar el catálogo,\no agrega una cuenta Xtream en Perfil → Mis Fuentes.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    ),
  );
}
