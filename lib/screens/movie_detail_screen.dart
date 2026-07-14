import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/channel.dart';
import '../services/content_store.dart';
import '../services/device_type.dart';
import '../services/xtream_service.dart';
import '../theme/app_theme.dart';
import '../widgets/tv_focusable.dart';
import 'player_screen.dart';

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
  bool get _isTv => DeviceProfile.isTv(context);

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

  Future<void> _loadMetadata() async {
    final changed = await XtreamService.enrichMovieMetadata(widget.channel);
    if (changed && mounted) setState(() {});
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

  List<String> get _metadataParts {
    final channel = widget.channel;
    final parts = <String>[];
    final year = channel.year?.trim();
    final duration = channel.duration?.trim();
    final rating = channel.rating?.trim();
    final genre = channel.genre?.trim();
    final category = channel.category?.trim();

    if (year?.isNotEmpty == true) parts.add(year!);
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
        child: Padding(
          padding: EdgeInsets.fromLTRB(18 + overscan, 12, 18 + overscan, 32),
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _topBar()),
              SliverToBoxAdapter(child: SizedBox(height: 18 * _s)),
              SliverToBoxAdapter(child: _movieHeader()),
              if (recommendations.isNotEmpty) ...[
                SliverToBoxAdapter(child: SizedBox(height: 30 * _s)),
                SliverToBoxAdapter(
                  child: Text(
                    'También podría gustarte',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 19 * _s,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                SliverToBoxAdapter(child: SizedBox(height: 14 * _s)),
                SliverToBoxAdapter(
                  child: _recommendationsGrid(recommendations),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _topBar() => Row(
    children: [
      TvFocusable(
        onTap: () => Navigator.maybePop(context),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 42 * _s,
          height: 42 * _s,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.cardDark,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.arrow_back_rounded,
            color: AppColors.textPrimary,
            size: 24 * _s,
          ),
        ),
      ),
      const SizedBox(width: 12),
      Text(
        'Detalles',
        style: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 16 * _s,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );

  Widget _movieHeader() => LayoutBuilder(
    builder: (context, constraints) {
      final wide = constraints.maxWidth >= 720;
      final poster = _poster(wide);
      final details = _details();

      if (wide) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            poster,
            SizedBox(width: 28 * _s),
            Expanded(child: details),
          ],
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(child: poster),
          SizedBox(height: 22 * _s),
          details,
        ],
      );
    },
  );

  Widget _poster(bool wide) {
    final height = (wide ? 270 : 250) * _s;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: height / 1.45,
        height: height,
        color: AppColors.cardElevated,
        child:
            widget.channel.logo != null &&
                widget.channel.logo!.trim().isNotEmpty
            ? CachedNetworkImage(
                imageUrl: widget.channel.logo!,
                fit: BoxFit.cover,
                errorWidget: (_, _, _) => _posterPlaceholder(),
              )
            : _posterPlaceholder(),
      ),
    );
  }

  Widget _posterPlaceholder() => Container(
    color: AppColors.cardElevated,
    alignment: Alignment.center,
    padding: const EdgeInsets.all(20),
    child: Text(
      widget.channel.displayName,
      maxLines: 5,
      textAlign: TextAlign.center,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: AppColors.accentLight,
        fontSize: 14 * _s,
        fontWeight: FontWeight.w700,
      ),
    ),
  );

  Widget _details() {
    final plot = widget.channel.plot?.trim();
    final metadata = _metadataParts;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                widget.channel.displayName,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 27 * _s,
                  height: 1.08,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            SizedBox(width: 12 * _s),
            TvFocusable(
              onTap: _toggleFavorite,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 46 * _s,
                height: 46 * _s,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.cardDark,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _favorite
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: _favorite ? AppColors.accent : AppColors.textPrimary,
                  size: 26 * _s,
                ),
              ),
            ),
          ],
        ),
        if (metadata.isNotEmpty) ...[
          SizedBox(height: 10 * _s),
          Text(
            metadata.join('  ·  '),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13 * _s,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        SizedBox(height: 18 * _s),
        Text(
          plot?.isNotEmpty == true ? plot! : 'Sin descripción disponible.',
          maxLines: _expanded ? null : 3,
          overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14 * _s,
            height: 1.45,
          ),
        ),
        if (plot?.isNotEmpty == true) ...[
          SizedBox(height: 5 * _s),
          TvFocusable(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 2 * _s,
                vertical: 6 * _s,
              ),
              child: Text(
                _expanded ? 'Ver menos' : 'Ver más...',
                style: TextStyle(
                  color: AppColors.accent,
                  fontSize: 13 * _s,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
        SizedBox(height: 22 * _s),
        TvFocusable(
          autofocus: _isTv,
          onTap: _play,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            constraints: BoxConstraints(minWidth: 230 * _s),
            padding: EdgeInsets.symmetric(
              horizontal: 24 * _s,
              vertical: 13 * _s,
            ),
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.play_arrow_rounded,
                  color: AppColors.textPrimary,
                  size: 25 * _s,
                ),
                SizedBox(width: 8 * _s),
                Text(
                  'Reproducir',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15 * _s,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _recommendationsGrid(List<Channel> movies) => GridView.builder(
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
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    },
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
