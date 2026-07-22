part of 'catalog_screen.dart';

/// Inicio de escritorio. Mantiene la lógica del catálogo real y adopta la
/// composición panorámica aprobada en el prototipo: hero de 420 px, sin
/// sinopsis ni flechas, y tarjetas 16:9 pensadas para ratón.
class CatalogDesktopScreen extends StatefulWidget {
  final String initialCategory;
  const CatalogDesktopScreen({super.key, this.initialCategory = 'all'});

  @override
  State<CatalogDesktopScreen> createState() => _CatalogDesktopScreenState();
}

class _CatalogDesktopScreenState extends State<CatalogDesktopScreen>
    with CatalogBaseState {
  @override
  String get _initialCategory => widget.initialCategory;

  @override
  bool get _showLogo => false;

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
  Widget build(BuildContext context) {
    final featured = _heroMovies.isEmpty ? null : _heroMovies.first;
    final image = featured == null
        ? null
        : (featured.backdrop ?? featured.logo);

    return Stack(
      children: [
        Positioned.fill(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 450),
            child: image == null
                ? const ColoredBox(color: AppColors.primaryDark)
                : CachedNetworkImage(
                    key: ValueKey(image),
                    imageUrl: image,
                    fit: BoxFit.cover,
                    memCacheWidth: 1600,
                    errorWidget: (_, _, _) =>
                        const ColoredBox(color: AppColors.primaryDark),
                  ),
          ),
        ),
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Color(0xFF000000),
                  Color(0xE6000000),
                  Color(0x33000000),
                ],
                stops: [0, 0.5, 1],
              ),
            ),
          ),
        ),
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Color(0xFF000000),
                  Color(0x33000000),
                  Color(0xB3000000),
                ],
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: _content(),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget _buildHero() {
    final movies = _heroMovies;
    if (movies.isEmpty) return const SizedBox.shrink();
    final featured = movies.first;

    return SizedBox(
      height: 420,
      child: Align(
        alignment: Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: const Text(
                        'HOURTV ORIGINAL',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    Text(
                      '${_matchOf(featured)}% COINCIDENCIA',
                      style: const TextStyle(
                        color: Color(0xFF34D399),
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  featured.displayName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 48,
                    height: 1,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.4,
                    shadows: [Shadow(color: Colors.black, blurRadius: 16)],
                  ),
                ),
                _billboardMetadata(featured),
                const SizedBox(height: 22),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _heroPlayButton(featured),
                    const SizedBox(width: 12),
                    TvFocusable(
                      onTap: () => _toggleFavorite(featured),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 42),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.48),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.18),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              featured.isFavorite
                                  ? Icons.check_rounded
                                  : Icons.add_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 7),
                            const Text(
                              'Mi Lista',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget _movieRow(String title, List<Channel> items) {
    if (items.isEmpty) return const SizedBox.shrink();
    const cardWidth = 224.0;
    const cardHeight = 126.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Spacer(),
                Text(
                  '${items.length} títulos',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: cardHeight,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              itemCount: items.length > 40 ? 40 : items.length,
              separatorBuilder: (_, _) => const SizedBox(width: 16),
              itemBuilder: (_, index) {
                final content = items[index];
                final image = content.backdrop ?? content.logo;
                return TvFocusable(
                  onTap: () => _openDetails(content, items),
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: cardWidth,
                    height: cardHeight,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ColoredBox(
                            color: AppColors.cardElevated,
                            child: image == null || image.isEmpty
                                ? _posterPh(content)
                                : CachedNetworkImage(
                                    imageUrl: image,
                                    fit: BoxFit.cover,
                                    memCacheWidth: 520,
                                    placeholder: (_, _) => _posterPh(content),
                                    errorWidget: (_, _, _) =>
                                        _posterPh(content),
                                  ),
                          ),
                          const DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [Color(0xE6000000), Color(0x00000000)],
                              ),
                            ),
                          ),
                          Positioned(
                            left: 12,
                            right: 12,
                            bottom: 10,
                            child: Text(
                              content.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
