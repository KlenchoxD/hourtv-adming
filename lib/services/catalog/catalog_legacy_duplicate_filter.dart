import '../../models/channel.dart';
import '../tmdb_service.dart';

/// Hides low-metadata IPTV copies when a curated catalog record for the same
/// franchise/year is already available. This handles legacy feeds whose
/// localized titles differ while their rows have no TMDB id or poster.
///
/// A weak row is retained when there is no stronger match, so this never
/// removes a movie solely because of its title or provider.
class CatalogLegacyDuplicateFilter {
  CatalogLegacyDuplicateFilter._();

  static const _genericMovieCategories = {
    'movie',
    'movies',
    'pelicula',
    'peliculas',
    'vod',
  };

  static const _leadingArticles = {
    'a',
    'an',
    'el',
    'la',
    'las',
    'los',
    'the',
    'un',
    'una',
    'uno',
  };

  static List<Channel> withoutCuratedAliases(Iterable<Channel> source) {
    final channels = List<Channel>.of(source);
    final curatedGroups = <String>{};

    for (final channel in channels) {
      if (channel.type != MediaType.movie ||
          channel.tmdbId == null ||
          !_hasHttpArtwork(channel.logo)) {
        continue;
      }
      final group = _franchiseYearKey(channel);
      if (group != null) curatedGroups.add(group);
    }

    if (curatedGroups.isEmpty) return channels;
    return channels
        .where((channel) {
          if (!_isWeakGenericMovie(channel)) return true;
          final group = _franchiseYearKey(channel);
          return group == null || !curatedGroups.contains(group);
        })
        .toList(growable: false);
  }

  static bool _isWeakGenericMovie(Channel channel) {
    if (channel.type != MediaType.movie ||
        channel.tmdbId != null ||
        _hasHttpArtwork(channel.logo)) {
      return false;
    }
    final category = TmdbService.normalizeTitle(
      (channel.category?.trim().isNotEmpty ?? false)
          ? channel.category!
          : (channel.group ?? ''),
    );
    return _genericMovieCategories.contains(category);
  }

  static bool _hasHttpArtwork(String? value) {
    final uri = Uri.tryParse(value?.trim() ?? '');
    return uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
  }

  static String? _franchiseYearKey(Channel channel) {
    final year = int.tryParse(channel.year?.trim() ?? '');
    if (year == null || year < 1888 || year > 2100) return null;

    final tokens = TmdbService.normalizeTitle(channel.displayName)
        .split(' ')
        .where((token) => token.length > 1 && !_leadingArticles.contains(token))
        .toList(growable: false);
    if (tokens.length < 2) return null;
    return '$year:${tokens.take(2).join(' ')}';
  }
}
