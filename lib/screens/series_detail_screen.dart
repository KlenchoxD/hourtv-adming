import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/channel.dart';
import '../services/content_store.dart';
import '../services/device_type.dart';
import '../services/share_service.dart';
import '../services/storage_service.dart';
import '../services/xtream_service.dart';
import '../theme/app_theme.dart';
import '../widgets/tv_focusable.dart';
import '../widgets/vod_detail_widgets.dart';
import 'player_screen.dart';

class SeriesDetailScreen extends StatefulWidget {
  final XtreamSeries series;

  const SeriesDetailScreen({super.key, required this.series});

  @override
  State<SeriesDetailScreen> createState() => _SeriesDetailScreenState();
}

class _SeriesDetailScreenState extends State<SeriesDetailScreen> {
  final _store = ContentStore.instance;
  List<Channel> _episodes = const [];
  bool _loading = true;
  String? _error;
  String? _selectedSeason;
  late bool _favorite;

  double get _s => DeviceProfile.uiScale(context);

  @override
  void initState() {
    super.initState();
    _favorite = StorageService.loadFavorites().any(
      (favorite) => favorite.url == _seriesChannel.url,
    );
    _store.addListener(_onStoreChanged);
    _load();
  }

  @override
  void dispose() {
    _store.removeListener(_onStoreChanged);
    super.dispose();
  }

  Channel get _seriesChannel => Channel(
    name: widget.series.name,
    url: 'hourtv-series:${widget.series.seriesId}',
    logo: widget.series.cover,
    backdrop: widget.series.backdrop,
    forcedType: 'series',
    plot: widget.series.plot,
    year: widget.series.year,
    rating: widget.series.rating,
    duration: widget.series.duration,
    genre: widget.series.genre,
    cast: widget.series.cast,
    director: widget.series.director,
    writer: widget.series.writer,
    releaseDate: widget.series.releaseDate,
    categories: widget.series.categories,
  );

  void _onStoreChanged() {
    final favorite = StorageService.loadFavorites().any(
      (item) => item.url == _seriesChannel.url,
    );
    if (mounted && favorite != _favorite) setState(() => _favorite = favorite);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final episodes =
          widget.series.episodes ??
          await XtreamService.fetchEpisodes(
            widget.series.host,
            widget.series.username,
            widget.series.password,
            widget.series.seriesId,
          );
      if (!mounted) return;
      final ordered = [...episodes]
        ..sort((a, b) => a.displayName.compareTo(b.displayName));
      final seasons = _seasonNames(ordered);
      setState(() {
        _episodes = ordered;
        _selectedSeason = seasons.isEmpty ? null : seasons.first;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'No se pudieron cargar los episodios de esta serie.';
      });
    }
  }

  List<String> _seasonNames([List<Channel>? source]) {
    final values = (source ?? _episodes)
        .map((episode) => episode.group?.trim())
        .whereType<String>()
        .where((season) => season.isNotEmpty)
        .toSet()
        .toList();
    if (values.isEmpty && (source ?? _episodes).isNotEmpty) values.add('T1');
    values.sort((a, b) => _seasonNumber(a).compareTo(_seasonNumber(b)));
    return values;
  }

  int _seasonNumber(String season) =>
      int.tryParse(RegExp(r'\d+').firstMatch(season)?.group(0) ?? '') ?? 1;

  List<Channel> get _selectedEpisodes {
    final season = _selectedSeason;
    if (season == null) return const [];
    return _episodes
        .where(
          (episode) =>
              (episode.group?.trim().isNotEmpty == true
                  ? episode.group!.trim()
                  : 'T1') ==
              season,
        )
        .toList();
  }

  Channel? get _firstUnwatchedEpisode {
    if (_episodes.isEmpty) return null;
    final watchedUrls = StorageService.loadRecent()
        .map((channel) => channel.url)
        .toSet();
    return _episodes.cast<Channel?>().firstWhere(
      (episode) => episode != null && !watchedUrls.contains(episode.url),
      orElse: () => _episodes.first,
    );
  }

  Future<void> _toggleFavorite() async {
    await _store.toggleFavorite(_seriesChannel);
    final favorite = StorageService.loadFavorites().any(
      (item) => item.url == _seriesChannel.url,
    );
    if (mounted) setState(() => _favorite = favorite);
  }

  Future<void> _share() async {
    final result = await ShareService.shareVod(
      title: widget.series.name,
      plot: widget.series.plot,
    );
    if (!mounted || result == DetailShareResult.shared) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Información copiada al portapapeles.')),
    );
  }

  void _play(Channel? episode) {
    if (episode == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerScreen(
          channel: episode,
          allChannels: _episodes.isEmpty ? [episode] : _episodes,
        ),
      ),
    );
  }

  double _ratingValue(XtreamSeries series) {
    final match = RegExp(r'\d+(?:[.,]\d+)?').firstMatch(series.rating ?? '');
    return double.tryParse(match?.group(0)?.replaceAll(',', '.') ?? '') ?? -1;
  }

  List<XtreamSeries> get _similar {
    final genres = splitDetailGenres(
      widget.series.genre,
    ).map((genre) => genre.toLowerCase()).toSet();
    if (genres.isEmpty) return const [];
    final similar = _store.series.where((series) {
      if (series.seriesId == widget.series.seriesId) return false;
      return splitDetailGenres(
        series.genre,
      ).map((genre) => genre.toLowerCase()).any(genres.contains);
    }).toList();
    similar.sort((a, b) {
      final rating = _ratingValue(b).compareTo(_ratingValue(a));
      return rating != 0
          ? rating
          : a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return similar.take(12).toList();
  }

  @override
  Widget build(BuildContext context) {
    final series = widget.series;
    final seasons = _seasonNames();
    final similar = _similar
        .map(
          (item) => VodSimilarItem(
            title: item.name,
            imageUrl: item.cover,
            badge: item.rating?.trim().isNotEmpty == true
                ? '★ ${item.rating!.trim()}'
                : null,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SeriesDetailScreen(series: item),
              ),
            ),
          ),
        )
        .toList();

    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      body: SafeArea(
        child: VodDetailView(
          title: series.name,
          backdropUrl: series.backdrop ?? series.cover,
          year: series.releaseDate?.trim().isNotEmpty == true
              ? series.releaseDate
              : series.year,
          duration: series.duration,
          rating: series.rating,
          genres: splitDetailGenres(series.genre),
          plot: series.plot,
          director: series.director,
          writer: series.writer,
          cast: series.cast,
          scale: _s,
          overscan: DeviceProfile.overscan(context),
          onBack: () => Navigator.maybePop(context),
          onPlay: _loading ? null : () => _play(_firstUnwatchedEpisode),
          playAutofocus: DeviceProfile.isTv(context),
          actions: [
            VodDetailAction(
              icon: _favorite ? Icons.check_rounded : Icons.add_rounded,
              label: 'Mi Lista',
              selected: _favorite,
              onTap: _toggleFavorite,
            ),
            VodDetailAction(
              icon: Icons.share_rounded,
              label: 'Compartir',
              onTap: _share,
            ),
          ],
          body: _episodesBody(seasons),
          similarItems: similar,
        ),
      ),
    );
  }

  Widget _episodesBody(List<String> seasons) {
    if (_loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(28),
          child: CircularProgressIndicator(color: AppColors.accent),
        ),
      );
    }
    if (_error != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _error!,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13 * _s),
          ),
          const SizedBox(height: 12),
          TvFocusable(
            onTap: _load,
            borderRadius: BorderRadius.circular(20 * _s),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: 18 * _s,
                vertical: 10 * _s,
              ),
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(20 * _s),
              ),
              child: Text(
                'Reintentar',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      );
    }
    if (_episodes.isEmpty) {
      return Text(
        'Esta serie todavía no tiene episodios disponibles.',
        style: TextStyle(color: AppColors.textSecondary, fontSize: 13 * _s),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Episodios',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18 * _s,
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: 13 * _s),
        SizedBox(
          height: 42 * _s,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: seasons.length,
            separatorBuilder: (_, _) => SizedBox(width: 9 * _s),
            itemBuilder: (context, index) {
              final season = seasons[index];
              final selected = season == _selectedSeason;
              return TvFocusable(
                onTap: () => setState(() => _selectedSeason = season),
                borderRadius: BorderRadius.circular(20 * _s),
                child: Container(
                  alignment: Alignment.center,
                  padding: EdgeInsets.symmetric(horizontal: 16 * _s),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.accent : AppColors.cardDark,
                    borderRadius: BorderRadius.circular(20 * _s),
                    border: Border.all(
                      color: selected
                          ? AppColors.accent
                          : Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Text(
                    'Temporada ${_seasonNumber(season)}',
                    style: TextStyle(
                      color: selected ? Colors.white : AppColors.textSecondary,
                      fontSize: 12 * _s,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        SizedBox(height: 14 * _s),
        ..._selectedEpisodes.asMap().entries.map(
          (entry) => _episodeTile(entry.value, entry.key),
        ),
      ],
    );
  }

  Widget _episodeTile(Channel episode, int index) => Padding(
    padding: EdgeInsets.only(bottom: 10 * _s),
    child: TvFocusable(
      onTap: () => _play(episode),
      borderRadius: BorderRadius.circular(12 * _s),
      child: Container(
        height: 74 * _s,
        decoration: BoxDecoration(
          color: AppColors.cardDark,
          borderRadius: BorderRadius.circular(12 * _s),
          border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
        ),
        child: Row(
          children: [
            // Miniatura 16:9 compacta (estilo Netflix), no el póster vertical.
            SizedBox(
              width: 132 * _s,
              child: ClipRRect(
                borderRadius: BorderRadius.horizontal(
                  left: Radius.circular(12 * _s),
                ),
                child: _episodeImage(episode),
              ),
            ),
            SizedBox(width: 12 * _s),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${index + 1}. ${episode.displayName}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13.5 * _s,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Reproducir episodio',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11.5 * _s,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.all(12 * _s),
              child: Icon(
                Icons.play_arrow_rounded,
                color: AppColors.accent,
                size: 27 * _s,
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _episodeImage(Channel episode) {
    final image = episode.backdrop ?? episode.logo;
    if (image?.trim().isEmpty != false) {
      return const ColoredBox(
        color: AppColors.cardElevated,
        child: Center(
          child: Icon(
            Icons.play_circle_outline_rounded,
            color: AppColors.textMuted,
          ),
        ),
      );
    }
    return CachedNetworkImage(
      imageUrl: image!.trim(),
      fit: BoxFit.cover,
      memCacheWidth: 360,
      errorWidget: (_, _, _) => const ColoredBox(
        color: AppColors.cardElevated,
        child: Center(
          child: Icon(
            Icons.play_circle_outline_rounded,
            color: AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}
