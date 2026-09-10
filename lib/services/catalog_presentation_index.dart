import '../mobile_ui/hourtv_genre_service.dart';
import '../models/channel.dart';

enum ContentTypeFilter { all, movies, series, anime, novels }

enum CatalogSort { newest, oldest, titleAscending }

class CatalogQuery {
  const CatalogQuery({
    this.text = '',
    this.type = ContentTypeFilter.all,
    this.genre,
    this.sort = CatalogSort.newest,
  });

  final String text;
  final ContentTypeFilter type;
  final String? genre;
  final CatalogSort sort;
}

class _IndexedChannel {
  final Channel channel;
  final String normalizedTitle;
  final String searchableText;
  final Set<String> normalizedGenres;
  final Set<String> displayGenres;
  final int parsedYear;
  final bool isMovie;
  final bool isSeries;
  final bool isAnime;
  final bool isNovel;
  final bool isValidArtwork;
  final bool isPlayableSource;
  final int originalIndex;

  _IndexedChannel({
    required this.channel,
    required this.normalizedTitle,
    required this.searchableText,
    required this.normalizedGenres,
    required this.displayGenres,
    required this.parsedYear,
    required this.isMovie,
    required this.isSeries,
    required this.isAnime,
    required this.isNovel,
    required this.isValidArtwork,
    required this.isPlayableSource,
    required this.originalIndex,
  });

  bool matchesType(ContentTypeFilter typeFilter) => switch (typeFilter) {
    ContentTypeFilter.all => true,
    ContentTypeFilter.movies => isMovie,
    ContentTypeFilter.series => isSeries,
    ContentTypeFilter.anime => isAnime,
    ContentTypeFilter.novels => isNovel,
  };
}

/// Índice de presentación inmutable para búsquedas, destacados y géneros.
///
/// Precomputa títulos normalizados, textos de búsqueda, años y tipos para
/// que las consultas en la interfaz no realicen normalizaciones ni escaneos
/// repetitivos en cada build().
class CatalogPresentationIndex {
  CatalogPresentationIndex._({
    required List<_IndexedChannel> records,
    required Map<ContentTypeFilter, List<String>> genresByType,
  })  : _records = records,
        _genresByType = genresByType;

  final List<_IndexedChannel> _records;
  final Map<ContentTypeFilter, List<String>> _genresByType;

  // Caché para consultas repetidas de términos de búsqueda y géneros
  static final Map<String, List<String>> _queryTermsCache = {};
  static final Map<String, String> _genreTermsCache = {};

  /// Construye un índice de presentación inmutable a partir de una lista de canales.
  static CatalogPresentationIndex build(List<Channel> channels) {
    final records = <_IndexedChannel>[];

    for (var i = 0; i < channels.length; i++) {
      final channel = channels[i];

      final normalizedTitle = HourTvGenreService.normalize(channel.name);

      final searchableParts = [
        channel.name,
        channel.plot,
        channel.genre,
        channel.group,
        ...channel.categories,
      ].whereType<String>().where((s) => s.trim().isNotEmpty);

      final searchableText = HourTvGenreService.normalize(
        searchableParts.join(' '),
      );

      final displayGenres = HourTvGenreService.extractItemGenres(channel);
      final normalizedGenres = displayGenres
          .map(HourTvGenreService.normalize)
          .where((g) => g.isNotEmpty)
          .toSet();

      final metadataNormalized = HourTvGenreService.normalize(
        [channel.genre, channel.group, ...channel.categories]
            .whereType<String>()
            .join(' '),
      );

      final isMovie = channel.type == MediaType.movie ||
          channel.forcedType == 'movie';
      final isSeries = channel.type == MediaType.series ||
          channel.forcedType == 'series';
      final isAnime = metadataNormalized.contains('anime');
      final isNovel = metadataNormalized.contains('novela') ||
          metadataNormalized.contains('telenovela');

      final isValidArtwork = (channel.backdrop ?? '').trim().isNotEmpty;
      final isPlayableSource = channel.url.trim().isNotEmpty ||
          channel.servers.any((s) => s.url.trim().isNotEmpty);

      final parsedYear = int.tryParse(channel.year ?? '') ?? 0;

      records.add(
        _IndexedChannel(
          channel: channel,
          normalizedTitle: normalizedTitle,
          searchableText: searchableText,
          normalizedGenres: normalizedGenres,
          displayGenres: displayGenres,
          parsedYear: parsedYear,
          isMovie: isMovie,
          isSeries: isSeries,
          isAnime: isAnime,
          isNovel: isNovel,
          isValidArtwork: isValidArtwork,
          isPlayableSource: isPlayableSource,
          originalIndex: i,
        ),
      );
    }

    // Precomputar géneros disponibles para cada ContentTypeFilter
    final genresByType = <ContentTypeFilter, List<String>>{};
    for (final typeFilter in ContentTypeFilter.values) {
      final matchingChannels = records
          .where((r) => r.matchesType(typeFilter))
          .map((r) => r.channel);
      genresByType[typeFilter] = HourTvGenreService.getAvailableGenres(
        matchingChannels,
      );
    }

    return CatalogPresentationIndex._(
      records: List.unmodifiable(records),
      genresByType: Map.unmodifiable(genresByType),
    );
  }

  /// Ejecuta una búsqueda filtrando por texto, tipo, género y ordenamiento.
  List<Channel> search(CatalogQuery query) {
    List<String> terms = const [];
    if (query.text.trim().isNotEmpty) {
      terms = _queryTermsCache.putIfAbsent(query.text, () {
        final norm = HourTvGenreService.normalize(query.text);
        return norm
            .split(' ')
            .where((s) => s.isNotEmpty)
            .toList(growable: false);
      });
    }

    String? targetGenre;
    if (query.genre != null &&
        query.genre!.isNotEmpty &&
        query.genre != HourTvGenreService.defaultGenre &&
        query.genre != 'Todo') {
      targetGenre = _genreTermsCache.putIfAbsent(
        query.genre!,
        () => HourTvGenreService.normalize(query.genre!),
      );
    }

    final matched = <_IndexedChannel>[];

    for (final record in _records) {
      if (!record.matchesType(query.type)) continue;

      if (targetGenre != null && !record.normalizedGenres.contains(targetGenre)) {
        continue;
      }

      if (terms.isNotEmpty && !terms.every(record.searchableText.contains)) {
        continue;
      }

      matched.add(record);
    }

    // Ordenar resultados según sort especificado
    switch (query.sort) {
      case CatalogSort.newest:
        matched.sort((a, b) {
          final cmp = b.parsedYear.compareTo(a.parsedYear);
          if (cmp != 0) return cmp;
          return a.normalizedTitle.compareTo(b.normalizedTitle);
        });
      case CatalogSort.oldest:
        matched.sort((a, b) {
          final cmp = a.parsedYear.compareTo(b.parsedYear);
          if (cmp != 0) return cmp;
          return a.normalizedTitle.compareTo(b.normalizedTitle);
        });
      case CatalogSort.titleAscending:
        matched.sort((a, b) {
          final cmp = a.normalizedTitle.compareTo(b.normalizedTitle);
          if (cmp != 0) return cmp;
          return a.originalIndex.compareTo(b.originalIndex);
        });
    }

    return matched.map((r) => r.channel).toList(growable: false);
  }

  /// Retorna los títulos destacados que cumplen con los requisitos editoriales
  /// (isFeatured == true, imagen horizontal de fondo y fuente reproducible).
  ///
  /// Si no hay suficientes títulos destacados calificados, usa un fallback
  /// determinista con contenido completo (backdrop y fuente válida), nunca el orden de entrada.
  List<Channel> featured({int limit = 5}) {
    if (limit <= 0) return const [];

    final qualifiedFeatured = _records
        .where(
          (r) =>
              r.channel.isFeatured &&
              r.isValidArtwork &&
              r.isPlayableSource,
        )
        .toList();

    if (qualifiedFeatured.isNotEmpty) {
      qualifiedFeatured.sort((a, b) {
        final cmp = b.parsedYear.compareTo(a.parsedYear);
        if (cmp != 0) return cmp;
        return a.normalizedTitle.compareTo(b.normalizedTitle);
      });
      return qualifiedFeatured
          .take(limit)
          .map((r) => r.channel)
          .toList(growable: false);
    }

    // Fallback determinista: contenido completo con artwork y fuente reproducible
    final fallback = _records
        .where((r) => r.isValidArtwork && r.isPlayableSource)
        .toList();

    fallback.sort((a, b) {
      final cmp = b.parsedYear.compareTo(a.parsedYear);
      if (cmp != 0) return cmp;
      return a.normalizedTitle.compareTo(b.normalizedTitle);
    });

    return fallback.take(limit).map((r) => r.channel).toList(growable: false);
  }

  /// Retorna la lista de géneros disponibles para un tipo de contenido dado,
  /// con 'Todos los géneros' como primera opción.
  List<String> genresFor(ContentTypeFilter type) {
    return _genresByType[type] ?? const [HourTvGenreService.defaultGenre];
  }
}
