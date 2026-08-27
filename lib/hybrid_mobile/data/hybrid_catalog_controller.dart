import 'package:flutter/foundation.dart';

import '../../models/channel.dart';
import '../../services/content_store.dart';
import '../../services/xtream_service.dart';
import '../../studio_ui/data/studio_catalog_adapter.dart';
import '../../studio_ui/data/studio_media_item.dart';
import 'hybrid_catalog_models.dart';

abstract interface class HybridCatalogSource implements Listenable {
  Future<void> ensureLoaded();
  List<StudioMediaItem> snapshot();
  Future<bool> toggleMyList(StudioMediaItem item);
}

class ContentStoreHybridCatalogSource extends ChangeNotifier
    implements HybridCatalogSource {
  ContentStoreHybridCatalogSource({ContentStore? store})
    : _store = store ?? ContentStore.instance {
    _store.addListener(_onStoreChanged);
  }

  final ContentStore _store;

  void _onStoreChanged() => notifyListeners();

  @override
  Future<void> ensureLoaded() => _store.ensureLoaded();

  @override
  List<StudioMediaItem> snapshot() {
    final snapshot = StudioCatalogAdapter.fromStore(_store);
    return <StudioMediaItem>[
      ...snapshot.movies,
      ...snapshot.series,
    ];
  }

  @override
  Future<bool> toggleMyList(StudioMediaItem item) async {
    final channel = switch (item.source) {
      final Channel channel => channel,
      final XtreamSeries series => Channel(
        name: series.name,
        url: 'series:${series.seriesId}',
        logo: series.cover,
        forcedType: 'series',
        genre: series.genre,
        year: series.year,
        rating: series.rating,
        duration: series.duration,
        plot: series.plot,
        cast: series.cast,
        director: series.director,
        writer: series.writer,
        releaseDate: series.releaseDate,
        backdrop: series.backdrop,
        categories: series.categories,
        isFeatured: series.isFeatured,
      ),
      _ => null,
    };
    if (channel == null) return item.isFavorite;

    await _store.toggleFavorite(channel);
    return _store.favorites.any((favorite) => favorite.url == channel.url);
  }

  @override
  void dispose() {
    _store.removeListener(_onStoreChanged);
    super.dispose();
  }
}

class HybridCatalogController extends ChangeNotifier {
  HybridCatalogController({required HybridCatalogSource source}) {
    _source = source;
    _source.addListener(_onSourceChanged);
  }

  late final HybridCatalogSource _source;
  List<HybridMediaItem> _all = const <HybridMediaItem>[];
  Set<String> _myListIds = <String>{};
  bool _loaded = false;

  List<HybridMediaItem> get all => _all;

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    await _source.ensureLoaded();
    _refreshFromSource();
  }

  List<HybridMediaSection> get homeSections {
    const titles = <HybridMediaKind, String>{
      HybridMediaKind.movie: 'Películas más populares',
      HybridMediaKind.series: 'Series para maratonear',
      HybridMediaKind.anime: 'Anime',
      HybridMediaKind.novela: 'Novelas',
    };
    return <HybridMediaSection>[
      for (final kind in HybridMediaKind.values)
        if (_all.any((item) => item.kind == kind))
          HybridMediaSection(
            id: kind.name,
            title: titles[kind]!,
            kind: kind,
            items: List<HybridMediaItem>.unmodifiable(
              _all.where((item) => item.kind == kind),
            ),
          ),
    ];
  }

  List<HybridMediaItem> search(
    String query, {
    HybridMediaKind? kind,
  }) {
    final terms = _normalize(query)
        .split(' ')
        .where((term) => term.isNotEmpty)
        .toList(growable: false);
    if (terms.isEmpty && kind == null) return _all;

    return _all.where((item) {
      if (kind != null && item.kind != kind) return false;
      final haystack = _normalize(<String>[
        item.title,
        if (item.genre != null) item.genre!,
        ...item.categories,
      ].join(' '));
      return terms.every(haystack.contains);
    }).toList(growable: false);
  }

  List<HybridMediaItem> filter({
    HybridMediaKind? kind,
    String? genre,
    HybridSortOrder order = HybridSortOrder.newest,
  }) {
    final normalizedGenre = _normalize(genre ?? '');
    final result = _all.where((item) {
      if (kind != null && item.kind != kind) return false;
      if (normalizedGenre.isEmpty) return true;
      final genres = _normalize(<String>[
        if (item.genre != null) item.genre!,
        ...item.categories,
      ].join(' '));
      return genres.contains(normalizedGenre);
    }).toList();

    result.sort(switch (order) {
      HybridSortOrder.newest => (a, b) => _year(b).compareTo(_year(a)),
      HybridSortOrder.oldest => (a, b) => _year(a).compareTo(_year(b)),
      HybridSortOrder.titleAscending => (a, b) =>
        _normalize(a.title).compareTo(_normalize(b.title)),
    });
    return result;
  }

  bool isInMyList(String mediaId) => _myListIds.contains(mediaId);

  Future<void> toggleMyList(String mediaId) async {
    final item = _all.cast<HybridMediaItem?>().firstWhere(
      (candidate) => candidate?.id == mediaId,
      orElse: () => null,
    );
    if (item == null) return;

    final isFavorite = await _source.toggleMyList(item.media);
    if (isFavorite) {
      _myListIds.add(mediaId);
    } else {
      _myListIds.remove(mediaId);
    }
    notifyListeners();
  }

  void _onSourceChanged() => _refreshFromSource();

  void _refreshFromSource() {
    final media = _source.snapshot();
    _all = List<HybridMediaItem>.unmodifiable(
      media.map(
        (item) => HybridMediaItem(media: item, kind: _kindFor(item)),
      ),
    );
    _myListIds = <String>{
      ..._myListIds.where((id) => _all.any((item) => item.id == id)),
      ...media.where((item) => item.isFavorite).map((item) => item.id),
    };
    notifyListeners();
  }

  @override
  void dispose() {
    _source.removeListener(_onSourceChanged);
    super.dispose();
  }

  static HybridMediaKind _kindFor(StudioMediaItem item) {
    final classification = _normalize(<String>[
      item.title,
      if (item.genre != null) item.genre!,
      ...item.categories,
    ].join(' '));
    if (classification.contains('anime')) return HybridMediaKind.anime;
    if (classification.contains('novela') ||
        classification.contains('telenovela')) {
      return HybridMediaKind.novela;
    }
    return item.kind == StudioMediaKind.movie
        ? HybridMediaKind.movie
        : HybridMediaKind.series;
  }

  static int _year(HybridMediaItem item) => int.tryParse(item.year ?? '') ?? 0;

  static String _normalize(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp('[áàäâã]'), 'a')
      .replaceAll(RegExp('[éèëê]'), 'e')
      .replaceAll(RegExp('[íìïî]'), 'i')
      .replaceAll(RegExp('[óòöôõ]'), 'o')
      .replaceAll(RegExp('[úùüû]'), 'u')
      .replaceAll('ñ', 'n')
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .trim();
}
