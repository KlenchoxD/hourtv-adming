part of 'catalog_screen.dart';

/// Inicio para Android TV / Google TV (10 pies, control remoto). Diseño
/// rojo/negro de referencia: un backdrop AMBIENTAL a pantalla completa (suave y
/// oscurecido) que cambia según el póster enfocado con el D-pad, con el hero
/// como TEXTO a la izquierda y las filas encima. Comparte datos y filas con
/// [CatalogBaseState]; aquí van el fondo ambiental, el hero y el estado de foco.
class CatalogTvScreen extends StatefulWidget {
  final String initialCategory;
  const CatalogTvScreen({super.key, this.initialCategory = 'all'});
  @override
  State<CatalogTvScreen> createState() => _CatalogTvScreenState();
}

class _CatalogTvScreenState extends State<CatalogTvScreen>
    with CatalogBaseState {
  @override
  String get _initialCategory => widget.initialCategory;

  /// Contenido que define el fondo ambiental y el hero: el último póster
  /// enfocado con D-pad. Null = la primera película destacada.
  Channel? _spotlight;
  Timer? _spotlightDebounce;
  int _spotlightRequest = 0;

  @override
  bool get _showLogo => false;

  @override
  void dispose() {
    _spotlightDebounce?.cancel();
    _spotlightRequest++;
    super.dispose();
  }

  @override
  void _onPosterFocus(Channel channel, bool focused) {
    _spotlightDebounce?.cancel();
    final request = ++_spotlightRequest;
    if (!focused) return;

    if (!identical(_spotlight, channel)) {
      setState(() => _spotlight = channel);
    }

    _spotlightDebounce = Timer(const Duration(milliseconds: 400), () async {
      var changed = await XtreamService.enrichMovieMetadata(channel);
      changed = await TmdbService.enrich(channel) || changed;
      if (!mounted ||
          request != _spotlightRequest ||
          !identical(_spotlight, channel)) {
        return;
      }
      if (changed) setState(() {});
    });
  }

  /// Layout TV: fondo ambiental a sangre completa + contenido (hero texto +
  /// filas) encima. Sin barra superior ni chips: la navegación es el riel.
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: _ambientBackdrop()),
        Positioned.fill(
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.only(left: _contentPad, right: _contentPad),
              child: _content(),
            ),
          ),
        ),
      ],
    );
  }

  /// Fondo ambiental: la imagen del contenido enfocado, oscurecida y en baja
  /// resolución (suave/borrosa de forma barata, sin blur costoso en el TV Box),
  /// con degradados para que el texto de la izquierda se lea a 10 pies.
  Widget _ambientBackdrop() {
    final movies = _heroMovies;
    final f = _spotlight ?? (movies.isEmpty ? null : movies.first);
    final img = f == null ? null : (f.backdrop ?? f.logo);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      child: SizedBox.expand(
        key: ValueKey(img ?? 'none'),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (img != null)
              CachedNetworkImage(
                imageUrl: img,
                fit: BoxFit.cover,
                memCacheWidth: 640,
                color: Colors.black.withValues(alpha: 0.5),
                colorBlendMode: BlendMode.darken,
                fadeInDuration: const Duration(milliseconds: 400),
                errorWidget: (_, _, _) => const ColoredBox(
                  color: AppColors.primaryDark,
                ),
              ),
            // Degradado horizontal: negro sólido a la izquierda (legibilidad).
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Color(0xFF000000),
                    Color(0xD9000000),
                    Color(0x55000000),
                  ],
                  stops: [0.0, 0.42, 1.0],
                ),
              ),
            ),
            // Degradado vertical: funde con el fondo arriba y abajo.
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Color(0xFF000000),
                    Color(0x00000000),
                    Color(0x99000000),
                  ],
                  stops: [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Hero de TEXTO (la imagen ya está en el fondo ambiental): badge, título
  /// grande, metadata y botones, alineado a la izquierda.
  @override
  Widget _buildHero() {
    final movies = _heroMovies;
    if (movies.isEmpty) return const SizedBox.shrink();
    final f = _spotlight ?? movies.first;
    final width = MediaQuery.sizeOf(context).width;
    return Container(
      height: MediaQuery.sizeOf(context).height * 0.5,
      padding: const EdgeInsets.only(left: 14, top: 24, bottom: 8),
      alignment: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _heroBadge(),
          const SizedBox(height: 14),
          SizedBox(
            width: width * 0.6,
            child: Text(
              f.displayName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 46,
                fontWeight: FontWeight.w900,
                height: 1.03,
                letterSpacing: -1,
                shadows: [Shadow(color: Colors.black87, blurRadius: 16)],
              ),
            ),
          ),
          _billboardMetadata(f),
          if (f.plot?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: width * 0.5,
              child: Text(
                f.plot!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13 * _s,
                  height: 1.35,
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              _heroPlayButton(f),
              const SizedBox(width: 12),
              _heroInfoButtonTv(f),
            ],
          ),
        ],
      ),
    );
  }

  /// Botón secundario translúcido "Información" del hero (abre el detalle).
  Widget _heroInfoButtonTv(Channel f) => TvFocusable(
    onTap: () => _openDetails(f, _store.movies),
    borderRadius: BorderRadius.circular(10),
    child: Container(
      padding: EdgeInsets.symmetric(horizontal: 18 * _s, vertical: 9 * _s),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.info_outline_rounded, color: Colors.white, size: 20 * _s),
          const SizedBox(width: 7),
          Text(
            'Información',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14 * _s,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _heroBadge() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: AppColors.accent,
      borderRadius: BorderRadius.circular(6),
      boxShadow: [
        BoxShadow(
          color: AppColors.accent.withValues(alpha: 0.35),
          blurRadius: 12,
        ),
      ],
    ),
    child: Text(
      'DESTACADA',
      style: TextStyle(
        color: Colors.white,
        fontSize: 11 * _s,
        fontWeight: FontWeight.w900,
        letterSpacing: 1,
      ),
    ),
  );
}
