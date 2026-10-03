import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/channel.dart';
import '../services/catalog/catalog_detail_navigator.dart';
import '../services/playback_progress.dart';
import '../services/remote_playback.dart';
import '../services/catalog/hero_tag_helper.dart';
import '../services/content_store.dart';
import '../services/device_type.dart';
import '../services/likes_service.dart';
import '../services/recommendations/related_content_engine.dart';
import '../services/storage_service.dart';
import 'hourtv_artwork.dart';
import 'hourtv_web_related.dart';
import 'hourtv_web_detail_overview.dart';
import '../mobile_ui/hourtv_mobile_components.dart' show HourTvArtwork;
import 'hourtv_detail_parts.dart';
import 'hourtv_focusable.dart';
import 'hourtv_play_button.dart';
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
    this.fromContinueWatching = false,
    this.heroScope,
  });
  final Channel channel;
  final bool preview;
  final String? heroScope;

  /// Entrada desde la fila "Continuar viendo": el botón REPRODUCIR reanuda
  /// la posición guardada directamente, sin volver a preguntar.
  final bool fromContinueWatching;

  @override
  State<HourTvDetailPage> createState() => _HourTvDetailPageState();
}

class _HourTvDetailPageState extends State<HourTvDetailPage> {
  bool liked = false;

  /// Total global de Me gusta (todos los usuarios); null = aún no se sabe.
  int? likeCount;
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
  final FocusNode tvFocus = FocusNode();

  Channel get channel => widget.channel;
  ContentStore get store => ContentStore.instance;

  // Recorre todo el catálogo (~130 ms en un Moto G24): se calcula una vez y
  // al terminar la animación de entrada, no en el primer frame de la ficha.
  List<Channel> related = const [];

  void _loadRelatedAfterTransition() {
    Future<void> load() async {
      final engine = RelatedContentEngine.instance;
      final candidates = store.movies;
      await engine.warmUp(candidates);
      if (!mounted) return;
      setState(() {
        related = engine.getRelated(
          target: channel,
          candidates: candidates,
          isKidsProfile: StorageService.activeProfileIsKids,
          limit: 6,
        );
      });
    }

    final animation = ModalRoute.of(context)?.animation;
    if (animation == null || animation.isCompleted) {
      load();
      return;
    }
    void onStatus(AnimationStatus status) {
      if (status != AnimationStatus.completed) return;
      animation.removeStatusListener(onStatus);
      load();
    }

    animation.addStatusListener(onStatus);
  }

  @override
  void initState() {
    super.initState();
    liked = widget.preview ? false : LikesService.isLiked(channel);
    if (!widget.preview) {
      unawaited(
        LikesService.count(channel).then((count) {
          if (mounted && count != null) setState(() => likeCount = count);
        }),
      );
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadRelatedAfterTransition();
      if (DeviceProfile.isTv(context)) tvFocus.requestFocus();
      // Ficha a pantalla completa: sin barra de estado ni de navegacion. Se
      // usa `immersiveSticky` para que reaparezcan con un gesto y se vuelvan
      // a ocultar solas. Solo en movil: en TV y escritorio no aplica.
      if (defaultTargetPlatform == TargetPlatform.android &&
          !DeviceProfile.isTv(context)) {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      }
    });
    RemotePlayback.active.addListener(_onCastChanged);
  }

  void _onCastChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    RemotePlayback.active.removeListener(_onCastChanged);
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
    if (channel.url.startsWith('catalog://')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Error: No se pudo obtener una fuente reproducible válida.',
          ),
        ),
      );
      return;
    }
    if (_opening) return;
    _opening = true;
    try {
      if (!await ensureParentalAccess(context, channel) || !mounted) return;
      // Las tarjetas paginadas de Drift llegan aquí con una URL `catalog://…`;
      // CatalogDetailNavigator las hidrata y esta ficha ya tiene la fuente
      // real. Reconciliar la cola por URL solamente no encuentra esa entidad,
      // por lo que PlayerScreen caía silenciosamente en el índice 0 (Viuda
      // Negra). El ID estable identifica la película aunque su URL haya sido
      // hidratada o coincida con la de otro título.
      final allChannels = List<Channel>.of(store.visibleAll);
      final titleId = channel.stableTitleId;
      var index = allChannels.indexOf(channel);
      if (index < 0 && titleId != null && titleId.isNotEmpty) {
        index = allChannels.indexWhere((item) => item.stableTitleId == titleId);
      }
      if (index < 0 && channel.url.isNotEmpty) {
        index = allChannels.indexWhere((item) => item.url == channel.url);
      }
      if (index >= 0) {
        // Usa la versión hidratada, no el placeholder catalog:// del listado.
        allChannels[index] = channel;
      } else {
        // No permitas que una selección ausente en la cola termine abriendo
        // otro título por el fallback del reproductor al primer elemento.
        allChannels.insert(0, channel);
        index = 0;
      }
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PlayerScreen(
            channel: channel,
            allChannels: allChannels,
            initialIndex: index,
            // "Continuar viendo" o el botón "Continuar desde…" reanudan
            // directo; sin progreso guardado no hay nada que reanudar.
            resumePlayback: widget.fromContinueWatching || _resume != null,
          ),
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

  /// "Me gusta" o "12 Me gusta" (total de todos los usuarios).
  String get _likeLabel {
    final count = likeCount;
    if (count == null || count == 0) return 'Me gusta';
    return '${LikesService.format(count)} Me gusta';
  }

  Future<void> toggleLiked() async {
    if (widget.preview) {
      setState(() => liked = !liked);
      return;
    }
    // Al instante en pantalla; el total real se confirma con el servidor.
    final wasLiked = liked;
    setState(() {
      liked = !wasLiked;
      if (likeCount != null) {
        likeCount = (likeCount! + (wasLiked ? -1 : 1)).clamp(0, 1 << 31);
      }
    });
    final nowLiked = await LikesService.toggle(channel);
    final confirmed = await LikesService.count(channel);
    if (!mounted) return;
    setState(() {
      liked = nowLiked;
      if (confirmed != null) likeCount = confirmed;
    });
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
    await hourTvCastChannel(context, channel);
    if (mounted) setState(() {});
  }

  void openRelated(Channel item) {
    Navigator.of(context).pushReplacement(
      CatalogDetailNavigator.instantRoute(
        (_) => HourTvDetailPage(channel: item, preview: false),
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
    if (kIsWeb) return webLayout();
    if (DeviceProfile.isTv(context)) return tvLayout();
    if (DeviceProfile.isPhone(context)) return phoneLayout();
    if (DeviceProfile.isTablet(context)) return tabletLayout();
    return desktopLayout();
  }

  Widget phoneLayout() {
    // Antes ocupaba .58 de la pantalla (hasta 560px), casi identico al hero
    // del Inicio: la pantalla de detalles parecia una copia de esa misma
    // franja en vez de una vista propia. Se reduce para que se distinga.
    return Scaffold(
      backgroundColor: _black,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: HourTvDetailPhoneHeader(
              title: channel.displayName,
              meta: _meta(),
              backdropUrl: channel.backdrop,
              posterUrl: _heroPosterUrl,
              poster: _heroPosterUrl == null ? null : _heroPoster(),
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
                  HourTvDetailInfo(
                    plot: channel.plot,
                    director: channel.director,
                    writer: channel.writer,
                    genre: channel.genre,
                    releaseDate: channel.releaseDate,
                    year: channel.year,
                    rating: channel.rating,
                    duration: hourTvPrettyDuration(channel.duration),
                  ),
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

  // Poster vertical chico superpuesto al backdrop del hero de movil (esquina
  // inferior izquierda), 2:3, esquinas redondeadas. Si el canal no trae
  // poster (channel.logo), no ocupa espacio: el titulo usa el ancho completo.
  String? get _heroPosterUrl {
    final logo = channel.logo;
    return (logo != null && logo.trim().isNotEmpty) ? logo : null;
  }

  Widget _heroPoster() {
    final url = _heroPosterUrl;
    if (url == null) return const SizedBox.shrink();
    final imageWidget = ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: CachedNetworkImage(
        fadeInDuration: Duration.zero,
        fadeOutDuration: Duration.zero,
        imageUrl: url,
        width: 72,
        height: 108,
        fit: BoxFit.cover,
        errorWidget: (_, _, _) => const SizedBox.shrink(),
      ),
    );
    if (widget.heroScope != null) {
      return Hero(
        tag: makeHeroTag(
          contextScope: widget.heroScope!,
          id: channel.stableTitleId ?? channel.url,
        ),
        child: imageWidget,
      );
    }
    return imageWidget;
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
                      child: hourTvWideHeroWithPoster(
                        posterUrl: _heroPosterUrl,
                        width: 110,
                        info: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _title(42),
                            const SizedBox(height: 10),
                            _meta(),
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
                constraints: const BoxConstraints(maxWidth: 1440),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 60),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _actions(),
                      const SizedBox(height: 28),
                      _informationPanel(compact: true),
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
                        constraints: const BoxConstraints(maxWidth: 900),
                        child: hourTvWideHeroWithPoster(
                          posterUrl: _heroPosterUrl,
                          info: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
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
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1800),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    kIsWeb ? 32 : 20,
                    38,
                    kIsWeb ? 32 : 20,
                    70,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _informationPanel(compact: false),
                      if (related.isNotEmpty) ...[
                        const SizedBox(height: 40),
                        _relatedGrid(columns: 6, portrait: true),
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

  Widget webLayout() => Scaffold(
    backgroundColor: _black,
    body: Stack(
      children: [
        Positioned.fill(
          child: Stack(
            fit: StackFit.expand,
            children: [
              if ((channel.backdrop ?? channel.logo)?.isNotEmpty == true)
                HourTvArtwork(url: (channel.backdrop ?? channel.logo)!),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xB3000000), Color(0xD0000000), _black],
                  ),
                ),
              ),
            ],
          ),
        ),
        SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              HourTvWebDetailOverview(
                channel: channel,
                actions: _actions(desktop: true),
              ),
              if (related.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(32, 0, 32, 60),
                  child: _relatedGrid(columns: 6, portrait: true),
                ),
            ],
          ),
        ),
      ],
    ),
  );

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
                              _resume == null
                                  ? 'Reproducir'
                                  : 'Continuar desde '
                                        '${formatResumeClock(_resume!.positionMs)}',
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

  /// Avance guardado (para "Continuar desde X"); null si no hay.
  ResumeOffer? get _resume =>
      widget.preview ? null : resumeOfferFor(channel, autoResume: true);

  String get _playLabel => _resume == null ? 'Reproducir' : 'Continuar';

  /// Barra "Vas en X · quedan Y min" bajo Continuar; null sin avance.
  Widget? get _resumeProgress {
    if (_resume == null) return null;
    final saved = PlaybackProgress.load(channel);
    if (saved == null || saved.durationMs <= 0) return null;
    final left = ((saved.durationMs - saved.positionMs) / 60000).ceil();
    return HourTvResumeProgress(
      fraction: saved.fraction,
      label: left > 0 ? 'Quedan $left min' : 'Casi terminada',
    );
  }

  /// "Desde el inicio": borra el avance (como elegir "Desde el inicio" en
  /// el aviso del reproductor) y reproduce desde 0.
  Future<void> startOver() async {
    final saved = PlaybackProgress.load(channel);
    if (saved != null && saved.durationMs > 0) {
      await PlaybackProgress.save(
        channel,
        positionMs: 0,
        durationMs: saved.durationMs,
      );
    }
    if (!mounted) return;
    setState(() {});
    await play();
  }

  Widget _actions({bool phone = false, bool desktop = false}) {
    final resuming = _resume != null;
    final progress = _resumeProgress;
    final playButton = HourTvPlayButton(
      label: _playLabel,
      onPressed: play,
      large: !phone,
    );
    final startOverButton = HourTvPlayButton(
      label: 'Desde el inicio',
      icon: Icons.replay_rounded,
      secondary: true,
      large: !phone,
      onPressed: () => unawaited(startOver()),
    );

    // En movil "Reproducir" manda: ancho completo. Las demas acciones bajan de
    // jerarquia a iconos pequenos con su etiqueta debajo, para que se entienda
    // que hace cada una (el icono de transmitir no se explicaba solo).
    if (phone) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          playButton,
          if (progress != null) ...[const SizedBox(height: 10), progress],
          if (resuming) ...[const SizedBox(height: 10), startOverButton],
          const SizedBox(height: 18),
          HourTvDetailActionBoxes(
            inList: channel.isFavorite,
            onList: favorite,
            liked: liked,
            likeLabel: _likeLabel,
            onLike: () => unawaited(toggleLiked()),
            onCast: kIsWeb ? null : () => unawaited(castToDevice()),
          ),
        ],
      );
    }

    final buttons = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 240),
            child: playButton,
          ),
        ),
        if (resuming) ...[
          const SizedBox(width: 10),
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 240),
              child: startOverButton,
            ),
          ),
        ],
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
          label: _likeLabel,
          active: liked,
        ),
        if (!kIsWeb) ...[
          const SizedBox(width: 8),
          _roundAction(
            (RemotePlayback.active.value != null)
                ? Icons.cast_connected_rounded
                : Icons.cast_rounded,
            () => unawaited(castToDevice()),
            label: (RemotePlayback.active.value != null)
                ? 'Conectado'
                : 'Transmitir',
            active: (RemotePlayback.active.value != null),
          ),
        ],
      ],
    );
    if (progress == null) return buttons;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buttons,
        const SizedBox(height: 12),
        SizedBox(width: 380, child: progress),
      ],
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

  Widget _infoHeading(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      children: [
        Container(
          width: 18,
          height: 2,
          decoration: BoxDecoration(
            color: _red,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 9),
        Text(
          text.toUpperCase(),
          style: const TextStyle(
            color: _muted,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.15,
          ),
        ),
      ],
    ),
  );

  Widget _informationPanel({required bool compact}) {
    final plot = channel.plot?.trim();
    final hasPlot = plot != null && plot.isNotEmpty;
    final cast = channel.cast?.trim();
    final hasCast =
        cast != null &&
        cast.isNotEmpty &&
        isDistinctDetailCast(cast, channel.plot);
    final hasGenres = _genreNames().isNotEmpty;
    if (!hasPlot && !hasCast && !hasGenres) return const SizedBox.shrink();

    final details = <Widget>[];
    if (hasCast) details.add(_castSection(compact: true));
    if (hasGenres) {
      if (details.isNotEmpty) details.add(const SizedBox(height: 22));
      details.add(_genres(compact: true));
    }
    final detailsColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: details,
    );
    final description = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [_infoHeading('Sinopsis'), _description(large: true)],
    );

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(
        kIsWeb ? (compact ? 24 : 32) : (compact ? 20 : 24),
      ),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _line.withValues(alpha: .8)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stack = constraints.maxWidth < (compact ? 680 : 760);
          if (!hasPlot) return detailsColumn;
          if (details.isEmpty) return description;

          if (stack) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                description,
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(top: 22),
                  padding: const EdgeInsets.only(top: 20),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(color: _line.withValues(alpha: .8)),
                    ),
                  ),
                  child: detailsColumn,
                ),
              ],
            );
          }

          final dividerSpace = compact ? 24.0 : 34.0;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 2, child: description),
              SizedBox(width: dividerSpace),
              Expanded(
                child: Container(
                  padding: EdgeInsets.only(left: dividerSpace),
                  decoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(color: _line.withValues(alpha: .8)),
                    ),
                  ),
                  child: detailsColumn,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

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
  Widget _castSection({bool compact = false}) {
    final cast = channel.cast?.trim();
    if (cast == null || cast.isEmpty) return const SizedBox.shrink();
    // Algunos proveedores copian la sinopsis completa en el campo de actores:
    // mostrar "Reparto" con el mismo texto que "Sinopsis" no aporta nada.
    if (!isDistinctDetailCast(cast, channel.plot)) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: EdgeInsets.only(top: compact ? 0 : 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          compact ? _infoHeading('Reparto') : _sectionTitle('Reparto'),
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

  List<String> _genreNames() {
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
    return values.take(6).toList(growable: false);
  }

  Widget _genres({bool compact = false}) {
    final values = _genreNames();
    if (values.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(top: compact ? 0 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          compact ? _infoHeading('Géneros') : _sectionTitle('Géneros'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final value in values)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF171D1A),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: _line),
                  ),
                  child: Text(
                    value,
                    style: const TextStyle(
                      color: _muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _relatedRow({required bool portrait, required double cardWidth}) {
    if (kIsWeb) return HourTvWebRelated(channels: related, onOpen: openRelated);
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

  Widget _relatedGrid({required int columns, required bool portrait}) => kIsWeb
      ? HourTvWebRelated(channels: related, onOpen: openRelated)
      : Column(
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
                  fadeInDuration: Duration.zero,
                  fadeOutDuration: Duration.zero,
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
                      fadeInDuration: Duration.zero,
                      fadeOutDuration: Duration.zero,
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
                  fadeInDuration: Duration.zero,
                  fadeOutDuration: Duration.zero,
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
