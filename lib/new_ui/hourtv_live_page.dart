import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../models/channel.dart';
import 'hourtv_player_screen.dart';
import 'hourtv_search_keyboard.dart';

const _red = Color(0xFF00C781);
const _surface = Color(0xFF101412);
const _line = Color(0xFF27302C);
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
    this.active = true,
    this.backController,
  });

  final List<Channel> channels;
  final bool preview;
  final bool phone;
  final bool tablet;
  final bool tv;
  // Cuando esta pagina vive embebida de forma permanente en una pestaña
  // (shell movil) en vez de empujarse como ruta propia, no se destruye al
  // cambiar de seccion. `active` le avisa que ya no esta a la vista para
  // pausar la miniatura en vivo; sin esto el audio seguia sonando en Buscar,
  // Perfil, etc. despues de salir de "En vivo".
  final bool active;
  final LiveBackController? backController;

  @override
  State<HourTvLivePage> createState() => _HourTvLivePageState();
}

class _HourTvLivePageState extends State<HourTvLivePage> {
  late Channel current;
  String category = 'Todos los canales';
  bool showGuide = false;
  int guideIndex = 0;
  // Buscador independiente de canales de TV: vive solo dentro de la guia,
  // no comparte estado ni comportamiento con el buscador general (Buscar).
  bool searchMode = false;
  String channelQuery = '';
  final FocusNode _searchKeyFocus = FocusNode();
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
    _searchKeyFocus.dispose();
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
    return ['Todos los canales', 'Favoritos', ...values];
  }

  List<Channel> get filtered {
    final byCategory = category == 'Todos los canales'
        ? widget.channels
        : category == 'Favoritos'
        ? widget.channels.where((channel) => channel.isFavorite)
        : widget.channels.where(
            (channel) => channel.genre == category || channel.group == category,
          );
    final query = channelQuery.trim().toLowerCase();
    if (query.isEmpty) return byCategory.toList();
    return byCategory
        .where((channel) => channel.displayName.toLowerCase().contains(query))
        .toList();
  }

  /// Buscador de canales para telefono/tablet/desktop: propio de esta
  /// pantalla, no comparte estado con el buscador general (Buscar).
  Widget _channelSearchField() {
    return TextField(
      onChanged: _setChannelQuery,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: 'Buscar canal…',
        hintStyle: const TextStyle(color: _muted),
        prefixIcon: const Icon(Icons.search_rounded, color: _muted),
        filled: true,
        fillColor: _surface,
        contentPadding: const EdgeInsets.symmetric(vertical: 0),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _line),
        ),
      ),
    );
  }

  /// Canales de la guia que coinciden con [channelQuery]. Buscador propio de
  /// esta pantalla: no lee ni escribe el estado del buscador general (Buscar).
  List<Channel> get _searchFiltered {
    final query = channelQuery.trim().toLowerCase();
    if (query.isEmpty) return widget.channels;
    return widget.channels
        .where((channel) => channel.displayName.toLowerCase().contains(query))
        .toList();
  }

  /// Actualiza la busqueda de canales y reubica el cursor de la guia en el
  /// primer resultado: sin esto, guideIndex podia quedar apuntando fuera de
  /// rango cuando la lista filtrada se encogia.
  void _setChannelQuery(String value) {
    setState(() {
      channelQuery = value;
      guideIndex = 0;
    });
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

  /// Cierra la guia de canales y devuelve el foco al manejador de mando.
  /// Unico punto de cierre: lo llaman tanto el GestureDetector del scrim
  /// (toque) como el handler de teclado/mando (Escape / Back).
  void _closeGuide() {
    setState(() => showGuide = false);
    remoteFocus.requestFocus();
  }

  KeyEventResult _remote(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (showGuide) {
      if (searchMode) {
        // Con el buscador abierto, las flechas/OK las maneja el teclado en
        // pantalla (foco real de Flutter en sus teclas), asi que aqui solo
        // se atiende el cierre. Todo lo demas se ignora para que el evento
        // siga subiendo hasta el sistema de navegacion por foco.
        if (key == LogicalKeyboardKey.escape ||
            key == LogicalKeyboardKey.goBack) {
          setState(() {
            searchMode = false;
            channelQuery = '';
            guideIndex = widget.channels.indexOf(current);
            if (guideIndex < 0) guideIndex = 0;
          });
          remoteFocus.requestFocus();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      }
      final list = _searchFiltered;
      if (key == LogicalKeyboardKey.arrowUp) {
        if (list.isNotEmpty) {
          setState(
            () => guideIndex = (guideIndex - 1 + list.length) % list.length,
          );
          _revealGuideIndex();
        }
      } else if (key == LogicalKeyboardKey.arrowDown) {
        if (list.isNotEmpty) {
          setState(() => guideIndex = (guideIndex + 1) % list.length);
          _revealGuideIndex();
        }
      } else if (key == LogicalKeyboardKey.arrowLeft) {
        // Entrada al buscador independiente de canales (solo TV, D-pad).
        setState(() => searchMode = true);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _searchKeyFocus.requestFocus();
        });
      } else if (key == LogicalKeyboardKey.enter ||
          key == LogicalKeyboardKey.select) {
        if (list.isNotEmpty) select(list[guideIndex]);
      } else if (key == LogicalKeyboardKey.escape ||
          key == LogicalKeyboardKey.backspace) {
        _closeGuide();
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
        builder: (_) => PlayerScreen(
          channel: current,
          allChannels: widget.channels,
          // Expandir = pantalla completa horizontal. En vertical el video
          // queda como una franja y no es realmente "pantalla completa".
          forceLandscape: true,
        ),
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

  // El reproductor, el buscador y las categorias van fuera del area que
  // hace scroll: antes todo vivia en un solo CustomScrollView y al bajar la
  // lista el reproductor se iba de la pantalla con el resto. Ahora solo la
  // cuadricula de canales se desplaza; lo de arriba queda siempre visible.
  Widget _touchLayout({required int columns}) {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            widget.phone ? 14 : 28,
            22,
            widget.phone ? 14 : 28,
            16,
          ),
          // Mismo tamaño que los demas titulos de seccion (Buscar, Perfil,
          // Mi Biblioteca): antes 30px se veia mas grande que el resto.
          child: const Align(
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.live_tv_outlined,
                  color: Color(0xFF00C781),
                  size: 22,
                ),
                SizedBox(width: 8),
                Text(
                  'TV EN VIVO',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.35,
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: widget.phone ? 14 : 28),
          child: _PlayerSurface(
            channel: current,
            onPlay: play,
            large: true,
            active: widget.active,
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            widget.phone ? 14 : 28,
            18,
            widget.phone ? 14 : 28,
            12,
          ),
          child: _channelSearchField(),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            widget.phone ? 14 : 28,
            0,
            widget.phone ? 14 : 28,
            12,
          ),
          child: _categoryPills(),
        ),
        Expanded(
          child: GridView.builder(
            padding: EdgeInsets.fromLTRB(
              widget.phone ? 14 : 28,
              0,
              widget.phone ? 14 : 28,
              40,
            ),
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
            'TV EN VIVO',
            style: TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.w900,
              letterSpacing: .3,
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
                    _channelSearchField(),
                    const SizedBox(height: 12),
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
            // Sin insignia "EN VIVO": toda la seccion ya es TV en vivo, el
            // indicador solo repetia lo obvio encima del video.
            child: Text(
              'CH ${widget.channels.indexOf(current) + 1}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
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
                SizedBox(width: 420, child: _ProgramProgress(channel: current)),
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
                onTap: _closeGuide,
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
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Guía de canales',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 26,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            // Buscador independiente: filtra SOLO esta guia
                            // de canales, no toca el buscador general de la
                            // app (Buscar) ni comparte su estado con el.
                            IconButton(
                              tooltip: searchMode
                                  ? 'Cerrar buscador'
                                  : 'Buscar canal',
                              onPressed: () => setState(() {
                                searchMode = !searchMode;
                                if (!searchMode) {
                                  channelQuery = '';
                                  guideIndex = widget.channels.indexOf(current);
                                  if (guideIndex < 0) guideIndex = 0;
                                }
                              }),
                              icon: Icon(
                                searchMode
                                    ? Icons.close_rounded
                                    : Icons.search_rounded,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          searchMode
                              ? 'Atrás cierra el buscador'
                              : '↑ ↓ navegar  •  OK ver  •  ← buscar  •  Atrás cerrar',
                          style: const TextStyle(color: _muted, fontSize: 12),
                        ),
                        const SizedBox(height: 14),
                        if (searchMode) ...[
                          TvSearchKeyboard(
                            query: channelQuery,
                            onChanged: _setChannelQuery,
                            hint: 'Nombre del canal…',
                            firstKeyFocusNode: _searchKeyFocus,
                          ),
                          const SizedBox(height: 14),
                        ],
                        Expanded(
                          child: _searchFiltered.isEmpty
                              ? const Center(
                                  child: Text(
                                    'Sin resultados',
                                    style: TextStyle(color: _muted),
                                  ),
                                )
                              : ListView.builder(
                                  controller: guideScroll,
                                  itemCount: _searchFiltered.length,
                                  itemExtent: _guideRowExtent,
                                  itemBuilder: (context, index) {
                                    final channel = _searchFiltered[index];
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: _GuideRow(
                                        channel: channel,
                                        number:
                                            widget.channels.indexOf(channel) +
                                            1,
                                        active: channel.url == current.url,
                                        focused: index == guideIndex,
                                        onTap: () => select(channel),
                                      ),
                                    );
                                  },
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

  Future<void> _showCategorySelector() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: _surface,
      barrierColor: Colors.black.withValues(alpha: .72),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) {
        final options = categories;
        return SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: _line,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Categorías',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Selecciona una categoría',
                  style: TextStyle(color: _muted, fontSize: 12),
                ),
                const SizedBox(height: 14),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: options.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 3.25,
                  ),
                  itemBuilder: (context, index) {
                    final item = options[index];
                    final active = item == category;
                    return Material(
                      color: active ? _red : const Color(0xFF151917),
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        onTap: () => Navigator.pop(sheetContext, item),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: active ? _red : _line),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                item == 'Favoritos'
                                    ? Icons.star_rounded
                                    : Icons.layers_rounded,
                                size: 16,
                                color: active ? Colors.black : _red,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  item,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: active ? Colors.black : Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              if (active)
                                const Icon(
                                  Icons.check_rounded,
                                  size: 16,
                                  color: Colors.black,
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
    if (selected != null && mounted) {
      setState(() => category = selected);
    }
  }

  Widget _categoryPills() {
    return Material(
      color: _surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: _showCategorySelector,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _line),
          ),
          child: Row(
            children: [
              const Icon(Icons.layers_rounded, color: _red, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'CATEGORÍA',
                      style: TextStyle(
                        color: _muted,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: .8,
                      ),
                    ),
                    Text(
                      category,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.expand_more_rounded, color: _muted, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlayerSurface extends StatefulWidget {
  const _PlayerSurface({
    required this.channel,
    required this.onPlay,
    required this.large,
    this.tv = false,
    this.active = true,
  });
  final Channel channel;
  final VoidCallback onPlay;
  final bool large;
  final bool tv;
  final bool active;

  @override
  State<_PlayerSurface> createState() => _PlayerSurfaceState();
}

class _PlayerSurfaceState extends State<_PlayerSurface> {
  VideoPlayerController? _controller;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _PlayerSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.channel.url != widget.channel.url) {
      _load();
      return;
    }
    if (oldWidget.active == widget.active) return;
    if (widget.active) {
      // Vuelve a la pestaña En Vivo: reconecta desde cero.
      _load();
    } else {
      // Sale de la pestaña En Vivo. `dispose()` es async y en un stream en
      // vivo puede tardar un instante en llegar al reproductor nativo, asi
      // que primero se silencia y se pausa de forma sincronica (efecto
      // inmediato) y recien despues se cierra la conexion del todo.
      final controller = _controller;
      _controller = null;
      setState(() {});
      unawaited(_stopImmediately(controller));
    }
  }

  Future<void> _stopImmediately(VideoPlayerController? controller) async {
    if (controller == null) return;
    try {
      await controller.setVolume(0);
      await controller.pause();
    } catch (_) {
      // El controller puede haber quedado invalido si el stream fallo justo
      // antes de salir de la pestaña; el dispose de abajo igual se intenta.
    }
    await controller.dispose();
  }

  @override
  void dispose() {
    unawaited(_stopImmediately(_controller));
    super.dispose();
  }

  /// Reproduce el canal EN LA MISMA vista, sin pasar por el reproductor a
  /// pantalla completa: antes esta superficie solo mostraba una imagen fija
  /// (el backdrop) con un boton de play que empujaba a otra pantalla, asi
  /// que "TV en vivo" nunca reproducia video aqui mismo. Si el stream no es
  /// directamente reproducible (requiere resolucion de embed/stalker/etc.),
  /// se degrada honestamente a la miniatura + boton para abrir el
  /// reproductor completo, que si sabe resolver esos casos.
  Future<void> _load() async {
    final old = _controller;
    _controller = null;
    setState(() => _failed = false);
    await old?.dispose();
    final uri = Uri.tryParse(widget.channel.url);
    if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https')) {
      if (mounted) setState(() => _failed = true);
      return;
    }
    final controller = VideoPlayerController.networkUrl(
      uri,
      httpHeaders: widget.channel.userAgent?.isNotEmpty == true
          ? {'User-Agent': widget.channel.userAgent!}
          : const {},
    );
    try {
      await controller.initialize();
      // Si mientras esto cargaba (un stream en vivo puede tardar varios
      // segundos en conectar) el usuario ya salio de la pestaña En Vivo,
      // asignar igual `_controller` dejaba un reproductor sonando de fondo
      // que nada llegaba a cerrar: el toggle de `active` solo actuaba sobre
      // el controller que YA existia en ese instante, no sobre una carga
      // todavia en vuelo que termina despues.
      if (!mounted || !widget.active) {
        await controller.dispose();
        return;
      }
      await controller.setLooping(false);
      await controller.play();
      setState(() => _controller = controller);
    } catch (_) {
      await controller.dispose();
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final channel = widget.channel;
    final tv = widget.tv;
    final onPlay = widget.onPlay;
    final playing = _controller?.value.isInitialized == true && !_failed;
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(tv ? 0 : 18),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (playing)
              FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _controller!.value.size.width,
                  height: _controller!.value.size.height,
                  child: VideoPlayer(_controller!),
                ),
              )
            else
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
            if (!tv)
              Positioned(
                right: 12,
                top: 10,
                child: IconButton(
                  tooltip: 'Pantalla completa',
                  onPressed: onPlay,
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xB30B0B0D),
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: _red, width: 1.2),
                  ),
                  icon: const Icon(Icons.fullscreen_rounded),
                ),
              ),
            // Sin boton de play: el canal arranca solo. Mientras el stream
            // se abre se muestra un indicador de carga, no un boton que
            // sugiera que hay que pulsar algo para empezar.
            if (!tv && !playing && !_failed)
              const Center(
                child: SizedBox(
                  width: 34,
                  height: 34,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.6,
                    color: _red,
                  ),
                ),
              ),
            // Si el stream no se puede abrir aqui, se dice de frente y se
            // ofrece el reproductor completo (sabe resolver embed/stalker).
            if (!tv && _failed)
              Center(
                child: TextButton.icon(
                  onPressed: onPlay,
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xCC0B0B0D),
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.open_in_full_rounded),
                  label: const Text('Abrir en el reproductor'),
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
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _NetworkArtwork(url: channel.logo ?? channel.backdrop),
                      // Antes "VIENDO" era una pildora al final de la fila,
                      // suelta y aplastada entre el texto y el borde: aca
                      // sobre la miniatura queda claro a que titulo se
                      // refiere, como una etiqueta "al aire" convencional.
                      if (active)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: Container(
                            alignment: Alignment.center,
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            color: _red,
                            child: const Text(
                              'VIENDO',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 7.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: .4,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
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
