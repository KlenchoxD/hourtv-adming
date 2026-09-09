import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/channel.dart';
import '../services/content_store.dart';
import '../services/device_type.dart';
import '../services/playback_progress.dart';
import '../services/share_service.dart';
import '../services/tmdb_service.dart';
import '../services/xtream_service.dart';
import 'hourtv_focusable.dart';
import 'hourtv_parental_gate.dart';
import 'hourtv_player_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Paleta visual fiel a Google AI Studio (src/index.css)
// ─────────────────────────────────────────────────────────────────────────────
const _black = Color(0xFF050505);
const _bgPrimary = Color(0xFF080A09);
const _surface = Color(0xFF101412);
const _surfaceControl = Color(0xFF151917);
const _line = Color(0xFF27302C);
const _red = Color(0xFF00C781); // Emerald Brand Color
const _textSecondary = Color(0xFFC4C8C6);
const _muted = Color(0xFFA8ADAB);

String _seriesKey(XtreamSeries series) =>
    'hourtv-series:${Uri.encodeComponent(series.host)}:${Uri.encodeComponent(series.seriesId)}';

Channel hourTvSeriesChannel(XtreamSeries series) => Channel(
  name: series.name,
  url: _seriesKey(series),
  logo: series.cover,
  backdrop: series.backdrop ?? series.cover,
  plot: series.plot,
  year: series.year,
  rating: series.rating,
  duration: series.duration,
  genre: series.genre,
  cast: series.cast,
  director: series.director,
  writer: series.writer,
  releaseDate: series.releaseDate,
  category: 'series',
  forcedType: 'series',
  categories: [if ((series.genre ?? '').trim().isNotEmpty) series.genre!],
);

XtreamSeries? hourTvResolveSeries(
  Channel channel,
  Iterable<XtreamSeries> series,
) {
  // 1. Coincidencia directa por clave url de serie
  if (channel.url.startsWith('hourtv-series:')) {
    for (final item in series) {
      if (_seriesKey(item) == channel.url) return item;
    }
  }

  // 2. Coincidencia por seriesId o prefijo de tvgId
  if (channel.tvgId != null && channel.tvgId!.isNotEmpty) {
    for (final item in series) {
      if (item.seriesId == channel.tvgId ||
          channel.tvgId!.startsWith('${item.seriesId}:')) {
        return item;
      }
    }
  }

  // 3. Coincidencia si alguna URL de episodio coincide
  if (channel.url.isNotEmpty && !channel.url.startsWith('hourtv-series:')) {
    for (final item in series) {
      final eps = item.episodes;
      if (eps != null) {
        for (final ep in eps) {
          if (ep.url == channel.url) return item;
        }
      }
    }
  }

  // 4. Coincidencia por título normalizado TMDB
  final normChannel = TmdbService.normalizeTitle(channel.displayName);
  if (normChannel.isNotEmpty) {
    for (final item in series) {
      if (TmdbService.normalizeTitle(item.name) == normChannel) {
        return item;
      }
    }
  }

  // 5. Coincidencia exacta o por seriesTitle
  final lowerDisplay = channel.displayName.trim().toLowerCase();
  final lowerSeriesTitle = channel.seriesTitle.trim().toLowerCase();
  for (final item in series) {
    final itemLower = item.name.trim().toLowerCase();
    if (itemLower == lowerDisplay || itemLower == lowerSeriesTitle) {
      return item;
    }
  }

  // 6. Si el canal está forzado como serie o es tipo serie, sintetizar XtreamSeries
  if (channel.type == MediaType.series || channel.forcedType == 'series') {
    return XtreamSeries(
      seriesId: channel.tvgId ?? 'series:${channel.displayName}',
      name: channel.seriesTitle.isNotEmpty
          ? channel.seriesTitle
          : channel.displayName,
      cover: channel.backdrop ?? channel.logo,
      plot: channel.plot,
      host: '',
      username: '',
      password: '',
      year: channel.year,
      rating: channel.rating,
      duration: channel.duration,
      genre: channel.genre,
      cast: channel.cast,
      director: channel.director,
      writer: channel.writer,
      releaseDate: channel.releaseDate,
      episodes: [
        channel.copyWith(
          name: 'Capítulo 1',
          url: channel.url.isNotEmpty
              ? channel.url
              : channel.servers.firstOrNull?.url,
          group: 'T1',
          forcedType: 'series',
        ),
      ],
    );
  }

  return null;
}

class HourTvSeriesDetailPage extends StatefulWidget {
  const HourTvSeriesDetailPage({super.key, required this.series});

  final XtreamSeries series;

  @override
  State<HourTvSeriesDetailPage> createState() => _HourTvSeriesDetailPageState();
}

class _HourTvSeriesDetailPageState extends State<HourTvSeriesDetailPage> {
  final store = ContentStore.instance;
  List<Channel> episodes = const [];
  bool loading = true;
  String? error;
  String? season;
  bool _opening = false;

  Channel get channel {
    final item = hourTvSeriesChannel(widget.series);
    final favorite = store.favorites.any((saved) => saved.url == item.url);
    return item.copyWith(isFavorite: favorite);
  }

  Map<String, List<Channel>> get seasons {
    final grouped = <String, List<Channel>>{};
    for (final episode in episodes) {
      final key = (episode.group ?? 'T1').trim();
      grouped.putIfAbsent(key.isEmpty ? 'T1' : key, () => []).add(episode);
    }
    return grouped;
  }

  String? get currentSeasonKey {
    if (seasons.isEmpty) return null;
    if (season != null && seasons.containsKey(season)) return season!;
    return seasons.keys.first;
  }

  List<Channel> get currentSeasonEpisodes {
    final key = currentSeasonKey;
    if (key == null) return episodes;
    return seasons[key] ?? const <Channel>[];
  }

  static String _seasonLabel(String? key) {
    if (key == null || key.trim().isEmpty) return 'Temporada 1';
    final trimmed = key.trim();
    final match = RegExp(r'\d+').firstMatch(trimmed);
    if (match != null) {
      return 'Temporada ${match.group(0)}';
    }
    return trimmed.replaceFirst(
      RegExp(r'^T', caseSensitive: false),
      'Temporada ',
    );
  }

  static int _seasonNumber(String? key) {
    if (key == null) return 1;
    final match = RegExp(r'\d+').firstMatch(key);
    if (match != null) {
      return int.tryParse(match.group(0)!) ?? 1;
    }
    return 1;
  }

  String get _primaryPlayLabel {
    final current = currentSeasonEpisodes;
    if (current.isEmpty) return 'Reproducir';
    final sNum = _seasonNumber(currentSeasonKey);
    final next = _nextUnfinishedEpisode;
    if (next != null && next.tvgId != null) {
      final marker = RegExp(r'S\d+:\s*E?(\d+)|:(\d+)$')
          .firstMatch(next.tvgId!);
      final episodeNumber = marker?.group(1) ?? marker?.group(2);
      if (episodeNumber != null) {
        return 'Reproducir T$sNum:E$episodeNumber';
      }
    }
    return 'Reproducir T$sNum:E1';
  }

  /// El episodio en el que la serie quedo: el ultimo con progreso sin
  /// terminar (>=95% cuenta como terminado y se salta). Si todos los
  /// episodios guardados estan completos o no hay progreso, el primero
  /// no visto; a falta de todo, el primero de la temporada.
  Channel? get _nextUnfinishedEpisode =>
      PlaybackProgress.nextUnfinishedEpisode(currentSeasonEpisodes);

  @override
  void initState() {
    super.initState();
    store.addListener(_refresh);
    unawaited(_load());
  }

  @override
  void dispose() {
    store.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    try {
      final existingEpisodes = widget.series.episodes;
      final result = (existingEpisodes != null && existingEpisodes.isNotEmpty)
          ? existingEpisodes
          : (widget.series.host.isNotEmpty
                ? await XtreamService.fetchEpisodes(
                    widget.series.host,
                    widget.series.username,
                    widget.series.password,
                    widget.series.seriesId,
                  )
                : const <Channel>[]);
      var finalEpisodes = List<Channel>.from(result);
      if (finalEpisodes.isEmpty) {
        final matching = store.visibleAll
            .where(
              (item) =>
                  item.type == MediaType.series &&
                  (item.seriesTitle.toLowerCase() ==
                          widget.series.name.toLowerCase() ||
                      item.displayName.toLowerCase().contains(
                        widget.series.name.toLowerCase(),
                      )),
            )
            .toList();
        if (matching.isNotEmpty) {
          finalEpisodes = matching;
        }
      }
      if (!mounted) return;
      setState(() {
        episodes = finalEpisodes;
        loading = false;
        season = seasons.keys.isEmpty ? null : seasons.keys.first;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = 'No se pudieron cargar los episodios.';
      });
    }
  }

  Future<void> _favorite() async {
    await store.toggleFavorite(channel);
    if (mounted) setState(() {});
  }

  Future<void> _share() async {
    final result = await ShareService.shareVod(
      title: widget.series.name,
      plot: widget.series.plot,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result == DetailShareResult.shared
              ? 'Serie compartida.'
              : 'Información copiada.',
        ),
      ),
    );
  }

  Future<void> _play(Channel episode, {int? index}) async {
    if (_opening) return;
    _opening = true;
    try {
      if (!await ensureParentalAccess(context, channel) || !mounted) return;
      final current = currentSeasonEpisodes;
      final playIndex =
          index ?? current.indexWhere((c) => c.url == episode.url);
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PlayerScreen(
            channel: episode,
            allChannels: current.isNotEmpty ? current : episodes,
            initialIndex: playIndex >= 0 ? playIndex : 0,
            // Elegir un capitulo concreto de la ficha reanuda su progreso
            // directo (como Netflix): el dialogo de decision es para
            // peliculas/entradas genericas.
            resumePlayback: true,
          ),
        ),
      );
    } finally {
      _opening = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final phone = DeviceProfile.isPhone(context);
    final tablet = DeviceProfile.isTablet(context);
    final tv = DeviceProfile.isTv(context);
    if (tv) return _tv();
    if (phone) return _phone();
    return _wide(tablet: tablet);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // LAYOUT: Móvil (Fiel a DetailsView.tsx de Google AI Studio)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _phone() {
    return Scaffold(
      backgroundColor: _bgPrimary,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              // Hero Backdrop (Aspect Ratio 16/10)
              SliverToBoxAdapter(
                child: AspectRatio(
                  aspectRatio: 16 / 10,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _heroBackdrop(),
                      // Soft Multi-Stop Dark Vignette: vertical
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0x33000000),
                              Color(0x80080A09),
                              _bgPrimary,
                            ],
                            stops: [0.0, 0.6, 1.0],
                          ),
                        ),
                      ),
                      // Soft Multi-Stop Dark Vignette: horizontal
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [Color(0x99080A09), Color(0x00080A09)],
                            stops: [0.0, 0.4],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Main Content Section with -mt-6 overlap (-24px)
              SliverToBoxAdapter(
                child: Transform.translate(
                  offset: const Offset(0, -24),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title
                        Text(
                          widget.series.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Quality Badges
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final badge in ['4K UHD', 'HDR10+', '5.1'])
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: _surface,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: _line),
                                ),
                                child: Text(
                                  badge,
                                  style: const TextStyle(
                                    color: _red,
                                    fontSize: 10,
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Primary & Secondary Action Buttons
                        _actionsPhone(),
                        const SizedBox(height: 20),
                        // Synopsis & Technical Specs
                        _synopsisSection(),
                        // Episodes & Seasons
                        _episodesBodyPhone(),
                        // Reparto Principal
                        _castSection(),
                        // También te puede gustar
                        _relatedSection(),
                        const SizedBox(height: 48),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          // Floating Top Nav Back Button
          Positioned(
            left: 16,
            top: MediaQuery.paddingOf(context).top + 12,
            child: _floatingBackButton(),
          ),
        ],
      ),
    );
  }

  // Floating Back Button (w-12 h-12 rounded-full bg-[#050505]/85 border-[#27302C])
  Widget _floatingBackButton() {
    return Tooltip(
      message: 'Volver',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Navigator.pop(context),
          borderRadius: BorderRadius.circular(24),
          child: Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xD9050505),
              border: Border.all(color: _line),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black45,
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.arrow_back_rounded,
              color: Color(0xFFF5F5F5),
              size: 20,
            ),
          ),
        ),
      ),
    );
  }

  // Primary & Secondary Action Buttons (Buttons.tsx)
  Widget _actionsPhone() {
    final hasEps = currentSeasonEpisodes.isNotEmpty;
    final next = _nextUnfinishedEpisode;
    final nextIndex = next == null
        ? null
        : currentSeasonEpisodes.indexWhere((c) => c.url == next.url);
    final targetIndex = (nextIndex != null && nextIndex >= 0) ? nextIndex : 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Primary Button: la serie sigue donde quedo, no siempre en T1:E1.
        FilledButton.icon(
          onPressed: hasEps && next != null
              ? () => unawaited(
                  _play(next, index: targetIndex),
                )
              : null,
          style: FilledButton.styleFrom(
            backgroundColor: _red,
            foregroundColor: const Color(0xFF050505),
            minimumSize: const Size(double.infinity, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
          icon: const Icon(
            Icons.play_arrow_rounded,
            color: Color(0xFF050505),
            size: 20,
          ),
          label: Text(
            _primaryPlayLabel,
            style: const TextStyle(
              color: Color(0xFF050505),
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ),
        const SizedBox(height: 10),
        // Secondary Buttons (Mi Lista / Compartir)
        Row(
          children: [
            Expanded(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => unawaited(_favorite()),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    height: 64,
                    decoration: BoxDecoration(
                      color: _surfaceControl,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _line),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          channel.isFavorite
                              ? Icons.check_rounded
                              : Icons.add_rounded,
                          color: channel.isFavorite
                              ? _red
                              : const Color(0xFFF5F5F5),
                          size: 18,
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Mi Lista',
                          style: TextStyle(
                            color: Color(0xFFF5F5F5),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => unawaited(_share()),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    height: 64,
                    decoration: BoxDecoration(
                      color: _surfaceControl,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _line),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(
                          Icons.share_outlined,
                          color: Color(0xFFF5F5F5),
                          size: 18,
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Compartir',
                          style: TextStyle(
                            color: Color(0xFFF5F5F5),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Synopsis & Technical Specs DL Grid (DetailsView.tsx L147-185)
  Widget _synopsisSection() {
    final plot = widget.series.plot?.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'SINOPSIS',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: _muted,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          (plot != null && plot.isNotEmpty)
              ? plot
              : 'Sin descripción disponible para esta serie.',
          style: const TextStyle(
            color: _textSecondary,
            fontSize: 14,
            height: 1.55,
            fontWeight: FontWeight.normal,
          ),
        ),
        _technicalSpecs(),
      ],
    );
  }

  Widget _technicalSpecs() {
    final director = widget.series.director?.trim();
    final writer = widget.series.writer?.trim();
    final genre = widget.series.genre?.trim();
    final releaseDate = widget.series.releaseDate?.trim();
    final year = widget.series.year?.trim();
    final rating = widget.series.rating?.trim();
    final seasonsCount = seasons.length;
    final duration =
        '${seasonsCount > 0 ? seasonsCount : 1} Temporada${seasonsCount == 1 ? '' : 's'}';

    Widget specCell(String label, String value) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Color(0xFF7D8581),
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value.isNotEmpty ? value : 'No disponible',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFFF5F5F5),
              height: 1.25,
            ),
          ),
        ],
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.only(top: 16),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xB327302C))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: specCell('Dirección', director ?? 'No disponible'),
              ),
              const SizedBox(width: 16),
              Expanded(child: specCell('Guion', writer ?? 'No disponible')),
            ],
          ),
          const SizedBox(height: 12),
          specCell('Género', genre ?? 'No disponible'),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: specCell(
                  'Fecha de estreno',
                  releaseDate ?? 'No disponible',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(child: specCell('Año', year ?? 'No disponible')),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: specCell(
                  'Rating IMDb',
                  rating != null && rating.isNotEmpty
                      ? '$rating / 10'
                      : 'No disponible',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(child: specCell('Duración', duration)),
            ],
          ),
        ],
      ),
    );
  }

  // Episodes Header & Dropdown Season Selector (DetailsView.tsx L188-257)
  Widget _episodesHeader() {
    final current = currentSeasonKey;
    final label = _seasonLabel(current);

    return Container(
      margin: const EdgeInsets.only(top: 24, bottom: 12),
      padding: const EdgeInsets.only(bottom: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0x9927302C))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.tv_rounded, size: 16, color: _red),
              SizedBox(width: 8),
              Text(
                'Episodios',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => unawaited(_openSeasonSelector(context)),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: _surfaceControl,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _line),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 16,
                      color: _muted,
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

  Future<void> _openSeasonSelector(BuildContext context) async {
    final keys = seasons.keys.toList();
    if (keys.isEmpty) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: _line),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 8, bottom: 12),
                  child: Text(
                    'Temporadas',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ...keys.map((key) {
                  final isSelected = key == currentSeasonKey;
                  final label = _seasonLabel(key);
                  return InkWell(
                    onTap: () {
                      setState(() => season = key);
                      Navigator.pop(sheetContext);
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      margin: const EdgeInsets.only(bottom: 6),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? _surfaceControl
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            label,
                            style: TextStyle(
                              color: isSelected
                                  ? const Color(0xFFF5F5F5)
                                  : _textSecondary,
                              fontSize: 14,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                          if (isSelected)
                            const Icon(
                              Icons.check_rounded,
                              color: _red,
                              size: 18,
                            ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  // Episode Card (Cards.tsx L211-278)
  Widget _episodeCard(Channel episode, int index) {
    final thumbUrl =
        episode.backdrop ??
        episode.logo ??
        widget.series.backdrop ??
        widget.series.cover;
    final hasThumb = thumbUrl != null && thumbUrl.trim().isNotEmpty;
    final duration = (episode.duration ?? '').trim();
    final saved = PlaybackProgress.load(episode);
    final fraction = saved?.fraction ?? episode.progressFraction;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _line.withValues(alpha: 0.8)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => unawaited(_play(episode, index: index)),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 16:9 Thumbnail
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 112,
                    height: 63,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (hasThumb)
                          CachedNetworkImage(
                            imageUrl: thumbUrl,
                            fit: BoxFit.cover,
                            memCacheWidth: 320,
                            errorWidget: (_, _, _) => Container(
                              color: _surfaceControl,
                              child: const Icon(
                                Icons.movie_creation_outlined,
                                color: _line,
                                size: 24,
                              ),
                            ),
                          )
                        else
                          Container(
                            color: _surfaceControl,
                            child: const Icon(
                              Icons.movie_creation_outlined,
                              color: _line,
                              size: 24,
                            ),
                          ),
                        const ColoredBox(color: Color(0x4D000000)),
                        Center(
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xE600C781),
                            ),
                            child: const Icon(
                              Icons.play_arrow_rounded,
                              color: Color(0xFF050505),
                              size: 18,
                            ),
                          ),
                        ),
                        if (fraction != null && fraction > 0)
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: SizedBox(
                              height: 4,
                              child: LinearProgressIndicator(
                                value: fraction.clamp(0.0, 1.0),
                                backgroundColor: const Color(0x99000000),
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  _red,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Episode Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            'Episodio ${index + 1}',
                            style: const TextStyle(
                              color: _red,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (duration.isNotEmpty) ...[
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 5),
                              child: Text('•', style: TextStyle(color: _line)),
                            ),
                            Text(
                              duration,
                              style: const TextStyle(
                                color: _muted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        episode.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFFF5F5F5),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          height: 1.25,
                        ),
                      ),
                      if ((episode.plot ?? '').trim().isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          episode.plot!.trim(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _muted,
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _episodesBodyPhone() {
    if (loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 32),
          child: CircularProgressIndicator(color: _red),
        ),
      );
    }
    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, color: _muted, size: 40),
              const SizedBox(height: 10),
              Text(error!, style: const TextStyle(color: _muted)),
              TextButton(
                onPressed: _load,
                child: const Text('Reintentar', style: TextStyle(color: _red)),
              ),
            ],
          ),
        ),
      );
    }

    final visible = currentSeasonEpisodes;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _episodesHeader(),
        if (visible.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Text(
                'No hay episodios disponibles para esta temporada.',
                style: TextStyle(color: _muted, fontSize: 13),
              ),
            ),
          )
        else
          ...List.generate(
            visible.length,
            (index) => _episodeCard(visible[index], index),
          ),
      ],
    );
  }

  // Reparto Principal (DetailsView.tsx L271-294)
  Widget _castSection() {
    final castRaw = widget.series.cast?.trim();
    if (castRaw == null || castRaw.isEmpty) return const SizedBox.shrink();
    final actors = castRaw
        .split(',')
        .map((a) => a.trim())
        .where((a) => a.isNotEmpty)
        .toList();
    if (actors.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        const Text(
          'Reparto Principal',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 98,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: actors.length,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final actor = actors[index];
              return SizedBox(
                width: 80,
                child: Column(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _surfaceControl,
                        border: Border.all(color: _line),
                      ),
                      child: Center(
                        child: Text(
                          actor.isNotEmpty ? actor[0].toUpperCase() : '?',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      actor,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // También te puede gustar (DetailsView.tsx L298-318)
  Widget _relatedSection() {
    final related = store.visibleAll
        .where(
          (c) =>
              c.type == MediaType.series && c.displayName != widget.series.name,
        )
        .take(6)
        .toList();
    if (related.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        const Text(
          'También te puede gustar',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: related.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 2 / 3,
          ),
          itemBuilder: (context, index) {
            final item = related[index];
            final posterUrl = item.backdrop ?? item.logo;
            return ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Material(
                color: _surfaceControl,
                child: InkWell(
                  onTap: () {
                    final s = hourTvResolveSeries(item, const []);
                    if (s != null) {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => HourTvSeriesDetailPage(series: s),
                        ),
                      );
                    }
                  },
                  child: posterUrl != null && posterUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: posterUrl,
                          fit: BoxFit.cover,
                          errorWidget: (_, _, _) => Container(
                            color: _surfaceControl,
                            child: const Icon(Icons.tv_rounded, color: _line),
                          ),
                        )
                      : Container(
                          color: _surfaceControl,
                          child: const Icon(Icons.tv_rounded, color: _line),
                        ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HERO: Backdrop cinematográfico
  // ─────────────────────────────────────────────────────────────────────────
  Widget _heroBackdrop() {
    final backdrop = widget.series.backdrop;
    final hasBackdrop = backdrop != null && backdrop.isNotEmpty;
    final cover = widget.series.cover;
    final url = hasBackdrop ? backdrop : cover;

    if (url == null || url.trim().isEmpty) {
      return const ColoredBox(color: _surface);
    }

    return CachedNetworkImage(
      imageUrl: url,
      memCacheWidth: 900,
      fit: BoxFit.cover,
      alignment: hasBackdrop ? Alignment.center : Alignment.topCenter,
      errorWidget: (_, _, _) => const ColoredBox(color: _surface),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // LAYOUT: Tablet / Desktop
  // ─────────────────────────────────────────────────────────────────────────
  Widget _wide({required bool tablet}) => Scaffold(
    backgroundColor: _bgPrimary,
    body: CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: SizedBox(
            height: tablet ? 390 : 440,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _heroBackdrop(),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Color(0xEB000000),
                        Color(0x77000000),
                        Color(0x11000000),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 20,
                  top: MediaQuery.paddingOf(context).top + 20,
                  child: _floatingBackButton(),
                ),
                Positioned(
                  left: 58,
                  bottom: 42,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: tablet ? 480 : 610),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _badge('SERIE'),
                        const SizedBox(height: 10),
                        _heroTitle(tablet ? 38 : 46),
                        const SizedBox(height: 10),
                        _heroMeta(),
                        if ((widget.series.plot ?? '').trim().isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(
                            widget.series.plot!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _textSecondary,
                              height: 1.5,
                            ),
                          ),
                        ],
                        const SizedBox(height: 18),
                        _wideActions(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(34, 24, 34, 56),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _castSection(),
                    _episodesBody(compact: tablet),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _wideActions() {
    final next = _nextUnfinishedEpisode;
    final nextIndex = next == null
        ? null
        : currentSeasonEpisodes.indexWhere((c) => c.url == next.url);
    final targetIndex = (nextIndex != null && nextIndex >= 0) ? nextIndex : 0;
    return Row(
      children: [
        FilledButton.icon(
          onPressed: next == null
              ? null
              : () => _play(next, index: targetIndex),
          style: FilledButton.styleFrom(
            backgroundColor: _red,
            foregroundColor: Colors.black,
            minimumSize: const Size(156, 52),
            shape: const StadiumBorder(),
          ),
          icon: const Icon(Icons.play_arrow_rounded),
          label: Text(
            _primaryPlayLabel,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              letterSpacing: .3,
            ),
          ),
        ),
        const SizedBox(width: 10),
        _action(
          channel.isFavorite
              ? Icons.favorite_rounded
              : Icons.favorite_border_rounded,
          _favorite,
          active: channel.isFavorite,
        ),
        const SizedBox(width: 8),
        _action(Icons.ios_share_rounded, _share),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // LAYOUT: Android TV — estructura funcional y D-pad preservada
  // ─────────────────────────────────────────────────────────────────────────
  Widget _tv() => Scaffold(
    backgroundColor: _black,
    body: Stack(
      fit: StackFit.expand,
      children: [
        _heroBackdrop(),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [_black, Color(0xEE000000), Color(0x44000000)],
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(54, 34, 54, 34),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _floatingBackButton(),
                      const Spacer(),
                      _tvSummary(),
                      const Spacer(),
                    ],
                  ),
                ),
                const SizedBox(width: 46),
                Expanded(
                  flex: 6,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: _surface.withValues(alpha: .9),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: _line),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(22),
                      child: _episodesBody(compact: true, tv: true),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  Widget _tvSummary() {
    final item = channel;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _badge('SERIE'),
        const SizedBox(height: 12),
        _heroTitle(52),
        const SizedBox(height: 10),
        _heroMeta(),
        if ((widget.series.plot ?? '').trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            widget.series.plot!,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: _textSecondary, height: 1.45),
          ),
        ],
        const SizedBox(height: 18),
        Row(
          children: [
            FilledButton.icon(
              onPressed: _nextUnfinishedEpisode == null
                  ? null
                  : () => unawaited(() async {
                        final next = _nextUnfinishedEpisode!;
                        final nextIndex = currentSeasonEpisodes.indexWhere(
                          (c) => c.url == next.url,
                        );
                        await _play(
                          next,
                          index: nextIndex >= 0 ? nextIndex : 0,
                        );
                      }()),
              style: FilledButton.styleFrom(
                backgroundColor: _red,
                foregroundColor: Colors.black,
                minimumSize: const Size(190, 56),
                elevation: 4,
                shadowColor: _red.withValues(alpha: .5),
                shape: const StadiumBorder(),
              ),
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(
                _primaryPlayLabel,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  letterSpacing: .3,
                ),
              ),
            ),
            const SizedBox(width: 10),
            _action(
              item.isFavorite
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              _favorite,
              active: item.isFavorite,
            ),
            const SizedBox(width: 8),
            _action(Icons.ios_share_rounded, _share),
          ],
        ),
      ],
    );
  }

  Widget _episodesBody({required bool compact, bool tv = false}) {
    if (loading) {
      return const Center(child: CircularProgressIndicator(color: _red));
    }
    if (error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, color: _muted, size: 42),
            const SizedBox(height: 10),
            Text(error!, style: const TextStyle(color: _muted)),
            TextButton(
              onPressed: _load,
              child: const Text('Reintentar', style: TextStyle(color: _red)),
            ),
          ],
        ),
      );
    }
    if (episodes.isEmpty) {
      return const Center(
        child: Text(
          'No hay episodios disponibles para esta temporada.',
          style: TextStyle(color: _muted),
        ),
      );
    }
    final available = seasons;
    final current = season != null && available.containsKey(season)
        ? season!
        : available.keys.first;
    final visible = available[current] ?? const <Channel>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Temporadas y Episodios',
          style: TextStyle(
            color: Colors.white,
            fontSize: tv ? 26 : 22,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 42,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: available.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final key = available.keys.elementAt(index);
              final selected = key == current;
              return ChoiceChip(
                selected: selected,
                onSelected: (_) => setState(() => season = key),
                selectedColor: _red,
                backgroundColor: _surfaceControl,
                side: BorderSide(color: selected ? _red : _line),
                shape: const StadiumBorder(),
                elevation: selected ? 4 : 0,
                pressElevation: 2,
                shadowColor: selected
                    ? _red.withValues(alpha: .4)
                    : Colors.transparent,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 4,
                ),
                label: Text(
                  _seasonLabel(key),
                  style: TextStyle(
                    color: selected ? Colors.black : _muted,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        if (tv)
          Expanded(child: _episodeList(visible, tv: true, compact: true))
        else
          _episodeList(visible, tv: false, compact: compact),
      ],
    );
  }

  Widget _episodeList(
    List<Channel> visible, {
    required bool tv,
    bool compact = true,
  }) {
    return ListView.separated(
      shrinkWrap: !tv,
      physics: tv ? null : const NeverScrollableScrollPhysics(),
      itemCount: visible.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final episode = visible[index];
        final tile = _episodeCard(episode, index);
        if (!tv) {
          return tile;
        }
        return TvFocusable(
          autofocus: index == 0,
          onTap: () => unawaited(_play(episode, index: index)),
          borderRadius: BorderRadius.circular(12),
          child: tile,
        );
      },
    );
  }

  Widget _heroTitle(double size) => Text(
    widget.series.name,
    maxLines: 2,
    overflow: TextOverflow.ellipsis,
    style: TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.w900,
      fontSize: size,
      height: 1.12,
      letterSpacing: -.9,
      shadows: const [
        Shadow(color: Color(0xCC000000), blurRadius: 12, offset: Offset(0, 2)),
      ],
    ),
  );

  Widget _heroMeta() {
    final rating = widget.series.rating?.trim();
    final year = widget.series.year?.trim();
    final parts = <Widget>[
      if (rating != null && rating.isNotEmpty)
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.star_rounded, color: Color(0xFFF5C518), size: 16),
            const SizedBox(width: 3),
            Text(
              rating,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      if (year != null && year.isNotEmpty)
        Text(
          year,
          style: const TextStyle(color: _muted, fontWeight: FontWeight.w500),
        ),
      Text(
        '${seasons.length} temporada${seasons.length == 1 ? '' : 's'}',
        style: const TextStyle(color: _muted, fontWeight: FontWeight.w500),
      ),
    ];
    return Wrap(
      spacing: 9,
      runSpacing: 5,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (var i = 0; i < parts.length; i++) ...[
          if (i > 0) const Text('•', style: TextStyle(color: _muted)),
          parts[i],
        ],
      ],
    );
  }

  Widget _badge(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: _red,
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      text,
      style: const TextStyle(
        color: Colors.black,
        fontSize: 9,
        fontWeight: FontWeight.w900,
        letterSpacing: .7,
      ),
    ),
  );

  Widget _action(
    IconData icon,
    Future<void> Function() action, {
    bool active = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => unawaited(action()),
        customBorder: const CircleBorder(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? _red : _surface,
            border: Border.all(color: active ? _red : _line),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: _red.withValues(alpha: .45),
                      blurRadius: 14,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}
