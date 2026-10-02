import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../mobile_ui/hourtv_mobile_components.dart';
import '../models/channel.dart';
import '../services/catalog/catalog_detail_navigator.dart';
import '../services/content_store.dart';
import '../services/device_type.dart';
import '../services/image_resolution_service.dart';
import '../services/likes_service.dart';
import '../services/parental_control_service.dart';
import '../services/playback_progress.dart';
import '../services/recommendations/related_content_engine.dart';
import '../services/share_service.dart';
import '../services/tmdb_service.dart';
import '../services/xtream_service.dart';
import 'hourtv_detail_parts.dart';
import 'hourtv_play_button.dart';
import 'hourtv_focusable.dart';
import 'hourtv_parental_gate.dart';
import 'hourtv_player_screen.dart';
import '../services/catalog/series_title_sanitizer.dart';

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
  Iterable<XtreamSeries> series, {
  bool allowSynthetic = true,
}) {
  // 1. Coincidencia directa por clave url de serie
  if (channel.url.startsWith('hourtv-series:')) {
    for (final item in series) {
      if (_seriesKey(item) == channel.url) return item;
    }
  }

  // 2. Coincidencia por seriesId o prefijo de tvgId
  final identity = channel.stableTitleId;
  if (identity != null && identity.isNotEmpty) {
    for (final item in series) {
      if (item.seriesId == identity ||
          identity.startsWith('${item.seriesId}:')) {
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
  if (allowSynthetic &&
      (channel.type == MediaType.series || channel.forcedType == 'series')) {
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
        if (!channel.url.startsWith('hourtv-series:') &&
            !channel.url.startsWith('catalog://') &&
            (channel.url.isNotEmpty || channel.servers.isNotEmpty))
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
  List<Channel>? _publishedEpisodes;

  /// Resultado de RelatedContentEngine, precalculado fuera de build().
  /// Se invalida cuando cambia la serie, el control parental o el catálogo.
  List<Channel> _relatedChannels = const [];
  String? _relatedCacheKey;

  bool _liked = false;

  /// Total global de Me gusta de la serie; null = aún no se sabe.
  int? _likeCount;

  String get _likeLabel {
    final count = _likeCount;
    if (count == null || count == 0) return 'Me gusta';
    return '${LikesService.format(count)} Me gusta';
  }

  Future<void> _toggleLiked() async {
    final wasLiked = _liked;
    setState(() {
      _liked = !wasLiked;
      if (_likeCount != null) {
        _likeCount = (_likeCount! + (wasLiked ? -1 : 1)).clamp(0, 1 << 31);
      }
    });
    final item = hourTvSeriesChannel(widget.series);
    final nowLiked = await LikesService.toggle(item);
    final confirmed = await LikesService.count(item);
    if (!mounted) return;
    setState(() {
      _liked = nowLiked;
      if (confirmed != null) _likeCount = confirmed;
    });
  }

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

  /// El episodio ya se empezó (más de 10 s vistos y sin terminar).
  bool _hasProgress(Channel episode) {
    final saved = PlaybackProgress.load(episode);
    return saved != null && !saved.isCompleted && saved.positionMs >= 10000;
  }

  String get _primaryPlayLabel {
    final current = currentSeasonEpisodes;
    if (current.isEmpty) return 'Reproducir';
    final sNum = _seasonNumber(currentSeasonKey);
    final next = _nextUnfinishedEpisode;
    if (next != null && next.tvgId != null) {
      final marker = RegExp(r'S\d+:\s*E?(\d+)|:(\d+)$').firstMatch(next.tvgId!);
      final episodeNumber = marker?.group(1) ?? marker?.group(2);
      if (episodeNumber != null) {
        return '${_hasProgress(next) ? 'Continuar' : 'Reproducir'} T$sNum:E$episodeNumber';
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
    final likeItem = hourTvSeriesChannel(widget.series);
    _liked = LikesService.isLiked(likeItem);
    unawaited(
      LikesService.count(likeItem).then((count) {
        if (mounted && count != null) setState(() => _likeCount = count);
      }),
    );
    unawaited(_load());
    _rebuildRelated();
  }

  @override
  void dispose() {
    store.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) {
      final published = hourTvResolveSeries(
        hourTvSeriesChannel(widget.series),
        store.visibleSeries,
        allowSynthetic: false,
      )?.episodes;
      if (published != null &&
          published.isNotEmpty &&
          !identical(published, _publishedEpisodes)) {
        _publishedEpisodes = published;
        episodes = List<Channel>.from(published);
        loading = false;
        error = null;
      }
      _rebuildRelated();
      setState(() {});
    }
  }

  /// Recalcula los contenidos relacionados usando RelatedContentEngine.
  /// Clave de invalidación: serie actual + perfil infantil + tamaño del catálogo.
  void _rebuildRelated() {
    final isKids = ParentalControlService.isEnabled;
    final seriesKey = widget.series.seriesId;
    final catalogRevision = store.visibleAll.length;
    final newKey = '$seriesKey|$isKids|$catalogRevision';
    if (newKey == _relatedCacheKey) return;
    _relatedCacheKey = newKey;

    final target = hourTvSeriesChannel(widget.series);
    final candidates = store.visibleAll
        .where((c) => c.type == MediaType.series || c.forcedType == 'series')
        .toList();

    _relatedChannels = RelatedContentEngine.instance.getRelated(
      target: target,
      candidates: candidates,
      isKidsProfile: isKids,
      limit: 6,
    );
  }

  Future<void> _load() async {
    try {
      final published = hourTvResolveSeries(
        hourTvSeriesChannel(widget.series),
        store.visibleSeries,
        allowSynthetic: false,
      )?.episodes;
      _publishedEpisodes = published;
      final existingEpisodes = published?.isNotEmpty == true
          ? published
          : widget.series.episodes;
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
        // Una actualización del catálogo pudo llegar durante fetchEpisodes.
        episodes = _publishedEpisodes?.isNotEmpty == true
            ? List<Channel>.from(_publishedEpisodes!)
            : finalEpisodes;
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
    final epList = currentSeasonEpisodes;
    final seasonCount = seasons.length;
    return Scaffold(
      backgroundColor: _bgPrimary,
      body: CustomScrollView(
        key: const PageStorageKey('hourtv-series-detail-scroll'),
        slivers: [
          SliverToBoxAdapter(
            child: HourTvDetailPhoneHeader(
              title: SeriesTitleSanitizer.sanitize(widget.series.name),
              meta: HourTvDetailMeta(
                rating: widget.series.rating,
                year: widget.series.year,
                extra: seasonCount == 0
                    ? null
                    : '$seasonCount temporada${seasonCount == 1 ? '' : 's'}',
              ),
              backdropUrl: widget.series.backdrop,
              posterUrl: widget.series.cover,
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _playPhone(),
                  const SizedBox(height: 18),
                  HourTvDetailActionBoxes(
                    inList: channel.isFavorite,
                    onList: () => unawaited(_favorite()),
                    liked: _liked,
                    likeLabel: _likeLabel,
                    onLike: () => unawaited(_toggleLiked()),
                    onCast: kIsWeb ? null : () => unawaited(_castNext()),
                  ),
                  const SizedBox(height: 20),
                  HourTvDetailInfo(
                    plot: widget.series.plot,
                    director: widget.series.director,
                    writer: widget.series.writer,
                    genre: widget.series.genre,
                    releaseDate: widget.series.releaseDate,
                    year: widget.series.year,
                    rating: widget.series.rating,
                    duration: seasonCount == 0 ? null : '$seasonCount',
                    durationLabel: 'Temporadas',
                  ),
                  _episodesHeader(),
                ],
              ),
            ),
          ),
          if (loading)
            const SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: CircularProgressIndicator(color: _red),
                ),
              ),
            )
          else if (error != null)
            SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.cloud_off_rounded,
                        color: _muted,
                        size: 40,
                      ),
                      const SizedBox(height: 10),
                      Text(error!, style: const TextStyle(color: _muted)),
                      TextButton(
                        onPressed: _load,
                        child: const Text(
                          'Reintentar',
                          style: TextStyle(color: _red),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else if (epList.isEmpty)
            const SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Text(
                    'No hay episodios disponibles para esta temporada.',
                    style: TextStyle(color: _muted, fontSize: 13),
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList.builder(
                key: const ValueKey('hourtv-series-episodes-sliver-list'),
                itemCount: epList.length,
                itemBuilder: (context, index) =>
                    _episodeCard(epList[index], index),
              ),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [_relatedSection(), const SizedBox(height: 48)],
              ),
            ),
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

  /// Reproducir o Continuar el episodio donde quedó la serie, con su avance.
  Widget _playPhone() {
    final next = _nextUnfinishedEpisode;
    final nextIndex = next == null
        ? -1
        : currentSeasonEpisodes.indexWhere((c) => c.url == next.url);
    final saved = next == null ? null : PlaybackProgress.load(next);
    final resuming = next != null && _hasProgress(next);
    final left = saved == null || saved.durationMs <= 0
        ? 0
        : ((saved.durationMs - saved.positionMs) / 60000).ceil();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HourTvPlayButton(
          label: _primaryPlayLabel,
          onPressed: next == null
              ? null
              : () => unawaited(
                  _play(next, index: nextIndex >= 0 ? nextIndex : 0),
                ),
        ),
        if (resuming && saved != null) ...[
          const SizedBox(height: 10),
          HourTvResumeProgress(
            fraction: saved.fraction,
            label: left > 0 ? 'Quedan $left min' : 'Casi terminado',
          ),
        ],
      ],
    );
  }

  /// Transmite a la TV el episodio donde quedó la serie.
  Future<void> _castNext() async {
    final next =
        _nextUnfinishedEpisode ??
        (currentSeasonEpisodes.isEmpty ? null : currentSeasonEpisodes.first);
    if (next == null) return;
    await hourTvCastChannel(
      context,
      next,
      title:
          '${SeriesTitleSanitizer.sanitize(widget.series.name)} · '
          'T${_seasonNumber(currentSeasonKey)}:E${_episodeNumber(next, 0)}',
    );
    if (mounted) setState(() {});
  }

  /// Número del episodio ("S1:E4" o "serie:1:4" en tvgId); si no, su orden.
  static int _episodeNumber(Channel episode, int index) {
    final id = episode.tvgId ?? '';
    final match = RegExp(r'E(\d+)$|:(\d+)$').firstMatch(id);
    return int.tryParse(match?.group(1) ?? match?.group(2) ?? '') ?? index + 1;
  }

  // "Episodios" y el selector de temporada estilo Netflix: botón gris
  // compacto; con una sola temporada, solo el texto (no hay qué elegir).
  Widget _episodesHeader() {
    final label = _seasonLabel(currentSeasonKey);
    final several = seasons.length > 1;
    return Padding(
      padding: const EdgeInsets.only(top: 28, bottom: 6),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Episodios',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          if (!several)
            Text(
              label,
              style: const TextStyle(
                color: _muted,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            )
          else
            Material(
              color: const Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(4),
              child: InkWell(
                onTap: () => unawaited(_openSeasonSelector(context)),
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 9, 10, 9),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 20,
                        color: Colors.white,
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

  // Lista de temporadas a pantalla completa sobre fondo oscuro, la elegida
  // resaltada y una X redonda abajo para cerrar (como Netflix).
  Future<void> _openSeasonSelector(BuildContext context) async {
    final keys = seasons.keys.toList();
    if (keys.length < 2) return;
    final picked = await showGeneralDialog<String>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Cerrar',
      barrierColor: const Color(0xF2000000),
      transitionDuration: const Duration(milliseconds: 160),
      pageBuilder: (dialogContext, _, _) => SafeArea(
        child: Material(
          type: MaterialType.transparency,
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final key in keys)
                          InkWell(
                            onTap: () => Navigator.pop(dialogContext, key),
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                                vertical: 14,
                              ),
                              child: Text(
                                _seasonLabel(key),
                                style: TextStyle(
                                  color: key == currentSeasonKey
                                      ? Colors.white
                                      : _muted,
                                  fontSize: key == currentSeasonKey ? 22 : 18,
                                  fontWeight: key == currentSeasonKey
                                      ? FontWeight.w800
                                      : FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 28),
                child: Material(
                  color: Colors.white,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => Navigator.pop(dialogContext),
                    child: const SizedBox(
                      width: 56,
                      height: 56,
                      child: Icon(
                        Icons.close_rounded,
                        color: Colors.black,
                        size: 28,
                        semanticLabel: 'Cerrar',
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (picked != null && mounted) setState(() => season = picked);
  }

  // Episodio estilo Netflix: miniatura y título en una fila, el resumen
  // debajo, sin bordes de tarjeta. Si el episodio no trae imagen propia se
  // muestra su número (antes se repetía la misma foto de la serie en todos).
  Widget _episodeCard(Channel episode, int index) {
    final number = _episodeNumber(episode, index);
    final name = episode.displayName.trim();
    final generic = RegExp(
      r'^(episodio|cap[ií]tulo)\s*\d+$',
      caseSensitive: false,
    ).hasMatch(name);
    final title = generic || name.isEmpty
        ? 'Episodio $number'
        : '$number. $name';
    final image = (episode.backdrop ?? episode.logo)?.trim();
    final still =
        image != null &&
            image.isNotEmpty &&
            image != widget.series.cover &&
            image != widget.series.backdrop
        ? image
        : null;
    final duration = hourTvPrettyDuration(episode.duration);
    final saved = PlaybackProgress.load(episode);
    final fraction = saved?.fraction ?? episode.progressFraction;
    final plot = episode.plot?.trim();

    return InkWell(
      onTap: () => unawaited(_play(episode, index: index)),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox(
                    width: 128,
                    height: 72,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (still != null)
                          CachedNetworkImage(
                            fadeInDuration: Duration.zero,
                            fadeOutDuration: Duration.zero,
                            imageUrl: still,
                            fit: BoxFit.cover,
                            memCacheWidth: 320,
                            errorWidget: (_, _, _) =>
                                _episodeNumberTile(number),
                          )
                        else
                          _episodeNumberTile(number),
                        Center(
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0x8C000000),
                              border: Border.all(
                                color: Colors.white,
                                width: 1.5,
                              ),
                            ),
                            child: const Icon(
                              Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                        if (fraction != null && fraction > 0)
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: LinearProgressIndicator(
                              value: fraction.clamp(0.0, 1.0),
                              minHeight: 3,
                              backgroundColor: const Color(0x99000000),
                              color: _red,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFFF5F5F5),
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                        ),
                      ),
                      if (duration != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          duration,
                          style: const TextStyle(color: _muted, fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (plot != null && plot.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                plot,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _muted,
                  fontSize: 12.5,
                  height: 1.45,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _episodeNumberTile(int number) => ColoredBox(
    color: _surfaceControl,
    child: Align(
      alignment: const Alignment(-.8, .75),
      child: Text(
        '$number',
        style: const TextStyle(
          color: Color(0x40FFFFFF),
          fontSize: 30,
          fontWeight: FontWeight.w900,
          height: 1,
        ),
      ),
    ),
  );

  // También te puede gustar (DetailsView.tsx L298-318)
  Widget _relatedSection() {
    final related = _relatedChannels;
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
            // Cuadro vertical: la portada, no el fondo horizontal recortado.
            final posterUrl = item.logo ?? item.backdrop;
            return ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Material(
                color: _surfaceControl,
                child: InkWell(
                  onTap: () {
                    CatalogDetailNavigator.openDetails(
                      context,
                      item,
                      store: store,
                    );
                  },
                  child: posterUrl != null && posterUrl.isNotEmpty
                      ? HourTvArtwork(url: posterUrl)
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

    // HourTvArtwork también muestra imágenes de sitios sin CORS en web.
    return HourTvArtwork(
      url: url,
      memCacheWidth: 1280,
      memCacheHeight: null,
      variant: ImageResolutionVariant.heroBackdrop,
      alignment: hasBackdrop ? Alignment.center : Alignment.topCenter,
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
                  // Igual que la ficha de películas: portada pequeña, título,
                  // datos y botones; la sinopsis va en la ficha de abajo.
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: tablet ? 700 : 900),
                    child: hourTvWideHeroWithPoster(
                      posterUrl: widget.series.cover,
                      width: tablet ? 110 : 150,
                      info: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _badge('SERIE'),
                          const SizedBox(height: 10),
                          _heroTitle(tablet ? 38 : 46),
                          const SizedBox(height: 10),
                          _heroMeta(),
                          const SizedBox(height: 18),
                          _wideActions(),
                        ],
                      ),
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
                    HourTvDetailInfo(
                      plot: widget.series.plot,
                      director: widget.series.director,
                      writer: widget.series.writer,
                      genre: widget.series.genre,
                      releaseDate: widget.series.releaseDate,
                      year: widget.series.year,
                      rating: widget.series.rating,
                      duration: seasons.isEmpty ? null : '${seasons.length}',
                      durationLabel: 'Temporadas',
                    ),
                    const SizedBox(height: 28),
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
        Flexible(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 280),
            child: HourTvPlayButton(
              label: _primaryPlayLabel,
              large: true,
              onPressed: next == null
                  ? null
                  : () => _play(next, index: targetIndex),
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
        Tooltip(
          message: _likeLabel,
          child: _action(
            Icons.thumb_up_alt_rounded,
            _toggleLiked,
            active: _liked,
          ),
        ),
        // Como en el celular: Transmitir en vez de Compartir (y nada en el
        // navegador, donde no hay Chromecast/DLNA).
        if (!kIsWeb) ...[
          const SizedBox(width: 8),
          Tooltip(
            message: 'Transmitir',
            child: _action(Icons.cast_rounded, _castNext),
          ),
        ],
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
    final next = _nextUnfinishedEpisode;
    final nextIndex = next == null
        ? null
        : currentSeasonEpisodes.indexWhere((c) => c.url == next.url);
    final targetIndex = (nextIndex != null && nextIndex >= 0) ? nextIndex : 0;
    final targetEp = next;
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
            Flexible(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: HourTvPlayButton(
                  label: _primaryPlayLabel,
                  large: true,
                  onPressed: targetEp == null
                      ? null
                      : () => unawaited(() async {
                          await _play(targetEp, index: targetIndex);
                        }()),
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
            Tooltip(
              message: _likeLabel,
              child: _action(
                Icons.thumb_up_alt_rounded,
                _toggleLiked,
                active: _liked,
              ),
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
    SeriesTitleSanitizer.sanitize(widget.series.name),
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
