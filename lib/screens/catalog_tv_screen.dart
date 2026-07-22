part of 'catalog_screen.dart';

/// Inicio para Android TV / Google TV, réplica del prototipo rojo/negro
/// (hourtv_rojo_negro_13, `TvView.tsx`): backdrop ambiental borroso a pantalla
/// completa que sigue al foco, hero de texto a la izquierda (badge + línea de
/// coincidencia + meta + botones que se vuelven blancos al enfocar) y filas
/// horizontales cuyas tarjetas escalan con borde/glow rojo y muestran una
/// etiqueta al enfocar; las filas no enfocadas se atenúan.
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

  // Contenido enfocado que alimenta el fondo ambiental y el hero.
  Channel? _spotlight;
  // Tarjeta enfocada (para mostrar su etiqueta) y fila enfocada (para atenuar
  // las demás). -1 = ninguna (foco en hero o riel).
  Channel? _focusedCard;
  int _focusedRow = -1;
  Timer? _spotlightDebounce;
  int _spotlightRequest = 0;

  static const double _cardW = 160;
  static const double _cardH = 240;
  static const double _labelH = 56;

  @override
  bool get _showLogo => false;

  @override
  void dispose() {
    _spotlightDebounce?.cancel();
    _spotlightRequest++;
    super.dispose();
  }

  double _ratingOf(Channel c) {
    final m = RegExp(r'\d+(?:[.,]\d+)?').firstMatch(c.rating ?? '');
    return double.tryParse(m?.group(0)?.replaceAll(',', '.') ?? '') ?? 0;
  }

  /// % de "Coincidencia" sintetizado desde el rating (el catálogo real no trae
  /// match score); replica la línea verde del prototipo con números plausibles.
  int _matchOf(Channel c) {
    final r = _ratingOf(c);
    if (r <= 0) return 90;
    return (60 + r / 10 * 39).clamp(60, 99).round();
  }

  void _onCardFocus(Channel ch, int rowIdx, bool focused) {
    if (focused) {
      if (mounted) {
        setState(() {
          _focusedCard = ch;
          _focusedRow = rowIdx;
        });
      }
      _onPosterFocus(ch, true);
    } else if (identical(_focusedCard, ch)) {
      if (mounted) {
        setState(() {
          _focusedCard = null;
          _focusedRow = -1;
        });
      }
    }
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

  Future<void> _toggleFavorite(Channel f) async {
    await _store.toggleFavorite(f);
    if (mounted) setState(() {});
  }

  // ============================ BUILD ============================

  @override
  Widget build(BuildContext context) {
    final movies = _store.movies;
    final noContent = movies.isEmpty && _store.series.isEmpty;
    return Stack(
      children: [
        Positioned.fill(child: _ambientBackdrop()),
        Positioned.fill(
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.only(left: _contentPad, right: _contentPad),
              child: noContent
                  ? (_vodLoading
                        ? _loading('Cargando catálogo...')
                        : _vodEmpty('contenido'))
                  : _tvContent(),
            ),
          ),
        ),
      ],
    );
  }

  /// Fondo ambiental: imagen del contenido enfocado, borrosa (blur real) y muy
  /// tenue, con degradados para legibilidad — como el `absolute inset-0` del
  /// prototipo (`blur-sm opacity-25`).
  Widget _ambientBackdrop() {
    final movies = _heroMovies;
    final f = _spotlight ?? (movies.isEmpty ? null : movies.first);
    final img = f == null ? null : (f.backdrop ?? f.logo);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 550),
      child: SizedBox.expand(
        key: ValueKey(img ?? 'none'),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (img != null)
              ImageFiltered(
                imageFilter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Opacity(
                  opacity: 0.32,
                  child: CachedNetworkImage(
                    imageUrl: img,
                    fit: BoxFit.cover,
                    memCacheWidth: 480,
                    fadeInDuration: const Duration(milliseconds: 400),
                    errorWidget: (_, _, _) => const SizedBox(),
                  ),
                ),
              ),
            // Degradado horizontal (izquierda sólida para el texto).
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Color(0xFF000000),
                    Color(0xD9000000),
                    Color(0x66000000),
                  ],
                  stops: [0.0, 0.45, 1.0],
                ),
              ),
            ),
            // Degradado vertical (funde arriba y abajo).
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Color(0xFF000000),
                    Color(0x00000000),
                    Color(0xBF000000),
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

  Widget _tvContent() {
    return ListView(
      padding: const EdgeInsets.only(bottom: 30),
      children: [
        _buildHero(),
        for (var i = 0; i < _rows.length; i++)
          _tvRow(i, _rows[i].title, _rows[i].items, _rows[i].originals),
      ],
    );
  }

  // ============================ HERO ============================

  @override
  Widget _buildHero() {
    final movies = _heroMovies;
    if (movies.isEmpty) return const SizedBox.shrink();
    final f = _spotlight ?? movies.first;
    final width = MediaQuery.sizeOf(context).width;
    final genres = (f.genre ?? f.category ?? '')
        .split(RegExp(r'[,/|]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .take(2)
        .join(' • ');
    final year = f.year?.trim();
    final duration = f.duration?.trim();
    final rating = f.rating?.trim();
    final fav = f.isFavorite;
    return Container(
      constraints: BoxConstraints(minHeight: MediaQuery.sizeOf(context).height * 0.5),
      padding: const EdgeInsets.only(left: 14, top: 30, bottom: 20),
      alignment: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _heroBadge('EXCLUSIVO DE HOURTV'),
              const SizedBox(width: 14),
              Text(
                '${_matchOf(f)}% COINCIDENCIA • HD',
                style: TextStyle(
                  color: const Color(0xFF34D399),
                  fontSize: 13 * _s,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: width * 0.62,
            child: Text(
              f.displayName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 54,
                fontWeight: FontWeight.w900,
                height: 1.0,
                letterSpacing: -1.5,
                shadows: [Shadow(color: Colors.black87, blurRadius: 16)],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              if (year?.isNotEmpty == true) ...[
                _metaText(year!),
                _metaDot(),
              ],
              if (rating?.isNotEmpty == true) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    '★ $rating',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12 * _s,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _metaDot(),
              ],
              if (duration?.isNotEmpty == true) ...[
                _metaText(duration!),
                if (genres.isNotEmpty) _metaDot(),
              ],
              if (genres.isNotEmpty)
                Flexible(
                  child: Text(
                    genres.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.accentLight,
                      fontSize: 13 * _s,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              _TvHeroButton(
                icon: Icons.play_arrow_rounded,
                label: 'Reproducir ahora',
                scale: _s,
                autofocus: true,
                onTap: () => _play(f, _store.movies),
              ),
              const SizedBox(width: 14),
              _TvHeroButton(
                icon: fav ? Icons.check_rounded : Icons.add_rounded,
                label: fav ? 'Agregado a Mi Lista' : 'Añadir a Mi Lista',
                scale: _s,
                onTap: () => _toggleFavorite(f),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metaText(String s) => Text(
    s,
    style: TextStyle(
      color: AppColors.textSecondary,
      fontSize: 13 * _s,
      fontWeight: FontWeight.w700,
    ),
  );

  Widget _metaDot() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 10),
    child: Text(
      '•',
      style: TextStyle(color: AppColors.textMuted, fontSize: 13 * _s),
    ),
  );

  Widget _heroBadge(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
      text,
      style: TextStyle(
        color: Colors.white,
        fontSize: 11 * _s,
        fontWeight: FontWeight.w900,
        letterSpacing: 1,
      ),
    ),
  );

  // ============================ FILAS ============================

  List<({String title, List<Channel> items, bool originals})> get _rows {
    if (_cat == 'series') {
      final s = _seriesAsChannels(_store.series);
      return [
        if (s.isNotEmpty) (title: 'Series', items: s, originals: false),
      ];
    }
    final movies = _store.movies;
    final ranked = [...movies]
      ..sort((a, b) => _ratingOf(b).compareTo(_ratingOf(a)));
    final recent = StorageService.loadRecent()
        .where((c) => c.type != MediaType.live)
        .toList(growable: false);
    final rows = <({String title, List<Channel> items, bool originals})>[];
    if (_cat == 'all' && recent.isNotEmpty) {
      rows.add((title: 'Continuar viendo', items: recent, originals: false));
    }
    if (ranked.isNotEmpty) {
      rows.add((title: 'Tendencias en HourTV', items: ranked, originals: true));
    }
    if (movies.isNotEmpty) {
      rows.add((title: 'Todas las películas', items: movies, originals: false));
    }
    final series = _seriesAsChannels(_store.series);
    if (_cat == 'all' && series.isNotEmpty) {
      rows.add((title: 'Series', items: series, originals: false));
    }
    return rows;
  }

  List<Channel> _seriesAsChannels(List<XtreamSeries> series) => [
    for (final s in series)
      Channel(
        name: s.name,
        url: 'hourtv-series:${s.seriesId}',
        logo: s.cover,
        backdrop: s.backdrop,
        forcedType: 'series',
        plot: s.plot,
        year: s.year,
        rating: s.rating,
        duration: s.duration,
        genre: s.genre,
        categories: s.categories,
      ),
  ];

  Widget _tvRow(int rowIdx, String title, List<Channel> items, bool originals) {
    if (items.isEmpty) return const SizedBox.shrink();
    // Atenuar filas no enfocadas (como el prototipo: opacity-40).
    final opacity = _focusedRow < 0
        ? 0.62
        : (rowIdx == _focusedRow ? 1.0 : 0.4);
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 250),
      opacity: opacity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 28, 0, 12),
            child: Row(
              children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration: const BoxDecoration(
                    color: AppColors.accent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 9),
                Text(
                  title.toUpperCase(),
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14 * _s,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: _cardH + _labelH + 14,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              itemCount: items.length > 40 ? 40 : items.length,
              itemBuilder: (ctx, i) =>
                  _tvCard(items[i], items, rowIdx, originals),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tvCard(Channel ch, List<Channel> ctx, int rowIdx, bool originals) {
    final focused = identical(_focusedCard, ch);
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: TvFocusable(
        onTap: () => _openDetails(ch, ctx),
        onFocusChange: (f) => _onCardFocus(ch, rowIdx, f),
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: _cardW,
          height: _cardH + _labelH,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: _cardW,
                  height: _cardH,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ColoredBox(
                        color: AppColors.cardElevated,
                        child: ch.logo != null && ch.logo!.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: ch.logo!,
                                fit: BoxFit.cover,
                                memCacheWidth: 360,
                                placeholder: (_, _) => _posterPh(ch),
                                errorWidget: (_, _, _) => _posterPh(ch),
                              )
                            : _posterPh(ch),
                      ),
                      if (originals)
                        Positioned(
                          top: 7,
                          left: 7,
                          child: _posterBadge('ORIGINAL'),
                        ),
                    ],
                  ),
                ),
              ),
              // Etiqueta bajo la tarjeta enfocada (título, coincidencia, meta).
              if (focused)
                Positioned(
                  top: _cardH + 8,
                  left: 0,
                  width: _cardW,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        ch.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_matchOf(ch)}% Coincidencia',
                        style: const TextStyle(
                          color: AppColors.accentLight,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
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

/// Botón del hero TV: translúcido en reposo; al enfocar se vuelve BLANCO con
/// borde + glow rojo y escala (como los botones del prototipo `TvView.tsx`).
class _TvHeroButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool autofocus;
  final double scale;
  const _TvHeroButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.scale = 1.0,
    this.autofocus = false,
  });
  @override
  State<_TvHeroButton> createState() => _TvHeroButtonState();
}

class _TvHeroButtonState extends State<_TvHeroButton> {
  final _node = FocusNode();
  bool _f = false;

  @override
  void dispose() {
    _node.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    final activate = {
      LogicalKeyboardKey.select,
      LogicalKeyboardKey.enter,
      LogicalKeyboardKey.numpadEnter,
      LogicalKeyboardKey.space,
      LogicalKeyboardKey.gameButtonA,
    };
    if (activate.contains(e.logicalKey)) {
      widget.onTap();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.scale;
    return Focus(
      focusNode: _node,
      autofocus: widget.autofocus,
      onKeyEvent: _onKey,
      onFocusChange: (f) => setState(() => _f = f),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _f ? 1.06 : 1.0,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: EdgeInsets.symmetric(horizontal: 22 * s, vertical: 13 * s),
            decoration: BoxDecoration(
              color: _f ? Colors.white : Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _f ? AppColors.accent : Colors.white.withValues(alpha: 0.12),
                width: 2,
              ),
              boxShadow: _f
                  ? [
                      BoxShadow(
                        color: AppColors.accent.withValues(alpha: 0.45),
                        blurRadius: 20,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  widget.icon,
                  size: 20 * s,
                  color: _f ? Colors.black : Colors.white,
                ),
                const SizedBox(width: 9),
                Text(
                  widget.label,
                  style: TextStyle(
                    color: _f ? Colors.black : Colors.white,
                    fontSize: 15 * s,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
