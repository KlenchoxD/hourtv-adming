import 'dart:async';
import 'dart:io' show Platform;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart' show compute, kIsWeb;
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';

import '../models/channel.dart';
import '../services/content_store.dart';
import '../services/device_type.dart';
import '../services/logo_image_provider.dart';
import '../services/storage_service.dart';
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
  final ScrollController _phoneListScroll = ScrollController();
  static const double _guideRowExtent = 88;

  // Canales que fallaron en esta sesión (403, caídos, sin conectar): no se
  // vuelven a elegir solos al entrar a En Vivo.
  static final Set<String> _deadUrls = {};
  // Un 403/caída suele afectar a todos los canales del mismo servidor
  // (5Gold, 5Live, 5Plus... del mismo proveedor): para la elección
  // automática se descarta el servidor entero.
  static final Set<String> _deadHosts = {};
  // v2: antes se guardaba cualquier canal que funcionara, aunque fuera lento
  // (A Spor, Turquía: ~6.7 s hasta el primer frame).
  static const _lastLiveUrlKey = 'lastGoodLiveUrlV2';
  static const _fastStartMs = 3000;

  static String _host(Channel c) => Uri.tryParse(c.url)?.host ?? '';

  static bool _isProbeable(Channel c) =>
      c.url.startsWith('http://') || c.url.startsWith('https://');

  static bool _usable(Channel c) =>
      !_deadUrls.contains(c.url) && !_deadHosts.contains(_host(c));
  // true mientras el canal visible lo eligió la app (no el usuario): solo
  // entonces se salta solo al siguiente si falla. Tope para no recorrer
  // miles de canales cuando no hay conexión.
  bool _autoPicked = true;
  int _autoSkipsLeft = 8;
  // Mientras se elige el canal inicial más rápido, la vista previa no
  // empieza a descargar ninguno.
  bool _racing = false;
  String? _country;

  Channel? _savedGood() {
    final last = StorageService.getSetting(_lastLiveUrlKey);
    if (last is! String) return null;
    for (final channel in widget.channels) {
      if (channel.url == last && _usable(channel)) return channel;
    }
    return null;
  }

  /// Empieza por el último canal bueno (elegido por el usuario, o elegido
  /// solo y que arrancó rápido); si no hay, por un canal del país del
  /// teléfono: sus servidores entregan el primer segmento en 0.3-0.9 s
  /// frente a varios segundos de canales lejanos del principio de la lista.
  Channel _firstAlive() {
    final saved = _savedGood();
    if (saved != null) return saved;
    final country = WidgetsBinding
        .instance
        .platformDispatcher
        .locale
        .countryCode
        ?.toLowerCase();
    if (country != null) {
      for (final channel in widget.channels) {
        if (channel.countryCode == country && _usable(channel)) return channel;
      }
    }
    return widget.channels.firstWhere(
      _usable,
      orElse: () => widget.channels.first,
    );
  }

  /// Sin canal bueno guardado: consulta a la vez la lista de reproducción de
  /// hasta 8 canales del país (red móvil/SIM) y arranca con el primero que
  /// responde. Elige un servidor cercano y descarta caídos (403) en
  /// fracciones de segundo, en vez de los 4-8 s que tarda el reproductor.
  Future<void> _raceForFastChannel() async {
    final country =
        await DeviceProfile.countryIso() ??
        WidgetsBinding.instance.platformDispatcher.locale.countryCode
            ?.toLowerCase();
    var candidates = [
      for (final c in widget.channels)
        if (_usable(c) &&
            _isProbeable(c) &&
            c.countryCode != null &&
            c.countryCode == country)
          c,
    ].take(8).toList();
    if (candidates.isEmpty) {
      candidates = widget.channels
          .where((c) => _usable(c) && _isProbeable(c))
          .take(8)
          .toList();
    }
    final winner = Completer<Channel?>();
    var pending = candidates.length;
    for (final candidate in candidates) {
      unawaited(
        compute(_probeStream, (candidate.url, candidate.userAgent)).then((ok) {
          if (!ok) _deadUrls.add(candidate.url);
          if (ok && !winner.isCompleted) winner.complete(candidate);
          if (--pending == 0 && !winner.isCompleted) winner.complete(null);
        }),
      );
    }
    if (candidates.isEmpty) winner.complete(null);
    final chosen = await winner.future.timeout(
      const Duration(milliseconds: 3500),
      onTimeout: () => null,
    );
    if (!mounted) return;
    setState(() {
      if (chosen != null && _autoPicked) {
        current = chosen;
        guideIndex = widget.channels.indexOf(chosen);
      }
      _racing = false;
    });
  }

  void _onChannelPlaying(Channel channel, int startupMs) {
    debugPrint('[LIVE] ${channel.name} primer frame en ${startupMs}ms');
    final keep = !_autoPicked || startupMs < _fastStartMs;
    if (keep && StorageService.getSetting(_lastLiveUrlKey) != channel.url) {
      unawaited(StorageService.saveSetting(_lastLiveUrlKey, channel.url));
    }
  }

  /// Antes el primer canal (p. ej. un 403) se quedaba para siempre en la
  /// miniatura sin video ni aviso: En Vivo nunca mostraba nada al entrar.
  Future<void> _onChannelFailed(Channel failed) async {
    // Sin internet todos los canales fallan: marcarlos como caídos los
    // dejaba descartados (con sus servidores) aunque volviera la conexión.
    try {
      final result = await Connectivity().checkConnectivity();
      if (result.every((r) => r == ConnectivityResult.none)) return;
    } catch (_) {}
    _deadUrls.add(failed.url);
    final host = _host(failed);
    if (host.isNotEmpty) _deadHosts.add(host);
    if (!mounted || failed.url != current.url) return;
    if (!_autoPicked || _autoSkipsLeft <= 0) return;
    final start = widget.channels.indexWhere((c) => c.url == failed.url);
    for (var i = 1; i < widget.channels.length; i++) {
      final next = widget.channels[(start + i) % widget.channels.length];
      if (!_usable(next)) continue;
      _autoSkipsLeft--;
      setState(() {
        current = next;
        guideIndex = widget.channels.indexOf(next);
      });
      return;
    }
  }

  @override
  void initState() {
    super.initState();
    ContentStore.instance.ensureEpgLoaded();
    unawaited(
      DeviceProfile.countryIso().then((iso) {
        if (mounted && iso != null) setState(() => _country = iso);
      }),
    );
    current = _firstAlive();
    if (_savedGood() == null &&
        !widget.preview &&
        widget.channels.where(_isProbeable).length > 1) {
      _racing = true;
      unawaited(_raceForFastChannel());
    }
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
      current = _firstAlive();
      guideIndex = widget.channels.indexOf(current);
      _autoPicked = true;
    }
  }

  // Como Xuper (Glide): los logos de la lista quedan decodificados en
  // memoria antes de que el usuario llegue a ellos. Sin esto, cada fila nueva
  // iba a la caché en disco (SQLite + archivo) y decodificaba justo mientras
  // pasaba por la pantalla, y el scroll rápido se trababa.
  // ponytail: tope de 400 logos (~10 MB a 50 px de alto); subir si hay más.
  static final _isTest =
      !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');
  Object? _warmedFor;
  void _warmLogos(List<Channel> channels) {
    if (identical(_warmedFor, channels) || _isTest) return;
    _warmedFor = channels;
    final urls = <String>{
      for (final c in channels.take(400))
        if ((c.logo ?? '').trim().isNotEmpty) c.logo!.trim(),
    };
    unawaited(() async {
      // Tras el primer frame: el canal arranca primero.
      await Future<void>.delayed(const Duration(milliseconds: 800));
      for (final url in urls) {
        // Nunca compite con el scroll: cada logo sin caché en memoria pasa
        // por la caché en disco en este mismo hilo. Se sigue al soltar.
        while (mounted &&
            _phoneListScroll.hasClients &&
            _phoneListScroll.position.isScrollingNotifier.value) {
          await Future<void>.delayed(const Duration(milliseconds: 250));
        }
        if (!mounted || !identical(_warmedFor, channels)) return;
        await precacheImage(
          _channelLogoProvider(url),
          context,
          onError: (_, _) {},
        );
      }
    }());
  }

  @override
  void dispose() {
    if (widget.backController?.handler == _handleBack) {
      widget.backController!.handler = null;
    }
    remoteFocus.dispose();
    guideScroll.dispose();
    _phoneListScroll.dispose();
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

  /// Orden para la lista táctil: primero los del país (servidores cercanos,
  /// arrancan en < 1 s), al final los que ya fallaron en esta sesión. Antes
  /// la lista empezaba con canales lejanos que responden 403.
  List<Channel> _touchOrdered(List<Channel> channels) {
    int rank(Channel c) => !_usable(c)
        ? 2
        : (_country != null && c.countryCode == _country ? 0 : 1);
    final indexed = [
      for (var i = 0; i < channels.length; i++) (i, channels[i]),
    ];
    indexed.sort((a, b) {
      final r = rank(a.$2).compareTo(rank(b.$2));
      return r != 0 ? r : a.$1.compareTo(b.$1);
    });
    return [for (final e in indexed) e.$2];
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

  void _selectNextAvailable() {
    // Primero dentro de lo filtrado; si no queda otro (p. ej. una búsqueda
    // con un solo resultado), en todos los canales.
    for (final pool in [filtered, widget.channels]) {
      final ordered = _touchOrdered(pool);
      final start = ordered.indexWhere((c) => c.url == current.url);
      for (var i = 1; i < ordered.length; i++) {
        final next = ordered[(start + i) % ordered.length];
        if (_usable(next)) {
          select(next);
          return;
        }
      }
    }
  }

  void select(Channel channel) {
    _autoPicked = false;
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
    if (widget.tablet) return _desktopLayout();
    return _desktopLayout();
  }

  // El reproductor, el buscador y las categorias van fuera del area que
  // hace scroll: antes todo vivia en un solo CustomScrollView y al bajar la
  // lista el reproductor se iba de la pantalla con el resto. Ahora solo la
  // cuadricula de canales se desplaza; lo de arriba queda siempre visible.
  Widget _touchLayout({required int columns}) {
    final phone = widget.phone;
    final channels = _touchOrdered(filtered);
    if (phone) _warmLogos(channels);
    return Column(
      children: [
        // En teléfono, como Xuper: el video arriba de borde a borde, sin
        // título que le quite espacio.
        if (!phone)
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
          padding: EdgeInsets.symmetric(horizontal: phone ? 0 : 28),
          child: _PlayerSurface(
            channel: current,
            onFailed: _onChannelFailed,
            onPlaying: _onChannelPlaying,
            onPlay: play,
            onNext: _selectNextAvailable,
            edgeToEdge: phone,
            large: true,
            active: widget.active && !_racing,
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
        if (phone)
          // Como Xuper: filas planas de alto fijo, de borde a borde, con logo
          // chico, número y nombre en una línea. itemExtent fijo = scroll
          // barato aunque haya cientos de canales.
          Expanded(
            child: ListView.builder(
              controller: _phoneListScroll,
              padding: const EdgeInsets.only(bottom: 24),
              itemExtent: 68,
              // Filas (y sus logos) listas unas pantallas antes de entrar.
              scrollCacheExtent: const ScrollCacheExtent.pixels(700),
              itemCount: channels.length,
              itemBuilder: (context, index) {
                final channel = channels[index];
                return _PhoneChannelRow(
                  channel: channel,
                  number: index + 1,
                  active: channel.url == current.url,
                  onTap: () => select(channel),
                );
              },
            ),
          )
        else
          Expanded(
            child: GridView.builder(
              padding: EdgeInsets.fromLTRB(
                widget.phone ? 14 : 28,
                0,
                widget.phone ? 14 : 28,
                40,
              ),
              itemCount: channels.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                mainAxisSpacing: phone ? 6 : 9,
                crossAxisSpacing: 9,
                // Filas compactas en teléfono (~8 canales a la vista, como
                // Xuper) en vez de ~3 con miniaturas grandes.
                childAspectRatio: phone ? 5.6 : 3.0,
              ),
              itemBuilder: (context, index) {
                final channel = channels[index];
                return _GuideRow(
                  channel: channel,
                  number: index + 1,
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

  // Computador y tablet: el video grande con la ficha del canal debajo y, al
  // lado (o debajo si no cabe), buscador, categorías en chips y la guía en
  // filas compactas. Sin el título gigante: la barra de arriba ya lo dice.
  Widget _desktopLayout() {
    final channels = _touchOrdered(filtered);
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = constraints.maxWidth >= 980;
        final pad = (constraints.maxWidth * .03).clamp(16.0, 40.0);
        final player = _PlayerSurface(
          channel: current,
          onFailed: _onChannelFailed,
          onPlaying: _onChannelPlaying,
          onPlay: play,
          onNext: _selectNextAvailable,
          large: true,
          active: widget.active && !_racing,
        );
        final guideHeader = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _channelSearchField(),
            const SizedBox(height: 12),
            _categoryChips(),
            const SizedBox(height: 12),
            Text(
              '${channels.length} ${channels.length == 1 ? 'canal' : 'canales'}',
              style: const TextStyle(color: _muted, fontSize: 12),
            ),
            const SizedBox(height: 8),
          ],
        );
        Widget row(int index) => _WideChannelRow(
          channel: channels[index],
          number: index + 1,
          active: channels[index].url == current.url,
          onTap: () => select(channels[index]),
        );

        if (side) {
          return Padding(
            padding: EdgeInsets.fromLTRB(pad, 16, pad, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  // Fijo: solo la lista de canales se desplaza.
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Flexible(child: player),
                      _NowPlaying(channel: current),
                    ],
                  ),
                ),
                SizedBox(width: pad),
                SizedBox(
                  width: (constraints.maxWidth * .3).clamp(320.0, 420.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      guideHeader,
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.only(bottom: 24),
                          itemExtent: 64,
                          itemCount: channels.length,
                          itemBuilder: (_, i) => row(i),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }
        // Tablet vertical: video arriba y la guía en dos columnas debajo.
        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(pad, 16, pad, 0),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    player,
                    _NowPlaying(channel: current),
                    const SizedBox(height: 8),
                    guideHeader,
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(pad, 0, pad, 32),
              sliver: SliverGrid.builder(
                itemCount: channels.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisExtent: 64,
                  crossAxisSpacing: 12,
                ),
                itemBuilder: (_, i) => row(i),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Categorías como chips a la vista (en computador una hoja que sube
  /// desde abajo se sentía de celular).
  Widget _categoryChips() => SizedBox(
    height: 36,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: categories.length,
      separatorBuilder: (_, _) => const SizedBox(width: 8),
      itemBuilder: (_, i) {
        final value = categories[i];
        final selected = value == category;
        return ChoiceChip(
          label: Text(value == 'Todos los canales' ? 'Todos' : value),
          selected: selected,
          showCheckmark: false,
          onSelected: (_) => setState(() {
            category = value;
            guideIndex = 0;
          }),
          labelStyle: TextStyle(
            color: selected ? Colors.black : Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 12.5,
          ),
          selectedColor: _red,
          backgroundColor: _surface,
          side: BorderSide(color: selected ? _red : _line),
          shape: const StadiumBorder(),
        );
      },
    ),
  );

  Widget _tvLayout() {
    return Focus(
      focusNode: remoteFocus,
      onKeyEvent: _remote,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _PlayerSurface(
            channel: current,
            onFailed: _onChannelFailed,
            onPlaying: _onChannelPlaying,
            onPlay: play,
            large: true,
            tv: true,
            active: !_racing,
          ),
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
    required this.onFailed,
    required this.onPlaying,
    required this.onPlay,
    this.onNext,
    this.edgeToEdge = false,
    required this.large,
    this.tv = false,
    this.active = true,
  });
  final Channel channel;
  final ValueChanged<Channel> onFailed;
  final void Function(Channel channel, int startupMs) onPlaying;
  final VoidCallback onPlay;
  final VoidCallback? onNext;
  final bool edgeToEdge;
  final bool large;
  final bool tv;
  final bool active;

  @override
  State<_PlayerSurface> createState() => _PlayerSurfaceState();
}

class _PlayerSurfaceState extends State<_PlayerSurface> {
  VideoPlayerController? _controller;
  bool _failed = false;
  // Se mantiene al cambiar de canal, como en Xuper.
  static bool _muted = false;

  void _toggleMute() {
    setState(() => _muted = !_muted);
    unawaited(_controller?.setVolume(_muted ? 0 : 1));
  }

  @override
  void initState() {
    super.initState();
    if (widget.active) _load();
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
    final startup = Stopwatch()..start();
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
      // ponytail: textura a propósito. Con platformView (SurfaceView, como
      // Xuper) el video no fuerza frames, pero la composición híbrida hacía
      // el scroll de la lista mucho peor (309/693 frames lentos vs ~30) y
      // duplicaba el logo del canal. Medido en el Moto G24.
    );
    try {
      // Un stream caído puede quedarse conectando indefinidamente.
      await controller.initialize().timeout(const Duration(seconds: 8));
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
      await controller.setVolume(_muted ? 0 : 1);
      await controller.play();
      setState(() => _controller = controller);
      widget.onPlaying(widget.channel, startup.elapsedMilliseconds);
    } catch (_) {
      await controller.dispose();
      if (!mounted) return;
      setState(() => _failed = true);
      if (widget.active) widget.onFailed(widget.channel);
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
        borderRadius: BorderRadius.circular(tv || widget.edgeToEdge ? 0 : 18),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (playing)
              // Llenar sin deformar agrandando la caja por layout y
              // recortando: la vista nativa no admite escalas (FittedBox).
              LayoutBuilder(
                builder: (context, box) {
                  final value = _controller!.value;
                  final ar = value.aspectRatio > 0 ? value.aspectRatio : 16 / 9;
                  final boxAr = box.maxWidth / box.maxHeight;
                  final target = ar > boxAr
                      ? Size(box.maxHeight * ar, box.maxHeight)
                      : Size(box.maxWidth, box.maxWidth / ar);
                  return ClipRect(
                    child: OverflowBox(
                      maxWidth: target.width,
                      maxHeight: target.height,
                      child: SizedBox.fromSize(
                        size: target,
                        child: VideoPlayer(_controller!),
                      ),
                    ),
                  );
                },
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
              // Mismo estilo que el botón de sonido (arriba a la izquierda),
              // a la altura del nombre del canal para no tapar la guía.
              Positioned(
                right: 8,
                bottom: 40,
                child: IconButton(
                  tooltip: 'Pantalla completa',
                  onPressed: onPlay,
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xB30B0B0D),
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.fullscreen_rounded, size: 26),
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
            if (!tv && playing)
              Positioned(
                left: 12,
                top: 10,
                child: IconButton(
                  tooltip: _muted ? 'Activar sonido' : 'Silenciar',
                  onPressed: _toggleMute,
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xB30B0B0D),
                    foregroundColor: Colors.white,
                  ),
                  icon: Icon(
                    _muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                  ),
                ),
              ),
            // Si no abre, se dice de frente. Antes decía "Abrir en el
            // reproductor", que hacía pensar que había que expandir para ver
            // cualquier canal; el reproductor completo sigue en el botón de
            // pantalla completa (sabe resolver embed/stalker).
            if (!tv && _failed)
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Este canal no está disponible',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (widget.onNext != null) ...[
                      const SizedBox(height: 10),
                      TextButton.icon(
                        onPressed: widget.onNext,
                        style: TextButton.styleFrom(
                          backgroundColor: const Color(0xCC0B0B0D),
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.skip_next_rounded),
                        label: const Text('Siguiente canal'),
                      ),
                    ] else ...[
                      const SizedBox(height: 10),
                      TextButton.icon(
                        onPressed: onPlay,
                        style: TextButton.styleFrom(
                          backgroundColor: const Color(0xCC0B0B0D),
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.open_in_full_rounded),
                        label: const Text('Abrir en el reproductor'),
                      ),
                    ],
                  ],
                ),
              ),
            if (!tv)
              Positioned(
                left: 16,
                // Deja sitio al botón de pantalla completa (abajo a la derecha).
                right: 64,
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

class _PhoneChannelRow extends StatelessWidget {
  const _PhoneChannelRow({
    required this.channel,
    required this.number,
    required this.active,
    required this.onTap,
  });
  final Channel channel;
  final int number;
  final bool active;
  final VoidCallback onTap;

  // Estilos y decoraciones constantes: cada fila nueva que entra durante un
  // deslizamiento rápido se monta con el mínimo de widgets y sin crear
  // objetos. Antes Material + InkWell armaban por fila foco, acciones,
  // semántica y detector de gestos, y eso era casi todo el costo del scroll.
  static const _numStyle = TextStyle(
    fontFeatures: [FontFeature.tabularFigures()],
  );
  static const _nameStyle = TextStyle(
    color: Colors.white,
    fontSize: 16,
    fontWeight: FontWeight.w500,
  );
  static const _activeNameStyle = TextStyle(
    color: _red,
    fontSize: 16,
    fontWeight: FontWeight.w500,
  );
  static const _programStyle = TextStyle(color: _muted, fontSize: 12.5);
  static const _deco = BoxDecoration(
    border: Border(bottom: BorderSide(color: _line, width: .6)),
  );
  static const _activeDeco = BoxDecoration(
    color: Color(0xFF16181C),
    border: Border(bottom: BorderSide(color: _line, width: .6)),
  );
  static const _playIcon = Icon(
    Icons.play_arrow_rounded,
    color: Color(0x66FFFFFF),
    size: 24,
  );
  static const _nowIcon = Icon(Icons.graphic_eq_rounded, color: _red, size: 24);

  @override
  Widget build(BuildContext context) {
    final program = channel.currentProgram?.title.trim() ?? '';
    final title = Text.rich(
      TextSpan(
        children: [
          TextSpan(text: number.toString().padLeft(3, '0'), style: _numStyle),
          TextSpan(text: '   ${channel.displayName}'),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: active ? _activeNameStyle : _nameStyle,
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: DecoratedBox(
        decoration: active ? _activeDeco : _deco,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              SizedBox(
                width: 56,
                height: 34,
                child: _ChannelLogo(url: channel.logo ?? channel.backdrop),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: program.isEmpty
                    ? title
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          title,
                          Text(
                            program,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _programStyle,
                          ),
                        ],
                      ),
              ),
              active ? _nowIcon : _playIcon,
            ],
          ),
        ),
      ),
    );
  }
}

/// Mismo proveedor (y misma clave de caché) para la precarga y la fila.
/// Decodificado a ~50 px de alto: el recuadro mide 34 dp (≈49 px en el
/// Moto G24), así la GPU lo dibuja casi 1:1 sin reducirlo en cada frame.
ImageProvider _channelLogoProvider(String url) => ResizeImage(
  kIsWeb ? NetworkImage(url) : LogoImageProvider(url),
  height: 50,
  allowUpscaling: false,
);

/// Logo del canal completo (contain), sin recortar. Un `Image` simple: más
/// liviano que CachedNetworkImage por fila y, en un deslizamiento muy rápido,
/// aplaza solo la carga de lo que pasa de largo.
class _ChannelLogo extends StatelessWidget {
  const _ChannelLogo({this.url});
  final String? url;

  static const _fallback = Icon(
    Icons.live_tv_rounded,
    color: Color(0x55FFFFFF),
    size: 24,
  );

  @override
  Widget build(BuildContext context) {
    final u = url?.trim() ?? '';
    if (u.isEmpty) return _fallback;
    // Muchos logos vienen de sitios sin CORS: en el navegador se muestran
    // como <img> normal.
    if (kIsWeb) {
      return CachedNetworkImage(
        imageUrl: u,
        fit: BoxFit.contain,
        fadeInDuration: Duration.zero,
        fadeOutDuration: Duration.zero,
        placeholder: (_, _) => const SizedBox.shrink(),
        // Sin CORS no se puede leer: se muestra como <img> del navegador.
        errorWidget: (_, _, _) => Image.network(
          u,
          fit: BoxFit.contain,
          webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
          errorBuilder: (_, _, _) => _fallback,
        ),
      );
    }
    return Image(
      image: _channelLogoProvider(u),
      fit: BoxFit.contain,
      filterQuality: FilterQuality.low,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => _fallback,
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
    // Solo con guía real (EPG): antes se dibujaba un 38 % inventado.
    final program = channel.currentProgram;
    final total = program == null
        ? 0
        : program.stop.difference(program.start).inSeconds;
    if (program == null || total <= 0) return const SizedBox.shrink();
    final progress = DateTime.now().difference(program.start).inSeconds / total;
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
      fadeInDuration: Duration.zero,
      fadeOutDuration: Duration.zero,
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

/// Pide el stream y lee el primer bloque (lista .m3u8 de pocos KB, o el
/// inicio de un .ts). true si responde bien en menos de 3 s.
Future<bool> _probeStream((String, String?) args) async {
  final (url, userAgent) = args;
  final client = http.Client();
  try {
    final request = http.Request('GET', Uri.parse(url))
      ..headers['User-Agent'] = (userAgent?.isNotEmpty ?? false)
          ? userAgent!
          : 'Mozilla/5.0';
    final response = await client
        .send(request)
        .timeout(const Duration(seconds: 3));
    if (response.statusCode < 200 || response.statusCode >= 300) return false;
    await response.stream.first.timeout(const Duration(seconds: 3));
    return true;
  } catch (_) {
    return false;
  } finally {
    client.close();
  }
}

/// Ficha del canal que se está viendo, debajo del video en computador.
class _NowPlaying extends StatelessWidget {
  const _NowPlaying({required this.channel});
  final Channel channel;

  @override
  Widget build(BuildContext context) {
    final program = channel.currentProgram;
    final category = (channel.genre ?? channel.group ?? '').trim();
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Row(
        children: [
          Container(
            width: 88,
            height: 56,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _line),
            ),
            child: _ChannelLogo(url: channel.logo ?? channel.backdrop),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE50914),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'EN VIVO',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: .5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        channel.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // Solo lo que se sabe de verdad: el programa si hay guía
                // (EPG); si no, la categoría.
                Text(
                  program?.title ?? category,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _muted, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Fila compacta de la guía en computador/tablet: número, logo, nombre y
/// categoría. El canal que se ve queda marcado en verde.
class _WideChannelRow extends StatefulWidget {
  const _WideChannelRow({
    required this.channel,
    required this.number,
    required this.active,
    required this.onTap,
  });
  final Channel channel;
  final int number;
  final bool active;
  final VoidCallback onTap;

  @override
  State<_WideChannelRow> createState() => _WideChannelRowState();
}

class _WideChannelRowState extends State<_WideChannelRow> {
  var _hover = false;

  @override
  Widget build(BuildContext context) {
    final channel = widget.channel;
    final active = widget.active;
    final program = channel.currentProgram;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: active
                  ? _red.withValues(alpha: .12)
                  : (_hover ? const Color(0xFF171C19) : Colors.transparent),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: active ? _red : Colors.transparent),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 28,
                  child: Text(
                    '${widget.number}',
                    style: TextStyle(
                      color: active ? _red : _muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Container(
                  width: 64,
                  height: 40,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: _ChannelLogo(url: channel.logo ?? channel.backdrop),
                ),
                const SizedBox(width: 12),
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
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        program?.title ??
                            (channel.genre ?? channel.group ?? ''),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: _muted, fontSize: 11.5),
                      ),
                    ],
                  ),
                ),
                if (active)
                  const Icon(Icons.equalizer_rounded, color: _red, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
