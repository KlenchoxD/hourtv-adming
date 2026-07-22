part of 'catalog_screen.dart';

/// Inicio para teléfono y tablet (táctil, scroll vertical). Hero cinematográfico
/// con banner rotativo cada 5s. La tablet reutiliza esta misma UI con tarjetas
/// algo más grandes vía `uiScale`; no necesita una pantalla aparte. Comparte
/// datos y filas con [CatalogBaseState]; solo aporta el hero y su rotación.
class CatalogTouchScreen extends StatefulWidget {
  final String initialCategory;
  const CatalogTouchScreen({super.key, this.initialCategory = 'all'});
  @override
  State<CatalogTouchScreen> createState() => _CatalogTouchScreenState();
}

class _CatalogTouchScreenState extends State<CatalogTouchScreen>
    with CatalogBaseState {
  @override
  String get _initialCategory => widget.initialCategory;

  /// Banner rotativo del Inicio (estilo UltraPelis). Es un ValueNotifier para
  /// que la rotación cada 5s reconstruya SOLO el hero, no toda la pantalla.
  Timer? _bannerTimer;
  final ValueNotifier<int> _bannerIdx = ValueNotifier<int>(0);

  @override
  bool get _showLogo => true;

  @override
  void initState() {
    super.initState();
    _bannerTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || _cat == 'series') return;
      final n = _store.movies.where((m) => m.logo != null).length;
      if (n > 1) _bannerIdx.value = (_bannerIdx.value + 1) % n;
    });
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _bannerIdx.dispose();
    super.dispose();
  }

  @override
  Widget _buildHero() {
    final movies = _heroMovies;
    if (movies.isEmpty) return const SizedBox.shrink();
    // Hero cinematográfico (estilo Netflix): backdrop a sangre completa con
    // degradado, título, metadatos y botones. Rota solo cada 5s.
    return ValueListenableBuilder<int>(
      valueListenable: _bannerIdx,
      builder: (context, bannerIdx, _) {
        final f = movies[bannerIdx % movies.length];
        final size = MediaQuery.sizeOf(context);
        final heroH = (size.height *
                (DeviceProfile.isTablet(context) ? 0.5 : 0.54))
            .clamp(320.0, 560.0);
        return GestureDetector(
          onTap: () => _openDetails(f, movies),
          child: SizedBox(
            height: heroH,
            width: double.infinity,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 700),
              switchInCurve: Curves.easeOut,
              child: Stack(
                key: ValueKey(f.tvgId ?? f.url),
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: f.backdrop ?? f.logo!,
                    fit: BoxFit.cover,
                    memCacheWidth: 900,
                    errorWidget: (_, _, _) => Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppColors.accent.withValues(alpha: 0.55),
                            AppColors.cardDark,
                            AppColors.primaryDark,
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Degradado inferior que funde con el fondo (legibilidad).
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          AppColors.primaryDark,
                          AppColors.primaryDark,
                          Colors.transparent,
                        ],
                        stops: [0.0, 0.22, 0.72],
                      ),
                    ),
                  ),
                  // Scrim superior sutil para que el logo/buscador se lean.
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.center,
                        colors: [
                          Colors.black.withValues(alpha: 0.45),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(20, 0, 20, 18 * _s),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          f.displayName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 27 * _s,
                            fontWeight: FontWeight.w900,
                            height: 1.05,
                            letterSpacing: -0.5,
                            shadows: const [
                              Shadow(color: Colors.black87, blurRadius: 12),
                            ],
                          ),
                        ),
                        Align(
                          alignment: Alignment.center,
                          child: _billboardMetadata(f),
                        ),
                        SizedBox(height: 14 * _s),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _heroPlayButton(f),
                            const SizedBox(width: 10),
                            _heroInfoButton(f, movies),
                          ],
                        ),
                        SizedBox(height: 12 * _s),
                        _heroDots(bannerIdx, movies.length),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Botón secundario translúcido "Información" del hero.
  Widget _heroInfoButton(Channel f, List<Channel> ctx) => TvFocusable(
    onTap: () => _openDetails(f, ctx),
    borderRadius: BorderRadius.circular(10),
    child: Container(
      padding: EdgeInsets.symmetric(horizontal: 16 * _s, vertical: 9 * _s),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.info_outline_rounded, color: Colors.white, size: 19 * _s),
          const SizedBox(width: 6),
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

  /// Puntos de rotación del hero (el activo en rojo, estilo carrusel premium).
  Widget _heroDots(int active, int total) {
    final count = total.clamp(0, 7);
    if (count <= 1) return const SizedBox.shrink();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: (active % count) == i ? 18 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: (active % count) == i
                  ? AppColors.accent
                  : Colors.white.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
      ],
    );
  }
}
