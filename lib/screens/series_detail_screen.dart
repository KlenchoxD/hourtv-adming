import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/channel.dart';
import '../services/device_type.dart';
import '../services/xtream_service.dart';
import '../theme/app_theme.dart';
import '../widgets/tv_focusable.dart';
import 'player_screen.dart';

/// Detalles de una serie Xtream: carátula, sinopsis y episodios agrupados
/// por temporada. Navegable con D-pad (TV) y táctil (móvil/tablet).
class SeriesDetailScreen extends StatefulWidget {
  final XtreamSeries series;
  const SeriesDetailScreen({super.key, required this.series});

  @override
  State<SeriesDetailScreen> createState() => _SeriesDetailScreenState();
}

class _SeriesDetailScreenState extends State<SeriesDetailScreen> {
  List<Channel> _episodes = [];
  bool _loading = true;
  String? _error;

  double get _s => DeviceProfile.uiScale(context);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final eps =
          widget.series.episodes ??
          await XtreamService.fetchEpisodes(
            widget.series.host,
            widget.series.username,
            widget.series.password,
            widget.series.seriesId,
          );
      if (!mounted) return;
      setState(() {
        _episodes = eps;
        _loading = false;
        if (eps.isEmpty) _error = 'Esta serie no tiene episodios disponibles.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'No se pudieron cargar los episodios.\nRevisa tu conexión.';
      });
    }
  }

  /// Temporadas en orden de aparición (los episodios ya vienen ordenados).
  List<String> get _seasons {
    final seen = <String>{};
    final out = <String>[];
    for (final e in _episodes) {
      final t = e.group ?? 'T1';
      if (seen.add(t)) out.add(t);
    }
    return out;
  }

  void _play(Channel episode) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerScreen(channel: episode, allChannels: _episodes),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      body: Container(
        decoration: AppTheme.gradientBackground,
        child: SafeArea(
          child: Column(
            children: [
              _header(),
              Expanded(
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.accent,
                        ),
                      )
                    : (_error != null ? _errorView() : _list()),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<String> get _metadataParts {
    final series = widget.series;
    return <String>[
      if (series.releaseDate?.trim().isNotEmpty == true)
        series.releaseDate!.trim()
      else if (series.year?.trim().isNotEmpty == true)
        series.year!.trim(),
      if (series.duration?.trim().isNotEmpty == true) series.duration!.trim(),
      if (series.rating?.trim().isNotEmpty == true)
        '★ ${series.rating!.trim()}',
      if (series.genre?.trim().isNotEmpty == true) series.genre!.trim(),
    ];
  }

  Widget _header() {
    final s = widget.series;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        12,
        8,
        16 + DeviceProfile.overscan(context),
        8,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: AppColors.textPrimary,
            ),
            onPressed: () => Navigator.maybePop(context),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 92 * _s,
              height: 138 * _s,
              color: AppColors.cardElevated,
              child: s.cover != null && s.cover!.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: s.cover!,
                      fit: BoxFit.cover,
                      memCacheWidth: 500,
                      errorWidget: (_, _, _) => const Icon(
                        Icons.tv_rounded,
                        color: AppColors.textMuted,
                      ),
                    )
                  : const Icon(Icons.tv_rounded, color: AppColors.textMuted),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20 * _s,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (_metadataParts.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    _metadataParts.join('  •  '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11.5 * _s,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                if (!_loading && _episodes.isNotEmpty)
                  Text(
                    '${_seasons.length} temporada${_seasons.length == 1 ? '' : 's'} · ${_episodes.length} episodios',
                    style: TextStyle(
                      color: AppColors.accentLight,
                      fontSize: 12 * _s,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                if (s.plot != null && s.plot!.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    s.plot!,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12 * _s,
                      height: 1.35,
                    ),
                  ),
                ],
                if (s.writer?.trim().isNotEmpty == true) ...[
                  const SizedBox(height: 5),
                  Text(
                    'Guionista: ${s.writer!.trim()}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11.5 * _s,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorView() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppColors.textMuted,
            size: 52,
          ),
          const SizedBox(height: 14),
          Text(
            _error ?? '',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14 * _s),
          ),
          const SizedBox(height: 18),
          TvFocusable(
            autofocus: true,
            onTap: _load,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: 20 * _s,
                vertical: 10 * _s,
              ),
              decoration: BoxDecoration(
                gradient: AppTheme.accentGradient,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Reintentar',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14 * _s,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _list() {
    final pad = DeviceProfile.overscan(context);
    final items = <Widget>[];
    for (final season in _seasons) {
      final eps = _episodes.where((e) => (e.group ?? 'T1') == season).toList();
      items.add(
        Padding(
          padding: EdgeInsets.fromLTRB(18 + pad, 16, 18 + pad, 8),
          child: Text(
            'Temporada ${season.startsWith('T') ? season.substring(1) : season}',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15 * _s,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      );
      for (var i = 0; i < eps.length; i++) {
        items.add(
          _episodeTile(eps[i], i, autofocus: items.length == 1 && i == 0),
        );
      }
    }
    return ListView(
      padding: EdgeInsets.only(bottom: 24, left: pad, right: pad),
      children: items,
    );
  }

  Widget _episodeTile(Channel ep, int index, {bool autofocus = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
        child: TvFocusable(
          onTap: () => _play(ep),
          autofocus: autofocus,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: 12 * _s,
              vertical: 10 * _s,
            ),
            decoration: BoxDecoration(
              color: AppColors.cardDark,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Row(
              children: [
                Container(
                  width: 34 * _s,
                  height: 34 * _s,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      color: AppColors.accentLight,
                      fontSize: 13 * _s,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    ep.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13.5 * _s,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(
                  Icons.play_arrow_rounded,
                  color: AppColors.accent,
                  size: 22 * _s,
                ),
              ],
            ),
          ),
        ),
      );
}
