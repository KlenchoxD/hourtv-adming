import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/channel.dart';
import 'hourtv_player_screen.dart';

const _red = Color(0xFFF20A1A);
const _surface = Color(0xFF101012);
const _line = Color(0xFF25252A);
const _muted = Color(0xFFA6A6B0);

/// Puente para que el shell delegue el boton "atras" a la pagina En Vivo:
/// esta registra un [handler] que devuelve true si consumio el back (p. ej.
/// salio de la vista extendida a la guia) o false para que el shell siga
/// (ir al rail/Inicio).
class LiveBackController {
  bool Function()? handler;
  bool handleBack() => handler?.call() ?? false;
}

class HourTvLivePage extends StatefulWidget {
  const HourTvLivePage({
    super.key,
    required this.channels,
    required this.preview,
    required this.phone,
    required this.tablet,
    required this.tv,
    this.backController,
  });

  final List<Channel> channels;
  final bool preview;
  final bool phone;
  final bool tablet;
  final bool tv;
  final LiveBackController? backController;

  @override
  State<HourTvLivePage> createState() => _HourTvLivePageState();
}

class _HourTvLivePageState extends State<HourTvLivePage> {
  late Channel current;
  String category = 'Todos';
  bool showGuide = false;
  int guideIndex = 0;
  final FocusNode remoteFocus = FocusNode();
  // Sin esto la guia no se desplazaba: guideIndex avanzaba pero la lista se
  // quedaba quieta, asi que el resaltado se salia de pantalla (y con miles de
  // canales, abrir la guia en un canal alto mostraba la lista sin seleccion).
  final ScrollController guideScroll = ScrollController();
  static const double _guideRowExtent = 88;

  @override
  void initState() {
    super.initState();
    current = widget.channels.first;
    guideIndex = widget.channels.indexOf(current);
    widget.backController?.handler = _handleBack;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.tv && mounted) remoteFocus.requestFocus();
    });
  }

  /// Back por capas dentro de En Vivo: si la guia esta abierta, el back la
  /// CIERRA (te deja en pantalla completa) y no deja que el shell siga;
  /// con la guia ya cerrada, devuelve false para que el shell te lleve al
  /// rail.
  bool _handleBack() {
    if (!showGuide) return false;
    setState(() => showGuide = false);
    return true;
  }

  @override
  void didUpdateWidget(covariant HourTvLivePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Buscar por URL, no por identidad: Channel no define ==, asi que tras
    // recargar el catalogo las instancias son nuevas y `contains` daba false
    // -> te sacaba del canal que estabas viendo y volvia al 1.
    final sameUrl = widget.channels.indexWhere(
      (channel) => channel.url == current.url,
    );
    if (sameUrl >= 0) {
      current = widget.channels[sameUrl];
      guideIndex = sameUrl;
    } else if (widget.channels.isNotEmpty) {
      current = widget.channels.first;
      guideIndex = 0;
    }
  }

  @override
  void dispose() {
    if (widget.backController?.handler == _handleBack) {
      widget.backController!.handler = null;
    }
    remoteFocus.dispose();
    guideScroll.dispose();
    super.dispose();
  }

  /// Mantiene la fila [guideIndex] a la vista dentro de la guia. [jump] se usa
  /// al abrir la guia (posicionarse de golpe en el canal actual, sin animar
  /// miles de filas).
  void _revealGuideIndex({bool jump = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !guideScroll.hasClients) return;
      final position = guideScroll.position;
      final rowTop = guideIndex * _guideRowExtent;
      final rowBottom = rowTop + _guideRowExtent;
      final viewTop = position.pixels;
      final viewBottom = viewTop + position.viewportDimension;
      double? target;
      if (jump) {
        // Centra el canal actual en el viewport.
        target = rowTop - (position.viewportDimension - _guideRowExtent) / 2;
      } else if (rowTop < viewTop) {
        target = rowTop;
      } else if (rowBottom > viewBottom) {
        target = rowBottom - position.viewportDimension;
      }
      if (target == null) return;
      final clamped = target.clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      );
      if (jump) {
        guideScroll.jumpTo(clamped);
      } else {
        guideScroll.animateTo(
          clamped,
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  void _openGuide() {
    setState(() {
      showGuide = true;
      guideIndex = widget.channels.indexOf(current);
      if (guideIndex < 0) guideIndex = 0;
    });
    _revealGuideIndex(jump: true);
  }

  List<String> get categories {
    final values = <String>{};
    for (final channel in widget.channels) {
      final value = (channel.genre ?? channel.group ?? '').trim();
      if (value.isNotEmpty) values.add(value);
      if (values.length == 8) break;
    }
    return ['Todos', ...values];
  }

  List<Channel> get filtered {
    if (category == 'Todos') return widget.channels;
    return widget.channels
        .where(
          (channel) => channel.genre == category || channel.group == category,
        )
        .toList();
  }

  void select(Channel channel) {
    setState(() {
      current = channel;
      guideIndex = widget.channels.indexOf(channel);
      showGuide = false;
    });
    remoteFocus.requestFocus();
  }

  // Envuelve al llegar a una punta (del ultimo canal pasa al primero y
  // viceversa), en vez de trabarse en el limite.
  void flip(int direction) {
    final count = widget.channels.length;
    if (count == 0) return;
    final index = widget.channels.indexOf(current);
    final next = (index + direction) % count;
    select(widget.channels[next < 0 ? next + count : next]);
  }

  KeyEventResult _remote(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (showGuide) {
      if (key == LogicalKeyboardKey.arrowUp) {
        setState(
          () => guideIndex =
              (guideIndex - 1 + widget.channels.length) %
              widget.channels.length,
        );
        _revealGuideIndex();
      } else if (key == LogicalKeyboardKey.arrowDown) {
        setState(
          () => guideIndex = (guideIndex + 1) % widget.channels.length,
        );
        _revealGuideIndex();
      } else if (key == LogicalKeyboardKey.enter ||
          key == LogicalKeyboardKey.select) {
        select(widget.channels[guideIndex]);
      } else if (key == LogicalKeyboardKey.escape ||
          key == LogicalKeyboardKey.backspace) {
        setState(() => showGuide = false);
      } else {
        return KeyEventResult.ignored;
      }
      return KeyEventResult.handled;
    }
    // Solo arriba/abajo cambian de canal (abajo = siguiente, arriba =
    // anterior). Izquierda/derecha no hacen nada aqui. OK abre la guia.
    if (key == LogicalKeyboardKey.arrowUp) {
      flip(-1);
    } else if (key == LogicalKeyboardKey.arrowDown) {
      flip(1);
    } else if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.select) {
      _openGuide();
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  void play() {
    if (widget.preview) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Conecta una fuente IPTV para reproducir canales reales.',
          ),
        ),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            PlayerScreen(channel: current, allChannels: widget.channels),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.tv) return _tvLayout();
    if (widget.phone) return _touchLayout(columns: 1);
    if (widget.tablet) return _touchLayout(columns: 2);
    return _desktopLayout();
  }

  Widget _touchLayout({required int columns}) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              widget.phone ? 14 : 28,
              22,
              widget.phone ? 14 : 28,
              16,
            ),
            child: const Text(
              'TV en vivo',
              style: TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: widget.phone ? 14 : 28),
            child: _PlayerSurface(channel: current, onPlay: play, large: true),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              widget.phone ? 14 : 28,
              18,
              widget.phone ? 14 : 28,
              12,
            ),
            child: _categoryPills(),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            widget.phone ? 14 : 28,
            0,
            widget.phone ? 14 : 28,
            40,
          ),
          sliver: SliverGrid.builder(
            itemCount: filtered.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisSpacing: 9,
              crossAxisSpacing: 9,
              childAspectRatio: widget.phone ? 3.15 : 3.0,
            ),
            itemBuilder: (context, index) {
              final channel = filtered[index];
              return _GuideRow(
                channel: channel,
                number: widget.channels.indexOf(channel) + 1,
                active: channel.url == current.url,
                focused: false,
                onTap: () => select(channel),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _desktopLayout() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(32, 32, 32, 50),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'TV en vivo',
            style: TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: _PlayerSurface(
                  channel: current,
                  onPlay: play,
                  large: true,
                ),
              ),
              const SizedBox(width: 22),
              Expanded(
                child: Column(
                  children: [
                    _categoryPills(),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 560,
                      child: ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final channel = filtered[index];
                          return SizedBox(
                            height: 92,
                            child: _GuideRow(
                              channel: channel,
                              number: widget.channels.indexOf(channel) + 1,
                              active: channel.url == current.url,
                              focused: false,
                              onTap: () => select(channel),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tvLayout() {
    return Focus(
      focusNode: remoteFocus,
      onKeyEvent: _remote,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _PlayerSurface(channel: current, onPlay: play, large: true, tv: true),
          Positioned(
            left: 32,
            top: 28,
            child: Row(
              children: [
                const _LiveBadge(),
                const SizedBox(width: 12),
                Text(
                  'CH ${widget.channels.indexOf(current) + 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 38,
            right: 38,
            bottom: 34,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  current.displayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _currentTitle(current),
                  style: const TextStyle(color: Colors.white70, fontSize: 16),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: 420,
                  child: _ProgramProgress(channel: current),
                ),
                const SizedBox(height: 8),
                Text(
                  'A continuación: ${_nextTitle(current)}',
                  style: const TextStyle(color: _muted, fontSize: 13),
                ),
                const SizedBox(height: 14),
                // Sin boton clickeable: todo se maneja por control, como en
                // el diseño original (hint dinamico segun el estado).
                Text(
                  '↑ ↓ cambiar canal   •   OK para ver la guía',
                  style: TextStyle(
                    color: _muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: .2,
                  ),
                ),
              ],
            ),
          ),
          // Guia como panel deslizante angosto desde la izquierda (como
          // Pluto/Netflix), con el video detras atenuado, NO tapado del todo.
          IgnorePointer(
            ignoring: !showGuide,
            child: AnimatedOpacity(
              opacity: showGuide ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              child: GestureDetector(
                onTap: () => setState(() => showGuide = false),
                child: Container(color: const Color(0x80000000)),
              ),
            ),
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            left: showGuide ? 0 : -380,
            top: 0,
            bottom: 0,
            width: 380,
            child: IgnorePointer(
              ignoring: !showGuide,
              child: Container(
                color: const Color(0xF20B0B0D),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Guía de canales',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          '↑ ↓ navegar  •  OK ver  •  Atrás cerrar',
                          style: TextStyle(color: _muted, fontSize: 12),
                        ),
                        const SizedBox(height: 18),
                        Expanded(
                          child: ListView.builder(
                            controller: guideScroll,
                            itemCount: widget.channels.length,
                            itemExtent: _guideRowExtent,
                            itemBuilder: (context, index) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _GuideRow(
                                channel: widget.channels[index],
                                number: index + 1,
                                active: widget.channels[index].url == current.url,
                                focused: index == guideIndex,
                                onTap: () => select(widget.channels[index]),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _categoryPills() {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final item = categories[index];
          final selected = item == category;
          return ChoiceChip(
            selected: selected,
            label: Text(item),
            onSelected: (_) => setState(() => category = item),
            selectedColor: _red,
            backgroundColor: _surface,
            side: BorderSide(color: selected ? _red : _line),
            labelStyle: TextStyle(
              color: selected ? Colors.white : _muted,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
            showCheckmark: false,
          );
        },
      ),
    );
  }
}

class _PlayerSurface extends StatelessWidget {
  const _PlayerSurface({
    required this.channel,
    required this.onPlay,
    required this.large,
    this.tv = false,
  });
  final Channel channel;
  final VoidCallback onPlay;
  final bool large;
  final bool tv;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(tv ? 0 : 18),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _NetworkArtwork(url: channel.backdrop ?? channel.logo),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x22000000),
                    Color(0x22000000),
                    Color(0xEF000000),
                  ],
                ),
              ),
            ),
            // En TV el texto vive a la izquierda: oscurece ese lado y deja el
            // derecho mas limpio, como en el diseño original.
            if (tv)
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [Color(0xCC000000), Colors.transparent],
                    stops: [0, 0.6],
                  ),
                ),
              ),
            if (!tv) Positioned(left: 14, top: 14, child: const _LiveBadge()),
            if (!tv)
              Positioned(
                right: 12,
                top: 10,
                child: IconButton.filledTonal(
                  tooltip: 'Pantalla completa',
                  onPressed: onPlay,
                  icon: const Icon(
                    Icons.fullscreen_rounded,
                    color: Colors.white,
                  ),
                ),
              ),
            if (!tv)
              Center(
                child: IconButton.filled(
                  onPressed: onPlay,
                  style: IconButton.styleFrom(
                    backgroundColor: _red,
                    minimumSize: const Size(64, 64),
                  ),
                  icon: const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 38,
                  ),
                ),
              ),
            if (!tv)
              Positioned(
                left: 16,
                right: 16,
                bottom: 14,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${channel.displayName} • ${_currentTitle(channel)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _ProgramProgress(channel: channel),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            channel.currentProgram?.timeRange ?? 'Ahora',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'A continuación: ${_nextTitle(channel)}',
                            textAlign: TextAlign.right,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _GuideRow extends StatelessWidget {
  const _GuideRow({
    required this.channel,
    required this.number,
    required this.active,
    required this.focused,
    required this.onTap,
  });
  final Channel channel;
  final int number;
  final bool active;
  final bool focused;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: focused
          ? const Color(0xFF2A2A2E)
          : (active ? const Color(0xFF171719) : _surface),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: focused
                  ? Colors.white
                  : (active ? _red.withValues(alpha: .55) : _line),
              width: focused ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 30,
                child: Text(
                  '$number',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: active ? _red : _muted,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              AspectRatio(
                aspectRatio: 16 / 9,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: _NetworkArtwork(url: channel.logo ?? channel.backdrop),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      channel.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _currentTitle(channel),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: _muted, fontSize: 10.5),
                    ),
                    const SizedBox(height: 6),
                    _ProgramProgress(channel: channel),
                  ],
                ),
              ),
              if (active) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _red,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'VIENDO',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ProgramProgress extends StatelessWidget {
  const _ProgramProgress({required this.channel});
  final Channel channel;

  @override
  Widget build(BuildContext context) {
    final program = channel.currentProgram;
    var progress = .38;
    if (program != null) {
      final total = program.stop.difference(program.start).inSeconds;
      if (total > 0) {
        progress = DateTime.now().difference(program.start).inSeconds / total;
      }
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: LinearProgressIndicator(
        value: progress.clamp(0.0, 1.0),
        minHeight: 3,
        color: _red,
        backgroundColor: Colors.white.withValues(alpha: .16),
      ),
    );
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xCC000000),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(radius: 3, backgroundColor: _red),
          SizedBox(width: 6),
          Text(
            'EN VIVO',
            style: TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: .5,
            ),
          ),
        ],
      ),
    );
  }
}

class _NetworkArtwork extends StatelessWidget {
  const _NetworkArtwork({this.url});
  final String? url;

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.trim().isEmpty) return const _Fallback();
    return CachedNetworkImage(
      imageUrl: url!,
      memCacheWidth: 720,
      fit: BoxFit.cover,
      errorWidget: (_, _, _) => const _Fallback(),
      placeholder: (_, _) => const _Fallback(),
    );
  }
}

class _Fallback extends StatelessWidget {
  const _Fallback();
  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFF171719),
      child: Center(
        child: Icon(Icons.live_tv_rounded, color: Color(0x55FFFFFF), size: 36),
      ),
    );
  }
}

String _currentTitle(Channel channel) =>
    channel.currentProgram?.title ?? channel.group ?? 'Programación en vivo';

String _nextTitle(Channel channel) =>
    channel.nextProgram?.title ?? 'Más programación';
