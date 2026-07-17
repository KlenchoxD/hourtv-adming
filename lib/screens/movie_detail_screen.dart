import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/channel.dart';
import '../services/content_store.dart';
import '../services/device_type.dart';
import '../services/tmdb_service.dart';
import '../services/xtream_service.dart';
import '../theme/app_theme.dart';
import '../widgets/tv_focusable.dart';
import 'player_screen.dart';

/// Detalle de película, fiel al diseño UltraPelis: media 16:9 arriba con
/// botón de reproducción, título + corazón, meta "año — categorías",
/// descripción con "Ver más...", Director/Actores y recomendaciones.
class MovieDetailScreen extends StatefulWidget {
  final Channel channel;
  final List<Channel> allChannels;

  const MovieDetailScreen({
    super.key,
    required this.channel,
    this.allChannels = const [],
  });

  @override
  State<MovieDetailScreen> createState() => _MovieDetailScreenState();
}

class _MovieDetailScreenState extends State<MovieDetailScreen> {
  final _store = ContentStore.instance;
  bool _expanded = false;
  late bool _favorite;

  double get _s => DeviceProfile.uiScale(context);

  @override
  void initState() {
    super.initState();
    _favorite = widget.channel.isFavorite;
    _store.addListener(_onStoreChanged);
    _loadMetadata();
  }

  @override
  void dispose() {
    _store.removeListener(_onStoreChanged);
    super.dispose();
  }

  /// Xtream primero (metadata del panel) y TMDB después para rellenar lo que
  /// falte (sinopsis, reparto, director, backdrop...).
  Future<void> _loadMetadata() async {
    var changed = await XtreamService.enrichMovieMetadata(widget.channel);
    if (mounted && changed) setState(() {});
    changed = await TmdbService.enrich(widget.channel);
    if (mounted && changed) setState(() {});
  }

  void _onStoreChanged() {
    if (!mounted) return;
    final index = _store.all.indexWhere(
      (item) => item.url == widget.channel.url,
    );
    final favorite = index >= 0
        ? _store.all[index].isFavorite
        : widget.channel.isFavorite;
    if (favorite != _favorite) {
      setState(() => _favorite = favorite);
    }
  }

  Future<void> _toggleFavorite() async {
    await _store.toggleFavorite(widget.channel);
    if (!mounted) return;
    final index = _store.all.indexWhere(
      (item) => item.url == widget.channel.url,
    );
    setState(() {
      _favorite = index >= 0 ? _store.all[index].isFavorite : !_favorite;
      widget.channel.isFavorite = _favorite;
    });
  }

  void _play() {
    final channels = widget.allChannels.isNotEmpty
        ? widget.allChannels
        : _store.movies;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerScreen(
          channel: widget.channel,
          allChannels: channels.isEmpty ? [widget.channel] : channels,
        ),
      ),
    );
  }

  /// Meta estilo UltraPelis: "año — categoría" en gris pequeño.
  List<String> get _metadataParts {
    final channel = widget.channel;
    final parts = <String>[];
    final releaseDate = channel.releaseDate?.trim();
    final year = channel.year?.trim();
    final duration = channel.duration?.trim();
    final rating = channel.rating?.trim();
    final genre = channel.genre?.trim();
    final category = channel.category?.trim();

    if (releaseDate?.isNotEmpty == true) {
      parts.add(releaseDate!);
    } else if (year?.isNotEmpty == true) {
      parts.add(year!);
    }
    if (duration?.isNotEmpty == true) parts.add(duration!);
    if (rating?.isNotEmpty == true) parts.add('★ $rating');
    if (genre?.isNotEmpty == true) {
      parts.add(genre!);
    } else if (category?.isNotEmpty == true) {
      parts.add(category!);
    }
    return parts;
  }

  List<Channel> get _recommendations {
    final genre = widget.channel.genre?.trim().toLowerCase();
    if (genre == null || genre.isEmpty) return const [];

    final seen = <String>{widget.channel.url};
    return _store.movies
        .where(
          (movie) =>
              seen.add(movie.url) && movie.genre?.trim().toLowerCase() == genre,
        )
        .take(6)
        .toList();
  }

  void _openRecommendation(Channel movie) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MovieDetailScreen(
          channel: movie,
          allChannels: widget.allChannels.isNotEmpty
              ? widget.allChannels
              : _store.movies,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final overscan = DeviceProfile.overscan(context);
    final recommendations = _recommendations;

    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(overscan, 0, overscan, 32),
          children: [
            _mediaHeader(),
            _titleRow(),
            _metaLine(),
            _description(),
            _castSection(),
            if (recommendations.isNotEmpty) ...[
              SizedBox(height: 26 * _s),
              Container(
                height: 1,
                margin: const EdgeInsets.symmetric(horizontal: 20),
                color: Colors.white.withValues(alpha: 0.2),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(20, 18 * _s, 20, 14 * _s),
                child: Text(
                  'También podría gustarte',
                  style: TextStyle(
                    color: AppColors.textPrimary.withValues(alpha: 0.9),
                    fontSize: 16 * _s,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              _recommendationsGrid(recommendations),
            ],
          ],
        ),
      ),
    );
  }

  /// Media 16:9 arriba (como el video del index): backdrop de TMDB si existe,
  /// si no el póster recortado; botón rojo de reproducción centrado y botón
  /// Atrás flotante.
  Widget _mediaHeader() {
    final img = widget.channel.backdrop ?? widget.channel.logo;
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(
            color: Colors.black,
            child: img != null && img.trim().isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: img,
                    fit: BoxFit.cover,
                    memCacheWidth: 800,
                    errorWidget: (_, _, _) => const SizedBox(),
                  )
                : const SizedBox(),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.35),
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.55),
                ],
              ),
            ),
          ),
          Center(
            child: TvFocusable(
              autofocus: true,
              onTap: _play,
              borderRadius: BorderRadius.circular(40 * _s),
              child: Container(
                width: 64 * _s,
                height: 64 * _s,
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 18,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 38 * _s,
                ),
              ),
            ),
          ),
          Positioned(
            top: 8,
            left: 8,
            child: TvFocusable(
              onTap: () => Navigator.maybePop(context),
              borderRadius: BorderRadius.circular(21),
              child: Container(
                width: 40 * _s,
                height: 40 * _s,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.arrow_back_rounded,
                  color: Colors.white,
                  size: 22 * _s,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Título + corazón de favorito (como .title-row del index).
  Widget _titleRow() => Padding(
    padding: EdgeInsets.fromLTRB(12, 14 * _s, 14, 0),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            widget.channel.displayName,
            maxLines: 3,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18 * _s,
              fontWeight: FontWeight.w500,
              height: 1.2,
            ),
          ),
        ),
        const SizedBox(width: 10),
        TvFocusable(
          onTap: _toggleFavorite,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(5),
            child: Icon(
              _favorite
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              color: _favorite ? AppColors.accent : AppColors.textSecondary,
              size: 22 * _s,
            ),
          ),
        ),
      ],
    ),
  );

  /// Meta gris pequeña "año — duración — ★rating — categoría".
  Widget _metaLine() {
    final parts = _metadataParts;
    if (parts.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.fromLTRB(12, 6 * _s, 14, 0),
      child: Text(
        parts.join('  —  '),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: AppColors.textSecondary.withValues(alpha: 0.8),
          fontSize: 12 * _s,
        ),
      ),
    );
  }

  /// Descripción colapsada a 3 líneas con "Ver más..." (rojo, pequeño).
  Widget _description() {
    final plot = widget.channel.plot?.trim();
    if (plot == null || plot.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.fromLTRB(12, 12 * _s, 14, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            plot,
            maxLines: _expanded ? null : 3,
            overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.textPrimary.withValues(alpha: 0.92),
              fontSize: 13 * _s,
              height: 1.6,
            ),
          ),
          TvFocusable(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 5 * _s, horizontal: 2),
              child: Text(
                _expanded ? 'Ver menos' : 'Ver más...',
                style: TextStyle(
                  color: AppColors.accent,
                  fontSize: 11 * _s,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Director y Actores (como .detail-cast del index).
  Widget _castSection() {
    final director = widget.channel.director?.trim();
    final writer = widget.channel.writer?.trim();
    final cast = widget.channel.cast?.trim();
    if ((director == null || director.isEmpty) &&
        (writer == null || writer.isEmpty) &&
        (cast == null || cast.isEmpty)) {
      return const SizedBox.shrink();
    }
    TextStyle label() => TextStyle(
      color: AppColors.textSecondary.withValues(alpha: 0.75),
      fontSize: 13 * _s,
    );
    TextStyle value() => TextStyle(
      color: AppColors.textPrimary.withValues(alpha: 0.9),
      fontSize: 13 * _s,
      height: 1.45,
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(12, 10 * _s, 14, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (director != null && director.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: 'Director:  ', style: label()),
                    TextSpan(text: director, style: value()),
                  ],
                ),
              ),
            ),
          if (writer != null && writer.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: 'Guionista:  ', style: label()),
                    TextSpan(text: writer, style: value()),
                  ],
                ),
              ),
            ),
          if (cast != null && cast.isNotEmpty)
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: 'Actores:  ', style: label()),
                  TextSpan(text: cast, style: value()),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _recommendationsGrid(List<Channel> movies) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14),
    child: GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: movies.length,
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 150 * _s,
        childAspectRatio: 0.59,
        crossAxisSpacing: 12 * _s,
        mainAxisSpacing: 14 * _s,
      ),
      itemBuilder: (context, index) {
        final movie = movies[index];
        return TvFocusable(
          onTap: () => _openRecommendation(movie),
          borderRadius: BorderRadius.circular(9),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: Container(
                    width: double.infinity,
                    color: AppColors.cardElevated,
                    child: movie.logo != null && movie.logo!.trim().isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: movie.logo!,
                            fit: BoxFit.cover,
                            memCacheWidth: 360,
                            errorWidget: (_, _, _) =>
                                _recommendationPlaceholder(movie),
                          )
                        : _recommendationPlaceholder(movie),
                  ),
                ),
              ),
              SizedBox(height: 6 * _s),
              Text(
                movie.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 11.5 * _s,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        );
      },
    ),
  );

  Widget _recommendationPlaceholder(Channel movie) => Container(
    color: AppColors.cardElevated,
    alignment: Alignment.center,
    padding: const EdgeInsets.all(8),
    child: Text(
      movie.displayName,
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
}
