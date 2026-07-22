part of 'catalog_screen.dart';

/// Inicio táctil con dos composiciones deliberadamente distintas:
/// - teléfono: portada vertical compacta tipo Netflix;
/// - tablet: banner horizontal contenido, alineado con el rail lateral.
///
/// Los datos, filas y acciones reales siguen viviendo en [CatalogBaseState].
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

  @override
  bool get _showLogo => DeviceProfile.isPhone(context);

  int _matchOf(Channel content) {
    final match = RegExp(r'\d+(?:[.,]\d+)?').firstMatch(content.rating ?? '');
    final rating =
        double.tryParse(match?.group(0)?.replaceAll(',', '.') ?? '') ?? 0;
    return rating <= 0 ? 98 : (60 + rating / 10 * 39).clamp(60, 99).round();
  }

  Future<void> _toggleFavorite(Channel content) async {
    await _store.toggleFavorite(content);
    if (mounted) setState(() {});
  }

  @override
  Widget _buildHero() {
    final movies = _heroMovies;
    if (movies.isEmpty) return const SizedBox.shrink();
    final featured = movies.first;
    return DeviceProfile.isTablet(context)
        ? _tabletHero(featured, movies)
        : _phoneHero(featured, movies);
  }

  Widget _phoneHero(Channel featured, List<Channel> movies) {
    final viewport = MediaQuery.sizeOf(context);
    final height = (viewport.height * 0.58).clamp(320.0, 500.0);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: GestureDetector(
            onTap: () => _openDetails(featured, movies),
            child: Container(
              height: height,
              width: double.infinity,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: AppColors.cardElevated,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x66000000),
                    blurRadius: 28,
                    offset: Offset(0, 14),
                  ),
                ],
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: featured.logo!,
                    fit: BoxFit.cover,
                    memCacheWidth: 720,
                    placeholder: (_, _) => _posterPh(featured),
                    errorWidget: (_, _, _) => _posterPh(featured),
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Color(0xFF000000),
                          Color(0xB3000000),
                          Color(0x00000000),
                        ],
                        stops: [0, 0.42, 0.78],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            _badge('ORIGINAL'),
                            Text(
                              '${_matchOf(featured)}% Coincidencia',
                              style: const TextStyle(
                                color: Color(0xFF34D399),
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          featured.displayName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 30,
                            height: 1.02,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.8,
                            shadows: [
                              Shadow(color: Colors.black, blurRadius: 12),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        _genres(featured, centered: true),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(child: _playButton(featured, 'Ver ahora')),
                            const SizedBox(width: 12),
                            _favoriteButton(featured),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _tabletHero(Channel featured, List<Channel> movies) {
    final image = featured.backdrop ?? featured.logo!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 4),
      child: GestureDetector(
        onTap: () => _openDetails(featured, movies),
        child: Container(
          height: 280,
          width: double.infinity,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppColors.cardElevated,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: image,
                fit: BoxFit.cover,
                memCacheWidth: 1200,
                placeholder: (_, _) => _posterPh(featured),
                errorWidget: (_, _, _) => _posterPh(featured),
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Color(0xF2000000),
                      Color(0xA6000000),
                      Color(0x1A000000),
                    ],
                    stops: [0, 0.5, 1],
                  ),
                ),
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Color(0xA6000000), Color(0x00000000)],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(32, 26, 24, 28),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 500),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            _badge('HOURTV ORIGINAL'),
                            Text(
                              '${_matchOf(featured)}% de Coincidencia',
                              style: const TextStyle(
                                color: Color(0xFF34D399),
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(
                          featured.displayName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 34,
                            height: 1,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1,
                          ),
                        ),
                        _billboardMetadata(featured),
                        const SizedBox(height: 18),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _playButton(featured, 'Reproducir ahora'),
                            const SizedBox(width: 12),
                            _favoriteButton(featured),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _badge(String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: AppColors.accent,
      borderRadius: BorderRadius.circular(5),
    ),
    child: Text(
      label,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 10,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.8,
      ),
    ),
  );

  Widget _genres(Channel content, {required bool centered}) {
    final values = (content.genre ?? content.category ?? '')
        .split(RegExp(r'[,/|]'))
        .map((genre) => genre.trim())
        .where((genre) => genre.isNotEmpty)
        .take(3)
        .join('  •  ');
    if (values.isEmpty) return const SizedBox.shrink();
    return Text(
      values,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: centered ? TextAlign.center : TextAlign.start,
      style: const TextStyle(
        color: Color(0xFFD4D4D8),
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _playButton(Channel content, String label) => TvFocusable(
    onTap: () => _play(content, _store.movies),
    borderRadius: BorderRadius.circular(9),
    child: Container(
      constraints: const BoxConstraints(minHeight: 44),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
      decoration: BoxDecoration(
        color: AppColors.accent,
        borderRadius: BorderRadius.circular(9),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.32),
            blurRadius: 16,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 21),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _favoriteButton(Channel content) => TvFocusable(
    onTap: () => _toggleFavorite(content),
    borderRadius: BorderRadius.circular(9),
    child: Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Icon(
        content.isFavorite ? Icons.check_rounded : Icons.add_rounded,
        color: content.isFavorite ? AppColors.accentLight : Colors.white,
        size: 23,
      ),
    ),
  );
}
