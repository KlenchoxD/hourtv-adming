import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_chrome_cast/flutter_chrome_cast.dart';

import '../models/channel.dart';
import '../services/cast_service.dart';
import '../services/content_store.dart';
import '../services/device_type.dart';
import '../services/storage_service.dart';
import 'hourtv_artwork.dart';
import 'hourtv_cast_controls_screen.dart';
import 'hourtv_cast_sheet.dart';
import 'hourtv_focusable.dart';
import 'hourtv_player_screen.dart';
import 'hourtv_parental_gate.dart';

const _red = Color(0xFF00C781);
const _black = Color(0xFF050505);
const _surface = Color(0xFF101412);
const _line = Color(0xFF27302C);
const _muted = Color(0xFFA8ADAB);

/// Compara el reparto con la sinopsis ignorando espacios y puntuación.
/// Algunos proveedores copian el argumento completo en el campo de actores.
bool isDistinctDetailCast(String cast, String? plot) {
  final plotValue = plot?.trim();
  if (plotValue == null || plotValue.isEmpty) return true;
  String normalize(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9áéíóúüñ]+', unicode: true), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return normalize(cast) != normalize(plotValue);
}

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
  bool plotExpanded = false;
  bool castExpanded = false;
  bool castDeviceAvailable = false;
  // Sin esto, un doble-toque rapido en "Reproducir" empuja el reproductor
  // dos veces (el gate de PIN parental es async incluso cuando esta
  // desactivado y devuelve al toque, dejando una ventana breve para el
  // segundo toque).
  bool _opening = false;
  StreamSubscription<List<GoogleCastDevice>>? _castDevicesSub;
  final FocusNode tvFocus = FocusNode();

  Channel get channel => widget.channel;
  ContentStore get store => ContentStore.instance;

  List<Channel> get related {
    // `channel.genre` suele venir como varios generos separados por coma
    // ("Acción, Aventura, Ciencia ficción..."). Antes se comparaba esa
    // cadena completa contra el genero (casi siempre uno solo) de cada otro
    // titulo, asi que solo coincidia si algun otro titulo tenia exactamente
    // los mismos generos combinados: en la practica, "Relacionados" salia en
    // unas fichas si y en otras no, sin ningun criterio visible para el
    // usuario. Ahora se compara genero por genero.
    final genres = (channel.genre ?? '')
        .toLowerCase()
        .split(RegExp(r'[,/]'))
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();
    final others = store.movies.where((item) => item.url != channel.url);
    final byGenre = others.where((item) {
      if (genres.isEmpty) return false;
      final itemGenres = [
        (item.genre ?? '').toLowerCase(),
        ...item.categories.map((value) => value.toLowerCase()),
      ];
      return genres.any(
        (genre) => itemGenres.any((value) => value.contains(genre)),
      );
    });
    // Si no hay ningun otro titulo con un genero en comun, se muestra otro
    // contenido igual: la seccion no debe desaparecer solo porque el genero
    // de esta ficha es poco frecuente en el catalogo.
    final candidates = byGenre.isNotEmpty ? byGenre : others;
    return candidates.take(6).toList();
  }

  @override
  void initState() {
    super.initState();
    liked = StorageService.loadLikedUrls().contains(channel.url);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (DeviceProfile.isTv(context)) tvFocus.requestFocus();
      // Ficha a pantalla completa: sin barra de estado ni de navegacion. Se
      // usa `immersiveSticky` para que reaparezcan con un gesto y se vuelvan
      // a ocultar solas. Solo en movil: en TV y escritorio no aplica.
      if (defaultTargetPlatform == TargetPlatform.android &&
          !DeviceProfile.isTv(context)) {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      }
    });
    _watchCastDevices();
  }

  // El boton de transmitir solo se habilita si de verdad hay algo a lo que
  // transmitir. Antes estaba siempre activo y al pulsarlo no pasaba nada.
  void _watchCastDevices() {
    if (!CastService.instance.isAvailable) return;
    unawaited(CastService.instance.startDiscovery());
    _castDevicesSub = CastService.instance.devicesStream.listen((devices) {
      final available = devices.isNotEmpty;
      if (mounted && available != castDeviceAvailable) {
        setState(() => castDeviceAvailable = available);
      }
    });
  }

  @override
  void dispose() {
    _castDevicesSub?.cancel();
    tvFocus.dispose();
    if (defaultTargetPlatform == TargetPlatform.android) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    super.dispose();
  }

  Future<void> play() async {
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
    if (_opening) return;
    _opening = true;
    try {
      if (!await ensureParentalAccess(context, channel) || !mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              PlayerScreen(channel: channel, allChannels: store.visibleAll),
        ),
      );
    } finally {
      _opening = false;
    }
  }

  Future<void> favorite() async {
    if (widget.preview) return;
    await store.toggleFavorite(channel);
    if (mounted) setState(() {});
  }

  Future<void> toggleLiked() async {
    if (widget.preview) {
      setState(() => liked = !liked);
      return;
    }
    final nowLiked = await StorageService.toggleLiked(channel.url);
    if (mounted) setState(() => liked = nowLiked);
  }

  /// Envia el contenido a un TV por Chromecast/Cast, no comparte texto: el
  /// icono es un cast, asi que su accion real debe ser transmitir, igual
  /// que el boton "Transmitir" del reproductor.
  Future<void> castToDevice() async {
    if (widget.preview) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Conecta una fuente IPTV para transmitir contenido real.',
          ),
        ),
      );
      return;
    }
    // Mismo panel propio que el reproductor: busca, muestra el estado, deja
    // elegir y desconectar, y explica los errores sin salir de la app.
    final streamUrl = channel.url;
    final blocked =
        !CastService.isNetworkUrl(streamUrl) ||
            CastService.contentTypeFor(streamUrl, mediaType: channel.type) ==
                null
        ? 'Este contenido no expone una URL HLS (.m3u8) ni MP4, que son los '
              'únicos formatos que acepta Chromecast.'
        : null;
    final connected = await showCastSheet(
      context,
      title: channel.displayName,
      streamUrl: () => streamUrl,
      posterUrl: channel.backdrop ?? channel.logo,
      mediaType: channel.type,
      blockedReason: blocked,
    );
    if (!mounted || !connected) return;
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CastControlsScreen(title: channel.displayName),
      ),
    );
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

  // Cuando no hay banner horizontal el poster se dibuja completo (contain),
  // asi que la altura reservada solo sirve para dejar franjas negras a los
  // lados. Se reserva menos alto: la caratula sigue viendose entera y el
  // titulo y los botones suben a la parte visible de la pantalla.
  double _heroHeight(BuildContext context, double withBackdrop) =>
      (channel.backdrop?.isNotEmpty ?? false)
      ? withBackdrop
      : 300 + MediaQuery.paddingOf(context).top;

  @override
  Widget build(BuildContext context) {
    if (DeviceProfile.isTv(context)) return tvLayout();
    if (DeviceProfile.isPhone(context)) return phoneLayout();
    if (DeviceProfile.isTablet(context)) return tabletLayout();
    return desktopLayout();
  }

  Widget phoneLayout() {
    // Antes ocupaba .58 de la pantalla (hasta 560px), casi identico al hero
    // del Inicio: la pantalla de detalles parecia una copia de esa misma
    // franja en vez de una vista propia. Se reduce para que se distinga.
    final screen = MediaQuery.sizeOf(context).height;
    final headerHeight = (screen * .42).clamp(280.0, 380.0);
    return Scaffold(
      backgroundColor: _black,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: SizedBox(
              height: headerHeight,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _CinematicBackdrop(channel: channel),
                  // El boton atras va superpuesto DENTRO de la imagen. No se
                  // reserva franja negra para el.
                  _backButton(left: 12, top: 8),
                  // Titulo y metadatos pegados al borde inferior de la
                  // imagen, donde el degradado ya es negro solido.
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 14,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _title(28),
                        const SizedBox(height: 8),
                        _meta(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _actions(phone: true),
                  const SizedBox(height: 20),
                  _description(),
                  _genres(),
                  _castSection(),
                  _creditsSection(),
                  if (related.isNotEmpty) ...[
                    const SizedBox(height: 26),
                    _relatedRow(portrait: true, cardWidth: 112),
                  ],
                  const SizedBox(height: 96),
                ],
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
              height: _heroHeight(context, 360),
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
                                _castSection(),
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
                                _castSection(),
                                const SizedBox(height: 18),
                                _genres(),
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
                        _title(60),
                        const SizedBox(height: 14),
                        _meta(),
                        const SizedBox(height: 16),
                        _description(maxLines: 3, large: true),
                        const SizedBox(height: 12),
                        _castSection(),
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
      // Suma el inset de la barra de estado mas un margen. En modo inmersivo
      // el inset baja a 0, pero `immersiveSticky` reaparece las barras con un
      // gesto: sin un minimo, en ese momento el boton queda encima del reloj.
      top:
          top +
          (MediaQuery.paddingOf(context).top > 12
              ? MediaQuery.paddingOf(context).top + 10
              : 26),
      child: Tooltip(
        message: close ? 'Cerrar' : 'Volver',
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
              child: Icon(
                close ? Icons.close_rounded : Icons.arrow_back_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // height 1.12 (antes .98) y una sombra suave: con .98 las dos lineas se
  // tocaban entre si y el titulo se leia comprimido contra la imagen; la
  // sombra lo despega del fondo cuando queda sobre el backdrop.
  Widget _title(double size) => Text(
    channel.displayName,
    maxLines: 2,
    overflow: TextOverflow.ellipsis,
    style: TextStyle(
      color: Colors.white,
      fontSize: size,
      height: 1.12,
      fontWeight: FontWeight.w900,
      letterSpacing: -.8,
      shadows: const [
        Shadow(color: Color(0xCC000000), blurRadius: 12, offset: Offset(0, 2)),
      ],
    ),
  );

  /// "133 Min" -> "2 h 13 min". Si el texto no trae minutos reconocibles se
  /// devuelve tal cual: es preferible mostrar el dato original que inventar.
  static String? _prettyDuration(String? raw) {
    final value = raw?.trim();
    if (value == null || value.isEmpty) return null;
    final match = RegExp(
      r'^(\d+)\s*(min|m|minutos?)?\.?$',
      caseSensitive: false,
    ).firstMatch(value);
    if (match == null) return value;
    final total = int.tryParse(match.group(1)!);
    if (total == null || total <= 0) return value;
    final hours = total ~/ 60;
    final minutes = total % 60;
    if (hours == 0) return '$minutes min';
    if (minutes == 0) return '$hours h';
    return '$hours h $minutes min';
  }

  /// Fecha de estreno solo si aporta algo mas que el año que ya se muestra.
  String? get _releaseBeyondYear {
    final raw = channel.releaseDate?.trim();
    if (raw == null || raw.length < 10) return null;
    final date = DateTime.tryParse(raw);
    if (date == null) return null;
    const months = [
      'enero',
      'febrero',
      'marzo',
      'abril',
      'mayo',
      'junio',
      'julio',
      'agosto',
      'septiembre',
      'octubre',
      'noviembre',
      'diciembre',
    ];
    return '${date.day} de ${months[date.month - 1]} de ${date.year}';
  }

  // Solo datos que existen de verdad. Se quito el "98% Coincidencia", que
  // estaba escrito a mano en el codigo: la app no calcula ninguna afinidad.
  // Y `rating` se pinta como puntuacion (es la nota 0-10 de TMDB), no dentro
  // de un recuadro de clasificacion por edades: ese dato no existe.
  Widget _meta() {
    final duration = _prettyDuration(channel.duration);
    final rating = channel.rating?.trim();
    final year = channel.year?.trim();
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
      if (year != null && year.isNotEmpty) _metaText(year),
      if (duration != null) _metaText(duration),
    ];
    if (parts.isEmpty) return const SizedBox.shrink();
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

  Widget _metaText(String value) => Text(
    value,
    style: const TextStyle(color: _muted, fontWeight: FontWeight.w500),
  );

  Widget _actions({bool phone = false, bool desktop = false}) {
    final playButton = FilledButton.icon(
      onPressed: play,
      style: FilledButton.styleFrom(
        backgroundColor: desktop ? Colors.white : _red,
        // Texto blanco sobre el verde de marca casi no hacia contraste
        // (se perdia contra el fondo); negro es lo que ya se usa en el
        // resto de la app para texto sobre superficies emerald (el logo,
        // los botones de HourTvButton).
        foregroundColor: Colors.black,
        minimumSize: const Size(158, 52),
        elevation: desktop ? 0 : 4,
        shadowColor: _red.withValues(alpha: .5),
        shape: const StadiumBorder(),
      ),
      icon: const Icon(Icons.play_arrow_rounded),
      label: const Text(
        'REPRODUCIR',
        style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: .3),
      ),
    );

    // En movil "Reproducir" manda: ancho completo. Las demas acciones bajan de
    // jerarquia a iconos pequenos con su etiqueta debajo, para que se entienda
    // que hace cada una (el icono de transmitir no se explicaba solo).
    if (phone) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: 50, child: playButton),
          const SizedBox(height: 16),
          // Cada accion en su propio Expanded: en pantallas angostas (~360dp)
          // las tres etiquetas ("Favorito"/"Me gusta"/"Transmitir") con
          // spaceEvenly desbordaban el Row por su ancho intrinseco.
          Row(
            children: [
              Expanded(
                child: _labelledAction(
                  channel.isFavorite
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  'Favorito',
                  favorite,
                  active: channel.isFavorite,
                ),
              ),
              Expanded(
                child: _labelledAction(
                  Icons.thumb_up_alt_rounded,
                  'Me gusta',
                  () => unawaited(toggleLiked()),
                  active: liked,
                ),
              ),
              Expanded(
                child: _labelledAction(
                  Icons.cast_rounded,
                  'Transmitir',
                  () => unawaited(castToDevice()),
                  // Deshabilitado mientras no se detecte ningun dispositivo.
                  enabled: castDeviceAvailable,
                ),
              ),
            ],
          ),
        ],
      );
    }

    return Row(
      children: [
        playButton,
        const SizedBox(width: 10),
        _roundAction(
          channel.isFavorite
              ? Icons.favorite_rounded
              : Icons.favorite_border_rounded,
          favorite,
          label: channel.isFavorite ? 'Quitar de favoritos' : 'Favorito',
          active: channel.isFavorite,
        ),
        const SizedBox(width: 8),
        _roundAction(
          Icons.thumb_up_alt_rounded,
          () => unawaited(toggleLiked()),
          label: 'Me gusta',
          active: liked,
        ),
        const SizedBox(width: 8),
        _roundAction(
          Icons.cast_rounded,
          () => unawaited(castToDevice()),
          label: 'Transmitir',
        ),
      ],
    );
  }

  // Antes solo cambiaba el color del icono en seco (sin ninguna transicion):
  // se sentia tieso al tocar. Ahora el circulo de fondo anima igual que
  // `_roundAction` (version escritorio), con sombra cuando queda activo.
  Widget _labelledAction(
    IconData icon,
    String label,
    VoidCallback onTap, {
    bool active = false,
    bool enabled = true,
  }) {
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          customBorder: const CircleBorder(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
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
                  child: Icon(
                    icon,
                    color: enabled ? Colors.white : Colors.white24,
                    size: 22,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: enabled ? _muted : Colors.white24,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Rediseño de "Añadir a la lista" / "Me gusta": circular, con relleno rojo
  // y sombra suave cuando esta activo en vez del cuadrado plano de antes
  // (mismo color en foco y sin foco, sin feedback visual de estado real).
  Widget _roundAction(
    IconData icon,
    VoidCallback onTap, {
    required String label,
    bool active = false,
  }) => Tooltip(
    message: label,
    child: Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
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
    ),
  );

  // Una sola sinopsis, la de `plot`. Se acabo el texto de relleno inventado
  // ("Una historia original de HourTV..."): si no hay sinopsis, no hay bloque.
  Widget _description({int? maxLines, bool large = false}) {
    final plot = channel.plot?.trim();
    if (plot == null || plot.isEmpty) return const SizedBox.shrink();
    final style = TextStyle(
      color: Colors.white.withValues(alpha: .82),
      height: 1.6,
      fontSize: large ? 17 : 14,
    );
    // En las vistas que piden un recorte fijo (TV, escritorio) se respeta.
    if (maxLines != null) {
      return Text(
        plot,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
        style: style,
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: plot, style: style),
          maxLines: 5,
          textDirection: Directionality.of(context),
        )..layout(maxWidth: constraints.maxWidth);
        final overflows = painter.didExceedMaxLines;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              plot,
              maxLines: plotExpanded || !overflows ? null : 5,
              overflow: plotExpanded || !overflows
                  ? null
                  : TextOverflow.ellipsis,
              style: style,
            ),
            if (overflows)
              _linkButton(
                plotExpanded ? 'Ver menos' : 'Ver más',
                () => setState(() => plotExpanded = !plotExpanded),
              ),
          ],
        );
      },
    );
  }

  Widget _linkButton(String label, VoidCallback onTap) => Align(
    alignment: Alignment.centerLeft,
    child: TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
      ),
    ),
  );

  Widget _sectionTitle(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 15,
        fontWeight: FontWeight.w900,
      ),
    ),
  );

  // Sin fotos del reparto en el catalogo, un carrusel visual seria una fila de
  // huecos. Se muestra como texto, recortado y con opcion de verlo entero.
  Widget _castSection() {
    final cast = channel.cast?.trim();
    if (cast == null || cast.isEmpty) return const SizedBox.shrink();
    // Algunos proveedores copian la sinopsis completa en el campo de actores:
    // mostrar "Reparto" con el mismo texto que "Sinopsis" no aporta nada.
    if (!isDistinctDetailCast(cast, channel.plot)) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Reparto'),
          Text(
            cast,
            maxLines: castExpanded ? null : 2,
            overflow: castExpanded ? null : TextOverflow.ellipsis,
            style: const TextStyle(color: _muted, fontSize: 13, height: 1.5),
          ),
          if (cast.split(',').length > 4)
            _linkButton(
              castExpanded ? 'Ver menos' : 'Ver reparto completo',
              () => setState(() => castExpanded = !castExpanded),
            ),
        ],
      ),
    );
  }

  // Director, guion y estreno. Las filas sin dato no se pintan.
  Widget _creditsSection() {
    final rows = <(String, String)>[
      if (channel.director?.trim().isNotEmpty ?? false)
        ('Dirección', channel.director!.trim()),
      if (channel.writer?.trim().isNotEmpty ?? false)
        ('Guion', channel.writer!.trim()),
      if (_releaseBeyondYear != null) ('Estreno', _releaseBeyondYear!),
    ];
    if (rows.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Información'),
          for (final (label, value) in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(fontSize: 13, height: 1.4),
                  children: [
                    TextSpan(
                      text: '$label: ',
                      style: const TextStyle(color: _muted),
                    ),
                    TextSpan(
                      text: value,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Categorias internas del panel: sirven para armar las filas del Inicio,
  /// no son generos y no pintan nada en la ficha.
  static const _internalCategories = {
    'tendencias',
    'recomendado',
    'populares',
    'estrenos',
    'antiguas',
    'destacado',
    'featured',
    'live',
    'vod',
    'iptv',
  };

  /// Clave de comparacion sin tildes: el genero llega como "Acción" y la
  /// categoria del panel como "accion". Sin plegar los acentos las dos
  /// sobreviven y el genero sale duplicado.
  static String _fold(String value) {
    const from = 'áàäâãéèëêíìïîóòöôõúùüûñç';
    const to = 'aaaaaeeeeiiiiooooouuuunc';
    final buffer = StringBuffer();
    for (final char in value.toLowerCase().split('')) {
      final index = from.indexOf(char);
      buffer.write(index < 0 ? char : to[index]);
    }
    return buffer.toString().trim();
  }

  Widget _genres() {
    // Solo generos de verdad: se parte `genre` por comas y se descartan las
    // categorias internas y lo que ya aparece repetido.
    final seen = <String>{};
    final values = <String>[];
    for (final raw in [
      ...(channel.genre ?? '').split(RegExp(r'[,/|]')),
      ...channel.categories,
    ]) {
      final value = raw.trim();
      if (value.isEmpty) continue;
      final key = _fold(value);
      if (_internalCategories.contains(key)) continue;
      if (!seen.add(key)) continue;
      values.add(value[0].toUpperCase() + value.substring(1));
    }
    if (values.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Text(
        values.take(6).join(' · '),
        style: const TextStyle(
          color: _muted,
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          height: 1.4,
        ),
      ),
    );
  }

  Widget _relatedRow({required bool portrait, required double cardWidth}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'RELACIONADO',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w900,
            letterSpacing: .3,
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
        'RELACIONADO',
        style: TextStyle(
          color: Colors.white,
          fontSize: 21,
          fontWeight: FontWeight.w900,
          letterSpacing: .3,
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

/// Cabecera de la ficha en movil.
///
/// Con `backdrop` (imagen horizontal real) se pinta a todo el ancho con
/// `cover`, que es lo que se busca. Pero hoy casi ningun titulo del catalogo
/// lo trae, asi que el camino de respaldo es el habitual: se usa el propio
/// poster vertical ampliado, desenfocado y oscurecido como fondo, con el
/// poster nitido y completo delante. Asi la cabecera llena el ancho en vez de
/// dejar dos franjas negras a los lados.
class _CinematicBackdrop extends StatelessWidget {
  const _CinematicBackdrop({required this.channel});
  final Channel channel;

  @override
  Widget build(BuildContext context) {
    final backdrop = channel.backdrop;
    final hasBackdrop = backdrop != null && backdrop.trim().isNotEmpty;
    final poster = channel.logo;
    final url = hasBackdrop ? backdrop : poster;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (url == null || url.trim().isEmpty)
          const ColoredBox(color: _surface)
        else
          // Mismo tratamiento que el hero del Inicio: cover a toda la caja.
          // Antes, sin backdrop horizontal, el poster se mostraba chico y
          // nitido sobre un fondo desenfocado con marco alrededor — parecia
          // la foto de una pagina, no una imagen a pantalla completa.
          // topCenter porque el poster (vertical) recortado al centro corta
          // justo la cara del protagonista.
          CachedNetworkImage(
            imageUrl: url,
            memCacheWidth: 900,
            fit: BoxFit.cover,
            alignment: hasBackdrop ? Alignment.center : Alignment.topCenter,
            errorWidget: (_, _, _) => const ColoredBox(color: _surface),
          ),
        // Degradado inferior: funde la imagen con el negro de la pagina y da
        // fondo legible al titulo.
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
        // Oscurecimiento lateral, para que el texto no compita con la imagen.
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [Color(0x73000000), Color(0x00000000), Color(0x73000000)],
              stops: [0, .32, 1],
            ),
          ),
        ),
      ],
    );
  }
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
    final hasBackdrop =
        channel.backdrop != null && channel.backdrop!.isNotEmpty;
    final url = channel.backdrop ?? channel.logo;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (url != null && url.isNotEmpty)
          hasBackdrop
              // Banner horizontal real: cover, hecho para este ancho.
              ? CachedNetworkImage(
                  imageUrl: url,
                  memCacheWidth: 720,
                  fit: BoxFit.cover,
                  errorWidget: (_, _, _) => const ColoredBox(color: _surface),
                )
              // Sin banner: es el poster VERTICAL. Se muestra completo y
              // proporcionado sobre fondo negro liso. Nada de copia borrosa
              // de relleno a los lados: ensuciaba la caratula y no aportaba.
              : ColoredBox(
                  color: _black,
                  // El poster se baja lo que mide la barra de estado: sin
                  // esto el reloj y los iconos del sistema quedan pintados
                  // encima de la caratula. El banner horizontal si sangra
                  // hasta arriba a proposito, ahi el degradado lo tapa.
                  child: Padding(
                    padding: EdgeInsets.only(
                      top: MediaQuery.paddingOf(context).top,
                    ),
                    child: CachedNetworkImage(
                      imageUrl: url,
                      memCacheWidth: 620,
                      fit: BoxFit.contain,
                      errorWidget: (_, _, _) =>
                          const ColoredBox(color: _surface),
                    ),
                  ),
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
              // Poster completo, sin recortar; el banner horizontal si usa
              // cover (recorte de bordes esperado ahi). En celda vertical se
              // mide la imagen: si el catalogo trae un fotograma apaisado en
              // vez de poster, se pasa a cover para no dejar media tarjeta
              // vacia.
              child: AdaptiveArtwork(
                url: url,
                fit: portrait ? BoxFit.contain : BoxFit.cover,
                adaptive: portrait,
                cacheWidth: 720,
                fallback: const SizedBox.expand(),
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
                  memCacheWidth: 720,
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
