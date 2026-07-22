import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/channel.dart';
import '../services/content_store.dart';
import '../services/device_type.dart';
import '../services/share_service.dart';
import 'hourtv_focusable.dart';
import 'hourtv_player_screen.dart';

const _red = Color(0xFFF20A1A);
const _black = Color(0xFF050505);
const _surface = Color(0xFF101012);
const _line = Color(0xFF25252A);
const _muted = Color(0xFFA6A6B0);
const _green = Color(0xFF00D6A0);

class HourTvDetailPage extends StatefulWidget {
  const HourTvDetailPage({
    super.key,
    required this.channel,
    required this.preview,
  });
  final Channel channel;
  final bool preview;

  @override
  State<HourTvDetailPage> createState() => _HourTvDetailPageState();
}

class _HourTvDetailPageState extends State<HourTvDetailPage> {
  bool liked = false;
  int tvSection = 0;
  int tvAction = 0;
  int tvRelated = 0;
  final FocusNode tvFocus = FocusNode();

  Channel get channel => widget.channel;
  ContentStore get store => ContentStore.instance;

  List<Channel> get related {
    final genre = (channel.genre ?? '').toLowerCase();
    final candidates = store.movies
        .where((item) {
          if (item.url == channel.url) return false;
          if (genre.isEmpty) return true;
          return (item.genre ?? '').toLowerCase().contains(genre) ||
              item.categories.any(
                (value) => value.toLowerCase().contains(genre),
              );
        })
        .take(6)
        .toList();
    return candidates;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (DeviceProfile.isTv(context) && mounted) tvFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    tvFocus.dispose();
    super.dispose();
  }

  void play() {
    if (widget.preview) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Conecta una fuente IPTV para reproducir contenido real.',
          ),
        ),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlayerScreen(channel: channel, allChannels: store.all),
      ),
    );
  }

  Future<void> favorite() async {
    if (widget.preview) return;
    await store.toggleFavorite(channel);
    if (mounted) setState(() {});
  }

  Future<void> share() async {
    await ShareService.shareVod(title: channel.displayName, plot: channel.plot);
  }

  void openRelated(Channel item) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => HourTvDetailPage(channel: item, preview: false),
      ),
    );
  }

  KeyEventResult onTvKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.backspace ||
        key == LogicalKeyboardKey.goBack) {
      Navigator.pop(context);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      setState(() => tvSection = (tvSection - 1).clamp(0, 1));
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      setState(() => tvSection = (tvSection + 1).clamp(0, 1));
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      setState(() {
        if (tvSection == 0) {
          tvAction = (tvAction - 1).clamp(0, 1);
        } else {
          tvRelated = (tvRelated - 1).clamp(
            0,
            related.isEmpty ? 0 : related.length - 1,
          );
        }
      });
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      setState(() {
        if (tvSection == 0) {
          tvAction = (tvAction + 1).clamp(0, 1);
        } else {
          tvRelated = (tvRelated + 1).clamp(
            0,
            related.isEmpty ? 0 : related.length - 1,
          );
        }
      });
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.select) {
      if (tvSection == 0) {
        tvAction == 0 ? play() : favorite();
      } else if (related.isNotEmpty) {
        openRelated(related[tvRelated]);
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    if (DeviceProfile.isTv(context)) return tvLayout();
    if (DeviceProfile.isPhone(context)) return phoneLayout();
    if (DeviceProfile.isTablet(context)) return tabletLayout();
    return desktopLayout();
  }

  Widget phoneLayout() {
    return Scaffold(
      backgroundColor: _black,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: SizedBox(
              height: 410,
              child: _Backdrop(
                channel: channel,
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x44000000), Color(0x22000000), _black],
                  stops: [0, .48, 1],
                ),
                child: _backButton(left: 14, top: 12),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Transform.translate(
              offset: const Offset(0, -24),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _title(29),
                    const SizedBox(height: 10),
                    _meta(),
                    const SizedBox(height: 17),
                    _actions(phone: true),
                    const SizedBox(height: 19),
                    _description(),
                    const SizedBox(height: 14),
                    _cast(),
                    const SizedBox(height: 12),
                    _genres(),
                    if (related.isNotEmpty) ...[
                      const SizedBox(height: 28),
                      _relatedRow(portrait: true, cardWidth: 112),
                    ],
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget tabletLayout() {
    return Scaffold(
      backgroundColor: _black,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: SizedBox(
              height: 360,
              child: _Backdrop(
                channel: channel,
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x44000000), Color(0x44000000), _black],
                ),
                child: Stack(
                  children: [
                    _backButton(left: 24, top: 20),
                    Positioned(
                      left: 32,
                      right: 32,
                      bottom: 26,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _badge(),
                          const SizedBox(height: 10),
                          _title(42),
                          const SizedBox(height: 10),
                          _meta(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1000),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(32, 24, 32, 60),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _actions(),
                      const SizedBox(height: 28),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _description(),
                                const SizedBox(height: 12),
                                _cast(),
                              ],
                            ),
                          ),
                          const SizedBox(width: 34),
                          Expanded(child: _genres()),
                        ],
                      ),
                      if (related.isNotEmpty) ...[
                        const SizedBox(height: 34),
                        _relatedGrid(columns: 5, portrait: true),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget desktopLayout() {
    return Scaffold(
      backgroundColor: _black,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: SizedBox(
              height: 440,
              child: _Backdrop(
                channel: channel,
                gradient: const LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Color(0xEB000000),
                    Color(0x77000000),
                    Color(0x11000000),
                  ],
                ),
                child: Stack(
                  children: [
                    _backButton(left: 28, top: 22, close: true),
                    Positioned(
                      left: 62,
                      right: 42,
                      bottom: 42,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 700),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _badge(),
                            const SizedBox(height: 12),
                            _title(52),
                            const SizedBox(height: 12),
                            _meta(),
                            const SizedBox(height: 18),
                            _actions(desktop: true),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1240),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(62, 38, 62, 70),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 2, child: _description()),
                          const SizedBox(width: 54),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _cast(),
                                const SizedBox(height: 18),
                                _genres(),
                                const SizedBox(height: 14),
                                Text(
                                  'Clasificación: ${channel.rating ?? '16+'}',
                                  style: const TextStyle(
                                    color: _muted,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (related.isNotEmpty) ...[
                        const SizedBox(height: 40),
                        _relatedGrid(columns: 3, portrait: false),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget tvLayout() {
    return Scaffold(
      backgroundColor: _black,
      body: Focus(
        focusNode: tvFocus,
        autofocus: true,
        onKeyEvent: onTvKey,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _Backdrop(
              channel: channel,
              gradient: const LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [_black, Color(0xE6000000), Color(0x55000000)],
              ),
              child: const SizedBox.expand(),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(54, 44, 54, 38),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.sizeOf(context).width * .64,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _badge(),
                        const SizedBox(height: 14),
                        _title(60),
                        const SizedBox(height: 14),
                        _meta(),
                        const SizedBox(height: 16),
                        _description(maxLines: 3, large: true),
                        const SizedBox(height: 12),
                        _cast(),
                        const SizedBox(height: 22),
                        Row(
                          children: [
                            _tvAction(
                              0,
                              Icons.play_arrow_rounded,
                              'Reproducir',
                            ),
                            const SizedBox(width: 14),
                            _tvAction(
                              1,
                              channel.isFavorite
                                  ? Icons.check_rounded
                                  : Icons.add_rounded,
                              channel.isFavorite
                                  ? 'En Mi Lista'
                                  : 'Añadir a Mi Lista',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  if (related.isNotEmpty) ...[
                    const Text(
                      'MÁS COMO ESTO',
                      style: TextStyle(
                        color: _muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 150,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: related.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 16),
                        itemBuilder: (context, index) => _TvRelatedCard(
                          channel: related[index],
                          focused: tvSection == 1 && tvRelated == index,
                          onTap: () => openRelated(related[index]),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Positioned(right: 24, top: 20, child: _TvHint()),
          ],
        ),
      ),
    );
  }

  Widget _tvAction(int index, IconData icon, String label) {
    final focused = tvSection == 0 && tvAction == index;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 15),
      decoration: BoxDecoration(
        color: focused ? Colors.white : Colors.white.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: focused ? _red : Colors.white12, width: 2),
        boxShadow: focused
            ? [BoxShadow(color: _red.withValues(alpha: .42), blurRadius: 22)]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: focused ? Colors.black : Colors.white),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              color: focused ? Colors.black : Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _backButton({
    required double left,
    required double top,
    bool close = false,
  }) {
    return Positioned(
      left: left,
      top: top,
      child: IconButton.filledTonal(
        onPressed: () => Navigator.pop(context),
        icon: Icon(
          close ? Icons.close_rounded : Icons.chevron_left_rounded,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _title(double size) => Text(
    channel.displayName,
    maxLines: 2,
    overflow: TextOverflow.ellipsis,
    style: TextStyle(
      color: Colors.white,
      fontSize: size,
      height: .98,
      fontWeight: FontWeight.w900,
      letterSpacing: -1.2,
    ),
  );

  Widget _meta() => Wrap(
    spacing: 9,
    runSpacing: 6,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      const Text(
        '98% Coincidencia',
        style: TextStyle(
          color: _green,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
      const Text('•', style: TextStyle(color: _muted)),
      Text(
        channel.year ?? '2026',
        style: const TextStyle(
          color: Colors.white70,
          fontWeight: FontWeight.w700,
        ),
      ),
      const Text('•', style: TextStyle(color: _muted)),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white38),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text(
          channel.rating ?? '16+',
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      const Text('•', style: TextStyle(color: _muted)),
      Text(
        channel.duration ?? '2h 15m',
        style: const TextStyle(
          color: Colors.white70,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );

  Widget _badge() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: _red,
      borderRadius: BorderRadius.circular(4),
    ),
    child: const Text(
      'EXCLUSIVO DE HOURTV',
      style: TextStyle(
        color: Colors.white,
        fontSize: 9,
        fontWeight: FontWeight.w900,
        letterSpacing: .7,
      ),
    ),
  );

  Widget _actions({bool phone = false, bool desktop = false}) {
    return Row(
      children: [
        Expanded(
          flex: phone ? 1 : 0,
          child: FilledButton.icon(
            onPressed: play,
            style: FilledButton.styleFrom(
              backgroundColor: desktop ? Colors.white : _red,
              foregroundColor: desktop ? Colors.black : Colors.white,
              minimumSize: const Size(158, 48),
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
        _roundAction(
          channel.isFavorite ? Icons.check_rounded : Icons.add_rounded,
          favorite,
        ),
        const SizedBox(width: 8),
        _roundAction(
          Icons.thumb_up_alt_rounded,
          () => setState(() => liked = !liked),
          active: liked,
        ),
        const SizedBox(width: 8),
        _roundAction(Icons.cast_rounded, () => unawaited(share())),
      ],
    );
  }

  Widget _roundAction(
    IconData icon,
    VoidCallback onTap, {
    bool active = false,
  }) => IconButton(
    onPressed: onTap,
    style: IconButton.styleFrom(
      backgroundColor: _surface,
      foregroundColor: active ? _red : Colors.white,
      minimumSize: const Size(48, 48),
      side: const BorderSide(color: _line),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    icon: Icon(icon),
  );

  Widget _description({int? maxLines, bool large = false}) => Text(
    channel.plot?.trim().isNotEmpty == true
        ? channel.plot!
        : 'Una historia original de HourTV donde el misterio, la emoción y la aventura cambian todo.',
    maxLines: maxLines,
    overflow: maxLines == null ? null : TextOverflow.ellipsis,
    style: TextStyle(
      color: Colors.white.withValues(alpha: .82),
      height: 1.5,
      fontSize: large ? 17 : 14,
    ),
  );

  Widget _cast() => Text(
    channel.cast?.trim().isNotEmpty == true
        ? 'Reparto: ${channel.cast}'
        : 'Reparto: Elenco original de HourTV',
    style: const TextStyle(color: _muted, fontSize: 12.5, height: 1.4),
  );

  Widget _genres() {
    final values = <String>{
      if ((channel.genre ?? '').isNotEmpty) channel.genre!,
      ...channel.categories,
    }.take(5).toList();
    if (values.isEmpty) values.addAll(['Drama', 'Misterio']);
    return Wrap(
      spacing: 7,
      runSpacing: 7,
      children: [
        for (final value in values)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _line),
            ),
            child: Text(
              value,
              style: const TextStyle(
                color: _muted,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
  }

  Widget _relatedRow({required bool portrait, required double cardWidth}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Más como esto',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: portrait ? cardWidth * 1.72 : cardWidth * .72,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: related.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) => SizedBox(
              width: cardWidth,
              child: _RelatedCard(
                channel: related[index],
                portrait: portrait,
                onTap: () => openRelated(related[index]),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _relatedGrid({required int columns, required bool portrait}) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Más como esto',
        style: TextStyle(
          color: Colors.white,
          fontSize: 21,
          fontWeight: FontWeight.w900,
        ),
      ),
      const SizedBox(height: 14),
      GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: related.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio: portrait ? .66 : 1.35,
        ),
        itemBuilder: (context, index) => _RelatedCard(
          channel: related[index],
          portrait: portrait,
          onTap: () => openRelated(related[index]),
        ),
      ),
    ],
  );
}

class _Backdrop extends StatelessWidget {
  const _Backdrop({
    required this.channel,
    required this.gradient,
    required this.child,
  });
  final Channel channel;
  final Gradient gradient;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final url = channel.backdrop ?? channel.logo;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (url != null && url.isNotEmpty)
          CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.cover,
            errorWidget: (_, _, _) => const ColoredBox(color: _surface),
          )
        else
          const ColoredBox(color: _surface),
        DecoratedBox(decoration: BoxDecoration(gradient: gradient)),
        child,
      ],
    );
  }
}

class _RelatedCard extends StatelessWidget {
  const _RelatedCard({
    required this.channel,
    required this.portrait,
    required this.onTap,
  });
  final Channel channel;
  final bool portrait;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final url = portrait ? channel.logo : (channel.backdrop ?? channel.logo);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _line),
              ),
              child: url == null
                  ? const SizedBox.expand()
                  : CachedNetworkImage(
                      imageUrl: url,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      errorWidget: (_, _, _) => const SizedBox.expand(),
                    ),
            ),
          ),
          const SizedBox(height: 7),
          Text(
            channel.displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _TvRelatedCard extends StatelessWidget {
  const _TvRelatedCard({
    required this.channel,
    required this.focused,
    required this.onTap,
  });
  final Channel channel;
  final bool focused;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TvFocusable(
      onTap: onTap,
      autofocus: false,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: focused ? 1 : .62,
        child: Container(
          width: 220,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: focused ? _red : Colors.white12,
              width: focused ? 3 : 1,
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (channel.backdrop != null || channel.logo != null)
                CachedNetworkImage(
                  imageUrl: channel.backdrop ?? channel.logo!,
                  fit: BoxFit.cover,
                  errorWidget: (_, _, _) => const SizedBox.expand(),
                ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black87],
                  ),
                ),
              ),
              Positioned(
                left: 10,
                right: 10,
                bottom: 9,
                child: Text(
                  channel.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TvHint extends StatelessWidget {
  const _TvHint();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: const Color(0xAA101012),
      borderRadius: BorderRadius.circular(9),
      border: Border.all(color: Colors.white12),
    ),
    child: const Text(
      'Flechas / Enter / Atrás',
      style: TextStyle(
        color: _muted,
        fontSize: 10,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}
