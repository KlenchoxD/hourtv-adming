import 'package:flutter/material.dart';

import '../models/channel.dart';
import '../services/content_store.dart';
import '../services/device_type.dart';
import '../services/share_service.dart';
import '../services/tmdb_service.dart';
import '../services/xtream_service.dart';
import '../theme/app_theme.dart';
import '../widgets/vod_detail_widgets.dart';
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
    if (favorite != _favorite) setState(() => _favorite = favorite);
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

  Future<void> _share() async {
    final result = await ShareService.shareVod(
      title: widget.channel.displayName,
      plot: widget.channel.plot,
    );
    if (!mounted || result == DetailShareResult.shared) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Información copiada al portapapeles.')),
    );
  }

  void _play() {
    final channels = widget.allChannels.isNotEmpty
        ? widget.allChannels
              .where((item) => item.type == MediaType.movie)
              .toList()
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

  double _ratingValue(Channel channel) {
    final match = RegExp(r'\d+(?:[.,]\d+)?').firstMatch(channel.rating ?? '');
    return double.tryParse(match?.group(0)?.replaceAll(',', '.') ?? '') ?? -1;
  }

  List<Channel> get _recommendations {
    final genres = splitDetailGenres(
      widget.channel.genre,
    ).map((genre) => genre.toLowerCase()).toSet();
    if (genres.isEmpty) return const [];

    final movies = _store.movies.where((movie) {
      if (movie.url == widget.channel.url || movie.type != MediaType.movie) {
        return false;
      }
      final movieGenres = splitDetailGenres(
        movie.genre,
      ).map((genre) => genre.toLowerCase());
      return movieGenres.any(genres.contains);
    }).toList();
    movies.sort((a, b) {
      final rating = _ratingValue(b).compareTo(_ratingValue(a));
      return rating != 0
          ? rating
          : a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
    });
    return movies.take(12).toList();
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
    final channel = widget.channel;
    final year = channel.releaseDate?.trim().isNotEmpty == true
        ? channel.releaseDate
        : channel.year;
    final similar = _recommendations
        .map(
          (movie) => VodSimilarItem(
            title: movie.displayName,
            imageUrl: movie.logo,
            badge: movie.rating?.trim().isNotEmpty == true
                ? '★ ${movie.rating!.trim()}'
                : null,
            onTap: () => _openRecommendation(movie),
          ),
        )
        .toList();

    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      body: SafeArea(
        child: VodDetailView(
          title: channel.displayName,
          backdropUrl: channel.backdrop ?? channel.logo,
          year: year,
          duration: channel.duration,
          rating: channel.rating,
          genres: splitDetailGenres(channel.genre ?? channel.category),
          plot: channel.plot,
          director: channel.director,
          writer: channel.writer,
          cast: channel.cast,
          scale: _s,
          overscan: DeviceProfile.overscan(context),
          onBack: () => Navigator.maybePop(context),
          onPlay: _play,
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
          similarItems: similar,
        ),
      ),
    );
  }
}
