import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/channel.dart';
import '../services/content_store.dart';
import '../services/device_type.dart';
import '../services/share_service.dart';
import '../services/xtream_service.dart';
import 'hourtv_focusable.dart';
import 'hourtv_player_screen.dart';

const _black = Color(0xFF050505);
const _surface = Color(0xFF111113);
const _line = Color(0xFF29292E);
const _muted = Color(0xFFA6A6B0);
const _red = Color(0xFFF20A1A);
const _green = Color(0xFF00D6A0);

String _seriesKey(XtreamSeries series) =>
    'hourtv-series:${Uri.encodeComponent(series.host)}:${Uri.encodeComponent(series.seriesId)}';

Channel hourTvSeriesChannel(XtreamSeries series) => Channel(
  name: series.name,
  url: _seriesKey(series),
  logo: series.cover,
  backdrop: series.cover,
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
  if (!channel.url.startsWith('hourtv-series:')) return null;
  for (final item in series) {
    if (_seriesKey(item) == channel.url) return item;
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
      final result =
          widget.series.episodes ??
          await XtreamService.fetchEpisodes(
            widget.series.host,
            widget.series.username,
            widget.series.password,
            widget.series.seriesId,
          );
      if (!mounted) return;
      setState(() {
        episodes = result;
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

  void _play(Channel episode) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlayerScreen(channel: episode, allChannels: episodes),
      ),
    );
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

  Widget _phone() => Scaffold(
    backgroundColor: _black,
    body: CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: SizedBox(
            height: _heroHeight(context, 430),
            child: Stack(
              fit: StackFit.expand,
              children: [
                _artwork(BoxFit.cover),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.black26, Colors.transparent, _black],
                      stops: [0, .46, 1],
                    ),
                  ),
                ),
                Positioned(
                  left: 8,
                  top: MediaQuery.paddingOf(context).top + 4,
                  child: _back(),
                ),
                Positioned(
                  left: 18,
                  right: 18,
                  // Mas aire abajo: con 8 el titulo quedaba pegado al borde
                  // de la imagen y al bloque de episodios que sigue.
                  bottom: 22,
                  child: _summary(phone: true),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
            child: _episodesBody(compact: true),
          ),
        ),
      ],
    ),
  );

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
                _artwork(BoxFit.cover),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [_black, Color(0xE6000000), Colors.transparent],
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
                    child: _summary(phone: false),
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
                child: _episodesBody(compact: tablet),
              ),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _tv() => Scaffold(
    backgroundColor: _black,
    body: Stack(
      fit: StackFit.expand,
      children: [
        _artwork(BoxFit.cover),
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
                      _summary(phone: false, tv: true),
                      const Spacer(),
                    ],
                  ),
                ),
                const SizedBox(width: 46),
                Expanded(
                  flex: 6,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xE6111113),
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

  Widget _summary({required bool phone, bool tv = false}) {
    final item = channel;
    return Column(
      crossAxisAlignment: phone
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        Wrap(
          alignment: phone ? WrapAlignment.center : WrapAlignment.start,
          spacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _badge('SERIE'),
            const Text(
              '98% COINCIDENCIA',
              style: TextStyle(
                color: _green,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          widget.series.name,
          textAlign: phone ? TextAlign.center : TextAlign.left,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          // Igual que en el detalle de pelicula: height 1.12 en vez de .98
          // (las dos lineas se tocaban) y sombra para despegar el titulo de
          // la imagen que tiene detras.
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: phone ? 30 : (tv ? 52 : 42),
            height: 1.12,
            letterSpacing: -.9,
            shadows: const [
              Shadow(
                color: Color(0xCC000000),
                blurRadius: 12,
                offset: Offset(0, 2),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          [
            widget.series.year ?? 'Serie',
            widget.series.rating ?? '16+',
            '${seasons.length} temporada${seasons.length == 1 ? '' : 's'}',
          ].join('  •  '),
          textAlign: phone ? TextAlign.center : TextAlign.left,
          style: const TextStyle(color: Colors.white70),
        ),
        if (!phone && (widget.series.plot ?? '').trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            widget.series.plot!,
            maxLines: tv ? 3 : 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white70, height: 1.45),
          ),
        ],
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: phone
              ? MainAxisAlignment.center
              : MainAxisAlignment.start,
          children: [
            Expanded(
              flex: phone ? 1 : 0,
              child: FilledButton.icon(
                onPressed: episodes.isEmpty
                    ? null
                    : () => _play(episodes.first),
                style: FilledButton.styleFrom(
                  backgroundColor: _red,
                  foregroundColor: Colors.white,
                  minimumSize: Size(tv ? 190 : 150, tv ? 56 : 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text(
                  'Reproducir',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
            const SizedBox(width: 10),
            _action(
              item.isFavorite ? Icons.check_rounded : Icons.add_rounded,
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
          'Episodios',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: tv ? 26 : 22,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 38,
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
                backgroundColor: _surface,
                side: BorderSide(color: selected ? _red : _line),
                label: Text(
                  key.replaceFirst(RegExp(r'^T'), 'Temporada '),
                  style: TextStyle(
                    color: selected ? Colors.white : _muted,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 14),
        if (tv)
          Expanded(child: _episodeList(visible, tv: true))
        else
          _episodeList(visible, tv: false),
      ],
    );
  }

  Widget _episodeList(List<Channel> visible, {required bool tv}) {
    final list = ListView.separated(
      shrinkWrap: !tv,
      physics: tv ? null : const NeverScrollableScrollPhysics(),
      itemCount: visible.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final episode = visible[index];
        final tile = Container(
          padding: EdgeInsets.symmetric(horizontal: tv ? 18 : 13, vertical: 11),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _line),
          ),
          child: Row(
            children: [
              Container(
                width: tv ? 52 : 42,
                height: tv ? 52 : 42,
                decoration: const BoxDecoration(
                  color: _red,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      episode.displayName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: tv ? 16 : 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Episodio ${index + 1}',
                      style: const TextStyle(color: _muted, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
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

  // Sin banner horizontal el poster se dibuja completo (contain): el alto de
  // sobra solo produce franjas negras a los lados. Se reserva menos.
  double _heroHeight(BuildContext context, double withBackdrop) =>
      (widget.series.backdrop?.isNotEmpty ?? false)
      ? withBackdrop
      : 300 + MediaQuery.paddingOf(context).top;

  Widget _artwork(BoxFit fit) {
    final backdrop = widget.series.backdrop;
    if (backdrop != null && backdrop.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: backdrop,
        memCacheWidth: 720,
        fit: fit,
        errorWidget: (_, _, _) => const ColoredBox(color: _surface),
      );
    }
    final cover = widget.series.cover;
    if (cover == null || cover.isEmpty) {
      return const ColoredBox(color: _surface);
    }
    // Sin backdrop: cover es el poster VERTICAL. Se muestra completo y
    // proporcionado sobre fondo negro liso, sin copia borrosa de relleno
    // a los lados (ensuciaba la caratula y no aportaba nada).
    return ColoredBox(
      color: _black,
      // Baja el poster lo que mide la barra de estado: si no, el reloj y los
      // iconos del sistema quedan pintados encima de la caratula.
      child: Padding(
        padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top),
        child: CachedNetworkImage(
          imageUrl: cover,
          memCacheWidth: 620,
          fit: BoxFit.contain,
          errorWidget: (_, _, _) => const ColoredBox(color: _surface),
        ),
      ),
    );
  }

  Widget _back() => IconButton(
    onPressed: () => Navigator.pop(context),
    style: IconButton.styleFrom(
      backgroundColor: const Color(0xB3101012),
      foregroundColor: Colors.white,
      side: const BorderSide(color: _red, width: 1.4),
    ),
    icon: const Icon(Icons.chevron_left_rounded),
  );

  // Mismo rediseño circular que en el detalle de pelicula: relleno rojo y
  // sombra cuando esta activo, en vez del cuadrado plano de antes.
  Widget _action(
    IconData icon,
    Future<void> Function() action, {
    bool active = false,
  }) => Material(
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
          color: active ? _red : const Color(0xCC111113),
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

  Widget _badge(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: _red,
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 9,
        fontWeight: FontWeight.w900,
        letterSpacing: .7,
      ),
    ),
  );
}
