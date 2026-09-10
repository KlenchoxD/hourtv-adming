import 'catalog_cursor.dart';

/// Excepción de red específica para operaciones con el catálogo remoto de Supabase.
class CatalogNetworkException implements Exception {
  final String message;
  final Object? cause;

  const CatalogNetworkException(this.message, {this.cause});

  @override
  String toString() => 'CatalogNetworkException: $message${cause != null ? ' (Cause: $cause)' : ''}';
}

/// Orden de clasificación para consultas de catálogo.
enum CatalogSortOrder {
  recent,
  ratingDesc,
  titleAsc,
}

/// Resultado de una página de catálogo con cursor para la siguiente página.
class CatalogPageResult<T> {
  final List<T> items;
  final CatalogCursor? nextCursor;
  final bool hasMore;

  const CatalogPageResult({
    required this.items,
    this.nextCursor,
    required this.hasMore,
  });
}

/// DTO ligero para tarjetas en grilla y filas horizontales de Inicio/Buscar.
class CatalogSummaryDto {
  final String id;
  final String? legacyId;
  final String title;
  final String normalizedTitle;
  final String mediaType;
  final String? posterUrl;
  final String? backdropUrl;
  final int? year;
  final double? rating;
  final bool isFeatured;
  final DateTime createdAt;
  final List<String> genres;

  const CatalogSummaryDto({
    required this.id,
    this.legacyId,
    required this.title,
    required this.normalizedTitle,
    required this.mediaType,
    this.posterUrl,
    this.backdropUrl,
    this.year,
    this.rating,
    required this.isFeatured,
    required this.createdAt,
    this.genres = const [],
  });

  factory CatalogSummaryDto.fromJson(Map<String, dynamic> json) {
    final rawGenres = json['title_genres'] as List<dynamic>? ?? [];
    final extractedGenres = <String>[];
    for (final item in rawGenres) {
      if (item is Map<String, dynamic>) {
        final g = item['genres'];
        if (g is Map<String, dynamic>) {
          final slug = g['slug'] as String? ?? g['name'] as String?;
          if (slug != null && slug.isNotEmpty) {
            extractedGenres.add(slug);
          }
        }
      }
    }

    return CatalogSummaryDto(
      id: json['id'] as String,
      legacyId: json['legacy_id'] as String?,
      title: json['title'] as String,
      normalizedTitle: json['normalized_title'] as String? ?? '',
      mediaType: json['media_type'] as String,
      posterUrl: json['poster_url'] as String?,
      backdropUrl: json['backdrop_url'] as String?,
      year: json['year'] as int?,
      rating: json['rating'] != null ? (json['rating'] as num).toDouble() : null,
      isFeatured: json['is_featured'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      genres: extractedGenres,
    );
  }
}

/// DTO detallado para la ficha de detalle (reemplaza o hidrata Channel/XtreamSeries).
class CatalogDetailDto {
  final String id;
  final String? legacyId;
  final String title;
  final String? originalTitle;
  final String normalizedTitle;
  final String? plot;
  final String mediaType;
  final int? year;
  final DateTime? releaseDate;
  final String? duration;
  final double? rating;
  final String? posterUrl;
  final String? backdropUrl;
  final bool isFeatured;
  final String? castMembers;
  final String? director;
  final String? writer;
  final String? countryCode;
  final int? tmdbId;
  final String? imdbId;
  final DateTime createdAt;
  final List<String> genres;

  const CatalogDetailDto({
    required this.id,
    this.legacyId,
    required this.title,
    this.originalTitle,
    required this.normalizedTitle,
    this.plot,
    required this.mediaType,
    this.year,
    this.releaseDate,
    this.duration,
    this.rating,
    this.posterUrl,
    this.backdropUrl,
    required this.isFeatured,
    this.castMembers,
    this.director,
    this.writer,
    this.countryCode,
    this.tmdbId,
    this.imdbId,
    required this.createdAt,
    this.genres = const [],
  });

  factory CatalogDetailDto.fromJson(Map<String, dynamic> json) {
    final rawGenres = json['title_genres'] as List<dynamic>? ?? [];
    final extractedGenres = <String>[];
    for (final item in rawGenres) {
      if (item is Map<String, dynamic>) {
        final g = item['genres'];
        if (g is Map<String, dynamic>) {
          final slug = g['slug'] as String? ?? g['name'] as String?;
          if (slug != null && slug.isNotEmpty) {
            extractedGenres.add(slug);
          }
        }
      }
    }

    return CatalogDetailDto(
      id: json['id'] as String,
      legacyId: json['legacy_id'] as String?,
      title: json['title'] as String,
      originalTitle: json['original_title'] as String?,
      normalizedTitle: json['normalized_title'] as String? ?? '',
      plot: json['plot'] as String?,
      mediaType: json['media_type'] as String,
      year: json['year'] as int?,
      releaseDate: json['release_date'] != null
          ? DateTime.tryParse(json['release_date'] as String)
          : null,
      duration: json['duration'] as String?,
      rating: json['rating'] != null ? (json['rating'] as num).toDouble() : null,
      posterUrl: json['poster_url'] as String?,
      backdropUrl: json['backdrop_url'] as String?,
      isFeatured: json['is_featured'] as bool? ?? false,
      castMembers: json['cast_members'] as String?,
      director: json['director'] as String?,
      writer: json['writer'] as String?,
      countryCode: json['country_code'] as String?,
      tmdbId: json['tmdb_id'] as int?,
      imdbId: json['imdb_id'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      genres: extractedGenres,
    );
  }
}

/// DTO para una fuente de reproducción.
class CatalogSourceDto {
  final String id;
  final String? titleId;
  final String? episodeId;
  final String? languageId;
  final String? languageCode;
  final String name;
  final String url;
  final int orderIndex;
  final String status;
  final bool requiresWebview;
  final String? refererUrl;
  final String? originUrl;
  final String? userAgentProfile;

  const CatalogSourceDto({
    required this.id,
    this.titleId,
    this.episodeId,
    this.languageId,
    this.languageCode,
    required this.name,
    required this.url,
    required this.orderIndex,
    required this.status,
    required this.requiresWebview,
    this.refererUrl,
    this.originUrl,
    this.userAgentProfile,
  });

  factory CatalogSourceDto.fromJson(Map<String, dynamic> json) {
    String? langCode;
    if (json['languages'] is Map<String, dynamic>) {
      langCode = json['languages']['code'] as String?;
    }

    return CatalogSourceDto(
      id: json['id'] as String,
      titleId: json['title_id'] as String?,
      episodeId: json['episode_id'] as String?,
      languageId: json['language_id'] as String?,
      languageCode: langCode,
      name: json['name'] as String,
      url: json['url'] as String,
      orderIndex: json['order_index'] as int? ?? 0,
      status: json['status'] as String? ?? 'active',
      requiresWebview: json['requires_webview'] as bool? ?? false,
      refererUrl: json['referer_url'] as String?,
      originUrl: json['origin_url'] as String?,
      userAgentProfile: json['user_agent_profile'] as String?,
    );
  }
}

/// DTO para un episodio de una serie.
class CatalogEpisodeDto {
  final String id;
  final String seasonId;
  final int episodeNumber;
  final String title;
  final String? plot;
  final String? duration;
  final String? stillUrl;
  final DateTime? releaseDate;
  final List<CatalogSourceDto> sources;

  const CatalogEpisodeDto({
    required this.id,
    required this.seasonId,
    required this.episodeNumber,
    required this.title,
    this.plot,
    this.duration,
    this.stillUrl,
    this.releaseDate,
    this.sources = const [],
  });

  factory CatalogEpisodeDto.fromJson(Map<String, dynamic> json) {
    final rawSources = json['sources'] as List<dynamic>? ?? [];
    return CatalogEpisodeDto(
      id: json['id'] as String,
      seasonId: json['season_id'] as String,
      episodeNumber: json['episode_number'] as int,
      title: json['title'] as String,
      plot: json['plot'] as String?,
      duration: json['duration'] as String?,
      stillUrl: json['still_url'] as String?,
      releaseDate: json['release_date'] != null
          ? DateTime.tryParse(json['release_date'] as String)
          : null,
      sources: rawSources
          .whereType<Map<String, dynamic>>()
          .map(CatalogSourceDto.fromJson)
          .toList(),
    );
  }
}

/// DTO para una temporada de una serie.
class CatalogSeasonDto {
  final String id;
  final String titleId;
  final int seasonNumber;
  final String? name;
  final String? plot;
  final String? posterUrl;
  final List<CatalogEpisodeDto> episodes;

  const CatalogSeasonDto({
    required this.id,
    required this.titleId,
    required this.seasonNumber,
    this.name,
    this.plot,
    this.posterUrl,
    this.episodes = const [],
  });

  factory CatalogSeasonDto.fromJson(Map<String, dynamic> json) {
    final rawEpisodes = json['episodes'] as List<dynamic>? ?? [];
    return CatalogSeasonDto(
      id: json['id'] as String,
      titleId: json['title_id'] as String,
      seasonNumber: json['season_number'] as int,
      name: json['name'] as String?,
      plot: json['plot'] as String?,
      posterUrl: json['poster_url'] as String?,
      episodes: rawEpisodes
          .whereType<Map<String, dynamic>>()
          .map(CatalogEpisodeDto.fromJson)
          .toList(),
    );
  }
}

/// DTO para deltas de sincronización de catalog_changes.
class CatalogChangeDto {
  final int revision;
  final String entityType;
  final String entityId;
  final String operation;
  final DateTime changedAt;

  const CatalogChangeDto({
    required this.revision,
    required this.entityType,
    required this.entityId,
    required this.operation,
    required this.changedAt,
  });

  factory CatalogChangeDto.fromJson(Map<String, dynamic> json) {
    return CatalogChangeDto(
      revision: (json['revision'] as num).toInt(),
      entityType: json['entity_type'] as String,
      entityId: json['entity_id'] as String,
      operation: json['operation'] as String,
      changedAt: DateTime.parse(json['changed_at'] as String),
    );
  }
}

/// DTO para metadatos de sincronización de catalog_sync_metadata.
class CatalogSyncMetadataDto {
  final int minimumAvailableRevision;
  final int latestRevision;

  const CatalogSyncMetadataDto({
    required this.minimumAvailableRevision,
    required this.latestRevision,
  });

  factory CatalogSyncMetadataDto.fromJson(Map<String, dynamic> json) {
    return CatalogSyncMetadataDto(
      minimumAvailableRevision: (json['minimum_available_revision'] as num).toInt(),
      latestRevision: (json['latest_revision'] as num).toInt(),
    );
  }
}
