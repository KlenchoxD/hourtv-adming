import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/channel.dart';
import '../services/content_store.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/tv_focusable.dart';
import 'player_screen.dart';
import 'search_screen.dart';

/// Pestaña INICIO: catálogo de VIDEO BAJO DEMANDA (películas y series) estilo
/// Netflix/Stremio. NO muestra canales en vivo (eso vive en la pestaña En Vivo).
class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key});
  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

const _tabs = ['Para ti', 'Películas', 'Series'];

class _CatalogScreenState extends State<CatalogScreen> {
  final _store = ContentStore.instance;
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _store.addListener(_onChange);
    _store.ensureLoaded();
  }

  @override
  void dispose() {
    _store.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() { if (mounted) setState(() {}); }

  void _play(Channel ch, List<Channel> ctx) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => PlayerScreen(channel: ch, allChannels: ctx.isEmpty ? [ch] : ctx)));
  }

  Future<void> _openSearch() async {
    final picked = await Navigator.push<Channel>(context, MaterialPageRoute(builder: (_) => SearchScreen(all: _store.all)));
    if (picked != null && mounted) _play(picked, _store.movies);
  }

  bool get _vodLoading => _store.moviesLoading || _store.vodLoading;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(children: [
        _topBar(),
        _tabsRow(),
        Expanded(child: _content()),
      ]),
    );
  }

  Widget _topBar() => Padding(
    padding: const EdgeInsets.fromLTRB(18, 12, 12, 6),
    child: Row(children: [
      Container(
        width: 30, height: 30,
        decoration: BoxDecoration(gradient: AppTheme.accentGradient, borderRadius: BorderRadius.circular(8)),
        child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 20),
      ),
      const SizedBox(width: 9),
      ShaderMask(shaderCallback: (b) => AppTheme.accentGradient.createShader(b), child: const Text('Hour', style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800))),
      const Text('TV', style: TextStyle(color: AppColors.textPrimary, fontSize: 19, fontWeight: FontWeight.w300)),
      const Spacer(),
      if (_vodLoading) const Padding(padding: EdgeInsets.only(right: 6), child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent))),
      IconButton(icon: const Icon(Icons.search_rounded, color: AppColors.textPrimary), onPressed: _openSearch),
    ]),
  );

  Widget _tabsRow() => SizedBox(
    height: 44,
    child: ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      itemCount: _tabs.length,
      itemBuilder: (ctx, i) {
        final sel = i == _tab;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: TvFocusable(
            onTap: () => setState(() => _tab = i),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(_tabs[i], style: TextStyle(color: sel ? AppColors.textPrimary : AppColors.textMuted, fontSize: 15, fontWeight: sel ? FontWeight.w800 : FontWeight.w500)),
                const SizedBox(height: 4),
                AnimatedContainer(duration: const Duration(milliseconds: 160), height: 3, width: sel ? 22 : 0, decoration: BoxDecoration(gradient: AppTheme.accentGradient, borderRadius: BorderRadius.circular(2))),
              ]),
            ),
          ),
        );
      },
    ),
  );

  Widget _content() {
    if (_tab == 2) return _seriesTab();
    final genres = _store.movieGenres;
    if (genres.isEmpty) {
      if (_vodLoading) return _loading('Cargando películas...');
      return _vodEmpty('películas');
    }
    final showHero = _tab == 0;
    final recent = showHero ? StorageService.loadRecent() : const <Channel>[];
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        if (showHero) _hero(),
        if (recent.isNotEmpty) _movieRow('Continuar viendo', recent),
        for (final g in genres) _movieRow(g, _store.moviesByGenre(g)),
        if (showHero && _store.series.isNotEmpty) _seriesRow(),
      ],
    );
  }

  // --------- Hero destacado ---------
  Widget _hero() {
    final movies = _store.movies.where((m) => m.logo != null).toList();
    if (movies.isEmpty) return const SizedBox.shrink();
    final f = movies.first;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 4),
      height: 190,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), color: AppColors.cardDark, border: Border.all(color: Colors.white.withValues(alpha: 0.06))),
      clipBehavior: Clip.antiAlias,
      child: Stack(fit: StackFit.expand, children: [
        if (f.logo != null) CachedNetworkImage(imageUrl: f.logo!, fit: BoxFit.cover, errorWidget: (_, _, _) => const SizedBox()),
        DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Colors.black.withValues(alpha: 0.92), Colors.black.withValues(alpha: 0.15)]))),
        Padding(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.end, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(6)),
              child: const Text('DESTACADA', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
            ),
            const SizedBox(height: 10),
            Text(f.displayName, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            TvFocusable(
              onTap: () => _play(f, _store.movies),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.play_arrow_rounded, color: Colors.black, size: 20),
                  SizedBox(width: 6),
                  Text('Reproducir', style: TextStyle(color: Colors.black, fontSize: 14, fontWeight: FontWeight.w700)),
                ]),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  // --------- Fila de películas ---------
  Widget _movieRow(String title, List<Channel> items) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
        child: Row(children: [
          Text(title, style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(width: 8),
          Text('${items.length}', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
        ]),
      ),
      SizedBox(
        height: 198,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          itemCount: items.length > 40 ? 40 : items.length,
          itemBuilder: (ctx, i) => _posterCard(items[i], items),
        ),
      ),
    ]);
  }

  Widget _posterCard(Channel ch, List<Channel> ctx) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 5),
    child: TvFocusable(
      onTap: () => _play(ch, ctx),
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 118,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 118, height: 165,
              color: AppColors.cardElevated,
              child: ch.logo != null && ch.logo!.isNotEmpty
                  ? CachedNetworkImage(imageUrl: ch.logo!, fit: BoxFit.cover, placeholder: (_, _) => _posterPh(ch), errorWidget: (_, _, _) => _posterPh(ch))
                  : _posterPh(ch),
            ),
          ),
          const SizedBox(height: 6),
          Text(ch.displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
        ]),
      ),
    ),
  );

  Widget _posterPh(Channel ch) => Container(
    alignment: Alignment.center,
    decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppColors.cardElevated, AppColors.cardDark])),
    padding: const EdgeInsets.all(8),
    child: Text(ch.displayName, maxLines: 4, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.accentLight, fontSize: 12, fontWeight: FontWeight.w700)),
  );

  // --------- Series ---------
  Widget _seriesRow() {
    final series = _store.series;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Padding(
        padding: EdgeInsets.fromLTRB(18, 18, 18, 10),
        child: Text('Series', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w800)),
      ),
      SizedBox(
        height: 198,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          itemCount: series.length > 40 ? 40 : series.length,
          itemBuilder: (ctx, i) => _seriesCard(series[i]),
        ),
      ),
    ]);
  }

  Widget _seriesTab() {
    final series = _store.series;
    if (series.isEmpty) {
      if (_vodLoading) return _loading('Cargando series...');
      return _vodEmpty('series');
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 124, childAspectRatio: 0.56, crossAxisSpacing: 12, mainAxisSpacing: 16),
      itemCount: series.length,
      itemBuilder: (ctx, i) => _seriesCard(series[i]),
    );
  }

  Widget _seriesCard(dynamic s) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 5),
    child: SizedBox(
      width: 118,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 118, height: 165,
            color: AppColors.cardElevated,
            child: s.cover != null && (s.cover as String).isNotEmpty
                ? CachedNetworkImage(imageUrl: s.cover, fit: BoxFit.cover, errorWidget: (_, _, _) => _seriesPh(s.name))
                : _seriesPh(s.name),
          ),
        ),
        const SizedBox(height: 6),
        Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
      ]),
    ),
  );

  Widget _seriesPh(String name) => Container(
    alignment: Alignment.center,
    padding: const EdgeInsets.all(8),
    decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppColors.cardElevated, AppColors.cardDark])),
    child: Text(name, maxLines: 4, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.accentLight, fontSize: 11, fontWeight: FontWeight.w700)),
  );

  // --------- Estados ---------
  Widget _loading(String msg) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
    const SizedBox(width: 30, height: 30, child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.accent)),
    const SizedBox(height: 16),
    Text(msg, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
  ]));

  Widget _vodEmpty(String tipo) => Center(child: Padding(
    padding: const EdgeInsets.all(32),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(tipo == 'series' ? Icons.tv_rounded : Icons.movie_rounded, color: AppColors.textMuted, size: 56),
      const SizedBox(height: 16),
      Text('Aún no hay $tipo', style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      Text(
        tipo == 'series'
            ? 'Las series bajo demanda vienen de una cuenta Xtream.\nConéctala desde Perfil → Mis Fuentes.'
            : 'Conéctate a internet para cargar el catálogo,\no agrega una cuenta Xtream en Perfil → Mis Fuentes.',
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
      ),
    ]),
  ));
}
