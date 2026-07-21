part of 'catalog_screen.dart';

/// Inicio para Android TV / Google TV (10 pies, control remoto). El billboard
/// superior sigue al póster enfocado con el D-pad (estilo Netflix/Google TV) y
/// se muestra como una tarjeta contenida con esquinas redondeadas. Comparte
/// datos y filas con [CatalogBaseState]; solo aporta hero y estado de foco.
class CatalogTvScreen extends StatefulWidget {
  const CatalogTvScreen({super.key});
  @override
  State<CatalogTvScreen> createState() => _CatalogTvScreenState();
}

class _CatalogTvScreenState extends State<CatalogTvScreen>
    with CatalogBaseState {
  /// Contenido que muestra el billboard: el último póster enfocado con D-pad.
  /// Null = la primera película destacada.
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

  @override
  Widget _buildHero() {
    final movies = _heroMovies;
    if (movies.isEmpty) return const SizedBox.shrink();
    return _tvBillboard(_spotlight ?? movies.first);
  }

  /// Banner destacado estilo Google TV Home: NO va a sangre completa. Es una
  /// tarjeta con esquinas redondeadas y aire alrededor (padding), con la imagen
  /// del contenido enfocado, degradado para legibilidad y el texto a la
  /// izquierda. Cambia al mover el foco por los pósters.
  Widget _tvBillboard(Channel f) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 10, 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.54,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if ((f.backdrop ?? f.logo) != null)
                CachedNetworkImage(
                  imageUrl: (f.backdrop ?? f.logo)!,
                  fit: BoxFit.cover,
                  memCacheWidth: 1100,
                  fadeInDuration: const Duration(milliseconds: 220),
                  errorWidget: (_, _, _) => const SizedBox(),
                ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      AppColors.primaryDark,
                      AppColors.primaryDark,
                      Colors.transparent,
                    ],
                    stops: [0.0, 0.40, 0.80],
                  ),
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      AppColors.primaryDark,
                      AppColors.primaryDark.withValues(alpha: 0.0),
                    ],
                    stops: const [0.0, 0.5],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(30, 12, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _heroBadge(),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: MediaQuery.sizeOf(context).width * 0.45,
                      child: Text(
                        f.displayName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                          height: 1.1,
                        ),
                      ),
                    ),
                    _billboardMetadata(f),
                    if (f.plot?.trim().isNotEmpty == true) ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        width: MediaQuery.sizeOf(context).width * 0.45,
                        child: Text(
                          f.plot!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12.5 * _s,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    _heroPlayButton(f),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _heroBadge() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: AppColors.accent,
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      'DESTACADA',
      style: TextStyle(
        color: Colors.white,
        fontSize: 10 * _s,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.5,
      ),
    ),
  );
}
