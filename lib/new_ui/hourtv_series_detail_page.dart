import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/channel.dart';
import '../services/content_store.dart';
import '../services/device_type.dart';
import '../services/share_service.dart';
import '../services/tmdb_service.dart';
import '../services/xtream_service.dart';
import 'hourtv_focusable.dart';
import 'hourtv_player_screen.dart';
import 'hourtv_parental_gate.dart';

// ───────────────────────────────────────────────────────────────────────────────
// Paleta visual unificada con hourtv_detail_page.dart
// ───────────────────────────────────────────────────────────────────────────────
const _black = Color(0xFF050505);
const _surface = Color(0xFF101412);
const _surfaceControl = Color(0xFF151917);
const _line = Color(0xFF27302C);
const _red = Color(0xFF00C781);
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
      // Un servidor alternativo no es otro capítulo. La entrada plana
      // representa un único episodio y conserva todos sus mirrors para que el
      // reproductor nativo pueda probarlos en orden o dejar elegir al usuario.
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
  // Sin esto, un doble-toque rapido en "Reproducir" (o dos episodios
  // seguidos antes de que abra el primero) empuja el reproductor dos veces.
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

  Future<void> _play(Channel episode) async {
    if (_opening) return;
    _opening = true;
    try {
      if (!await ensureParentalAccess(context, channel) || !mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PlayerScreen(channel: episode, allChannels: episodes),
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
  // LAYOUT: Móvil
  // ─────────────────────────────────────────────────────────────────────────
  Widget _phone() {
    final screen = MediaQuery.sizeOf(context).height;
    final headerHeight = (screen * 0.42).clamp(280.0, 380.0);
    return Scaffold(
      backgroundColor: _black,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: SizedBox(
              height: _heroHeight(context, headerHeight),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _heroBackdrop(),
                  // Degradado inferior multicapa: funde la imagen con el fondo
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x00000000), Color(0x66000000), _black],
                        stops: [.42, .74, 1],
                      ),
                    ),
                  ),
                  // Viñeta lateral para legibilidad del texto
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Color(0x73000000),
                          Color(0x00000000),
                          Color(0x73000000),
                        ],
                        stops: [0, .32, 1],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 8,
                    top: MediaQuery.paddingOf(context).top + 4,
                    child: _back(),
                  ),
                  // Póster + título + metadatos en la zona inferior del hero
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 14,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _heroPoster(),
                        if (_heroPosterUrl != null) const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _badge('SERIE'),
                              const SizedBox(height: 8),
                              _heroTitle(28),
                              const SizedBox(height: 8),
                              _heroMeta(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _actions(phone: true),
                  const SizedBox(height: 20),
                  _synopsisSection(),
                  _castGenreSection(),
                  _episodesBody(compact: true),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // LAYOUT: Tablet / Desktop
  // ─────────────────────────────────────────────────────────────────────────
  Widget _wide({required bool tablet}) => Scaffold(
    backgroundColor: _black,
    body: CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: SizedBox(
            height: tablet ? _heroHeight(context, 390) : 440,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _heroBackdrop(),
                // Degradado lateral izquierdo (como hourtv_detail_page desktop)
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
                  child: _back(),
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
                        _actions(),
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
                    _castGenreSection(),
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

  // ─────────────────────────────────────────────────────────────────────────
  // LAYOUT: Android TV — estructura funcional preservada intacta
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
                      _back(),
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

  // ─────────────────────────────────────────────────────────────────────────
  // HERO: Backdrop cinematográfico (como _CinematicBackdrop de películas)
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

  // Poster vertical superpuesto al hero (móvil), 2:3, esquinas redondeadas.
  // Si la serie no trae cover, no ocupa espacio: el titulo usa el ancho completo.
  String? get _heroPosterUrl {
    final cover = widget.series.cover;
    return (cover != null && cover.trim().isNotEmpty) ? cover : null;
  }

  Widget _heroPoster() {
    final url = _heroPosterUrl;
    if (url == null) return const SizedBox.shrink();
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: CachedNetworkImage(
          imageUrl: url,
          width: 72,
          height: 108,
          fit: BoxFit.cover,
          errorWidget: (_, _, _) => const SizedBox.shrink(),
        ),
      ),
    );
  }

  // Sin banner horizontal el poster se dibuja completo (contain): el alto de
  // sobra solo produce franjas negras a los lados. Se reserva menos.
  double _heroHeight(BuildContext context, double withBackdrop) =>
      (widget.series.backdrop?.isNotEmpty ?? false)
      ? withBackdrop
      : 300 + MediaQuery.paddingOf(context).top;

  // ─────────────────────────────────────────────────────────────────────────
  // HERO: Título y metadatos
  // ─────────────────────────────────────────────────────────────────────────

  // Igual que en el detalle de pelicula: height 1.12 y sombra para despegar
  // el titulo de la imagen que tiene detras.
  Widget _heroTitle(double size) => Text(
    widget.series.name,
    maxLines: 2,
    overflow: TextOverflow.ellipsis,
    style: GoogleFonts.robotoSerif(
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

  // Solo datos que existen de verdad, separados por bullet discreto.
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

  // ─────────────────────────────────────────────────────────────────────────
  // ACCIONES: Reproducir + Favorito + Compartir
  // Callbacks preservados identicos: _play(episodes.first), _favorite, _share
  // ─────────────────────────────────────────────────────────────────────────
  Widget _actions({bool phone = false}) {
    final playButton = FilledButton.icon(
      onPressed: episodes.isEmpty ? null : () => _play(episodes.first),
      style: FilledButton.styleFrom(
        backgroundColor: _red,
        // Negro sobre verde de marca para maximo contraste, como en películas.
        foregroundColor: Colors.black,
        minimumSize: const Size(156, 52),
        elevation: 4,
        shadowColor: _red.withValues(alpha: .5),
        shape: const StadiumBorder(),
      ),
      icon: const Icon(Icons.play_arrow_rounded),
      label: const Text(
        'REPRODUCIR',
        style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: .3),
      ),
    );

    // En movil "Reproducir" manda: ancho completo. Las demas acciones bajan
    // a iconos con etiqueta, como en el detalle de peliculas.
    if (phone) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: 50, child: playButton),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _action(
                channel.isFavorite
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                _favorite,
                active: channel.isFavorite,
                label: 'Favorito',
              ),
              const SizedBox(width: 32),
              _action(Icons.ios_share_rounded, _share, label: 'Compartir'),
            ],
          ),
        ],
      );
    }

    return Row(
      children: [
        playButton,
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
  // SINOPSIS y REPARTO/GÉNERO (condicionales: si existen se muestran)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _synopsisSection() {
    final plot = widget.series.plot?.trim();
    if (plot == null || plot.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        plot,
        maxLines: 4,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: _textSecondary,
          fontSize: 13.5,
          height: 1.55,
        ),
      ),
    );
  }

  Widget _castGenreSection() {
    final cast = widget.series.cast?.trim();
    final genre = widget.series.genre?.trim();
    if ((cast == null || cast.isEmpty) && (genre == null || genre.isEmpty)) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (cast != null && cast.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(
                      text: 'Reparto: ',
                      style: TextStyle(
                        color: _muted,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                    TextSpan(
                      text: cast,
                      style: const TextStyle(
                        color: _textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          if (genre != null && genre.isNotEmpty)
            Text.rich(
              TextSpan(
                children: [
                  const TextSpan(
                    text: 'Género: ',
                    style: TextStyle(
                      color: _muted,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                  TextSpan(
                    text: genre,
                    style: const TextStyle(color: _textSecondary, fontSize: 12),
                  ),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TV: Resumen lateral (preserva la arquitectura del layout TV original)
  // ─────────────────────────────────────────────────────────────────────────
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
              onPressed: episodes.isEmpty ? null : () => _play(episodes.first),
              style: FilledButton.styleFrom(
                backgroundColor: _red,
                foregroundColor: Colors.black,
                minimumSize: const Size(190, 56),
                elevation: 4,
                shadowColor: _red.withValues(alpha: .5),
                shape: const StadiumBorder(),
              ),
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text(
                'REPRODUCIR',
                style: TextStyle(
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

  // ─────────────────────────────────────────────────────────────────────────
  // TEMPORADAS Y EPISODIOS
  // Lógica preservada intacta: seasons getter, setState(() => season = key),
  // _episodeList con InkWell/_play o TvFocusable/_play
  // ─────────────────────────────────────────────────────────────────────────
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
            TextButton(onPressed: _load, child: const Text('Reintentar')),
          ],
        ),
      );
    }
    if (episodes.isEmpty) {
      return const Center(
        child: Text(
          'No hay episodios disponibles.',
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
          style: GoogleFonts.robotoSerif(
            color: Colors.white,
            fontSize: tv ? 26 : 22,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 14),
        // Selector de temporadas: ChoiceChip preservado con estilo premium
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
                  key.replaceFirst(RegExp(r'^T'), 'Temporada '),
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
    final list = ListView.separated(
      shrinkWrap: !tv,
      physics: tv ? null : const NeverScrollableScrollPhysics(),
      itemCount: visible.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final episode = visible[index];
        final tile = _episodeTile(episode, index, tv: tv, compact: compact);
        if (!tv) {
          return InkWell(
            onTap: () => _play(episode),
            borderRadius: BorderRadius.circular(12),
            child: tile,
          );
        }
        return TvFocusable(
          autofocus: index == 0,
          onTap: () => _play(episode),
          borderRadius: BorderRadius.circular(12),
          child: tile,
        );
      },
    );
    return list;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TARJETA CINEMATOGRÁFICA DE EPISODIO
  // Miniatura 16:9 + play overlay + badge EP.X + progreso condicional +
  // título + duración condicional + sinopsis condicional
  // ─────────────────────────────────────────────────────────────────────────
  Widget _episodeTile(
    Channel episode,
    int index, {
    required bool tv,
    bool compact = true,
  }) {
    // Imagen del episodio: usa su propia imagen si existe, sino la de la serie.
    final thumbUrl = episode.backdrop ?? episode.logo ?? widget.series.cover;
    final hasThumb = thumbUrl != null && thumbUrl.trim().isNotEmpty;
    final thumbW = tv ? 160.0 : (compact ? 130.0 : 160.0);
    final thumbH = tv ? 90.0 : (compact ? 73.0 : 90.0);

    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _line),
      ),
      child: Row(
        children: [
          // ── Miniatura 16:9 con overlay ──
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(11),
              bottomLeft: Radius.circular(11),
            ),
            child: SizedBox(
              width: thumbW,
              height: thumbH,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (hasThumb)
                    CachedNetworkImage(
                      imageUrl: thumbUrl,
                      fit: BoxFit.cover,
                      memCacheWidth: 320,
                      errorWidget: (_, _, _) =>
                          const ColoredBox(color: _surface),
                    )
                  else
                    Container(
                      color: _surfaceControl,
                      child: const Icon(
                        Icons.movie_creation_outlined,
                        color: _line,
                        size: 28,
                      ),
                    ),
                  // Oscurecimiento sutil para que el play destaque
                  const ColoredBox(color: Color(0x22000000)),
                  // Play overlay centrado
                  Center(
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0x88000000),
                        border: Border.all(color: Colors.white54, width: 1.5),
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                  // Badge EP.X
                  Positioned(
                    left: 6,
                    bottom: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xCC000000),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'EP. ${index + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: .5,
                        ),
                      ),
                    ),
                  ),
                  // Barra de progreso (solo si existe y > 0)
                  if (episode.progressFraction != null &&
                      episode.progressFraction! > 0)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: SizedBox(
                        height: 3,
                        child: LinearProgressIndicator(
                          value: episode.progressFraction!,
                          backgroundColor: Colors.transparent,
                          valueColor: const AlwaysStoppedAnimation<Color>(_red),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          // ── Información del episodio ──
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: tv ? 16 : 12,
                vertical: tv ? 12 : 8,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    episode.displayName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: tv ? 15 : 13.5,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                    ),
                  ),
                  if ((episode.duration ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.access_time_rounded,
                          color: _muted,
                          size: 12,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            episode.duration!.trim(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: _muted, fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if ((episode.plot ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      episode.plot!.trim(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _textSecondary,
                        fontSize: 11,
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // WIDGETS COMPARTIDOS
  // ─────────────────────────────────────────────────────────────────────────

  // Mismo boton rediseñado que en el detalle de pelicula: cuadrado redondeado
  // con borde sutil, en vez del circulo con borde de acento grueso de antes.
  Widget _back() => Tooltip(
    message: 'Volver',
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.pop(context),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _black.withValues(alpha: .55),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white24),
          ),
          child: const Icon(
            Icons.arrow_back_rounded,
            color: Colors.white,
            size: 20,
          ),
        ),
      ),
    ),
  );

  // Mismo rediseño circular que en el detalle de pelicula: relleno verde y
  // sombra cuando esta activo, en vez del cuadrado plano de antes.
  Widget _action(
    IconData icon,
    Future<void> Function() action, {
    bool active = false,
    String? label,
  }) {
    final button = Material(
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

    if (label != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          button,
          const SizedBox(height: 6),
          Text(
            label,
            maxLines: 1,
            style: const TextStyle(
              color: _muted,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    }
    return button;
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
}
