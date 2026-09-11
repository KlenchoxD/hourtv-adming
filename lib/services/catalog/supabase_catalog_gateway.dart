import 'package:supabase_flutter/supabase_flutter.dart';
import 'catalog_cursor.dart';
import 'catalog_dtos.dart';

/// Gateway para consultar el catálogo relacional normalizado y los registros
/// de sincronización incremental en Supabase utilizando PostgREST.
class SupabaseCatalogGateway {
  final SupabaseClient? _client;

  SupabaseCatalogGateway([this._client]);

  SupabaseClient get _effectiveClient {
    final client = _client ?? (Supabase.instance.isInitialized ? Supabase.instance.client : null);
    if (client == null) {
      throw const CatalogNetworkException('Supabase no está inicializado.');
    }
    return client;
  }

  /// Construye el filtro PostgREST para la paginación determinista por tupla (createdAt, id).
  /// Satisface: created_at < cursor.createdAt OR (created_at = cursor.createdAt AND id < cursor.id)
  static String buildCompositeCursorFilter(CatalogCursor cursor) {
    final iso = cursor.createdAt.toIso8601String();
    return 'created_at.lt.$iso,and(created_at.eq.$iso,id.lt.${cursor.id})';
  }

  /// Consulta una página de resúmenes de títulos con paginación determinista por cursor compuesta.
  Future<CatalogPageResult<CatalogSummaryDto>> fetchTitlesPage({
    CatalogCursor? cursor,
    int limit = 20,
    String? mediaType,
    String? genreSlug,
    CatalogSortOrder sort = CatalogSortOrder.recent,
  }) async {
    try {
      var query = _effectiveClient
          .from('titles')
          .select('''
            id, legacy_id, title, normalized_title, media_type,
            poster_url, backdrop_url, year, rating, is_featured, created_at,
            title_genres!inner (
              genres!inner (slug, name)
            )
          ''')
          .eq('is_published', true);

      if (mediaType != null) {
        query = query.eq('media_type', mediaType);
      }

      if (genreSlug != null) {
        query = query.eq('title_genres.genres.slug', genreSlug);
      }

      if (cursor != null) {
        query = query.or(buildCompositeCursorFilter(cursor));
      }

      // Orden determinista principal según sort
      PostgrestTransformBuilder<List<Map<String, dynamic>>> orderedQuery;
      switch (sort) {
        case CatalogSortOrder.recent:
          orderedQuery = query.order('created_at', ascending: false).order('id', ascending: false);
          break;
        case CatalogSortOrder.ratingDesc:
          orderedQuery = query.order('rating', ascending: false, nullsFirst: false).order('id', ascending: false);
          break;
        case CatalogSortOrder.titleAsc:
          orderedQuery = query.order('normalized_title', ascending: true).order('id', ascending: true);
          break;
      }

      final List<dynamic> rows = await orderedQuery.limit(limit + 1);
      final items = rows
          .take(limit)
          .map((r) => CatalogSummaryDto.fromJson(r as Map<String, dynamic>))
          .toList();

      final hasMore = rows.length > limit;
      CatalogCursor? nextCursor;
      if (hasMore && items.isNotEmpty) {
        final last = items.last;
        nextCursor = CatalogCursor(createdAt: last.createdAt, id: last.id);
      }

      return CatalogPageResult(
        items: items,
        nextCursor: nextCursor,
        hasMore: hasMore,
      );
    } catch (e) {
      if (e is CatalogNetworkException) rethrow;
      throw CatalogNetworkException('Error al consultar página de títulos remota', cause: e);
    }
  }

  /// Consulta la ficha detallada de un título por ID.
  Future<CatalogDetailDto?> fetchTitleDetails(String titleId) async {
    try {
      final data = await _effectiveClient
          .from('titles')
          .select('''
            id, legacy_id, title, original_title, normalized_title, plot,
            media_type, year, release_date, duration, rating, poster_url,
            backdrop_url, is_featured, cast_members, director, writer,
            country_code, tmdb_id, imdb_id, created_at,
            title_genres (
              genres (slug, name)
            )
          ''')
          .eq('id', titleId)
          .eq('is_published', true)
          .maybeSingle();

      if (data == null) return null;
      return CatalogDetailDto.fromJson(data);
    } catch (e) {
      if (e is CatalogNetworkException) rethrow;
      throw CatalogNetworkException('Error al consultar detalle del título $titleId', cause: e);
    }
  }

  /// Consulta las fuentes de reproducción para una película.
  Future<List<CatalogSourceDto>> fetchTitleSources(String titleId) async {
    try {
      final List<dynamic> rows = await _effectiveClient
          .from('sources')
          .select('''
            id, title_id, episode_id, language_id, name, url,
            order_index, status, requires_webview, referer_url,
            origin_url, user_agent_profile,
            languages (code, name)
          ''')
          .eq('title_id', titleId)
          .eq('status', 'active')
          .order('order_index', ascending: true);

      return rows
          .map((r) => CatalogSourceDto.fromJson(r as Map<String, dynamic>))
          .toList();
    } catch (e) {
      if (e is CatalogNetworkException) rethrow;
      throw CatalogNetworkException('Error al consultar fuentes del título $titleId', cause: e);
    }
  }

  /// Consulta las temporadas y episodios de una serie.
  Future<List<CatalogSeasonDto>> fetchSeriesEpisodes(String titleId) async {
    try {
      final List<dynamic> rows = await _effectiveClient
          .from('seasons')
          .select('''
            id, title_id, season_number, name, plot, poster_url,
            episodes (
              id, season_id, episode_number, title, plot, duration,
              still_url, release_date,
              sources (
                id, title_id, episode_id, language_id, name, url,
                order_index, status, requires_webview, referer_url,
                origin_url, user_agent_profile,
                languages (code, name)
              )
            )
          ''')
          .eq('title_id', titleId)
          .order('season_number', ascending: true);

      return rows
          .map((r) => CatalogSeasonDto.fromJson(r as Map<String, dynamic>))
          .toList();
    } catch (e) {
      if (e is CatalogNetworkException) rethrow;
      throw CatalogNetworkException('Error al consultar temporadas y episodios de $titleId', cause: e);
    }
  }

  /// Consulta el feed de cambios incrementales a partir de una revisión dada.
  Future<List<CatalogChangeDto>> fetchChanges({
    required int sinceRevision,
    int limit = 200,
  }) async {
    try {
      final List<dynamic> rows = await _effectiveClient
          .from('catalog_changes')
          .select('revision, entity_type, entity_id, operation, changed_at')
          .gt('revision', sinceRevision)
          .order('revision', ascending: true)
          .limit(limit);

      return rows
          .map((r) => CatalogChangeDto.fromJson(r as Map<String, dynamic>))
          .toList();
    } catch (e) {
      if (e is CatalogNetworkException) rethrow;
      throw CatalogNetworkException('Error al consultar cambios del catálogo desde revisión $sinceRevision', cause: e);
    }
  }

  /// Consulta los metadatos de sincronización (latest y minimum_available).
  Future<CatalogSyncMetadataDto> fetchSyncMetadata() async {
    try {
      final data = await _effectiveClient
          .from('catalog_sync_metadata')
          .select('id, minimum_available_revision, latest_revision, updated_at')
          .eq('id', 1)
          .single();

      return CatalogSyncMetadataDto.fromJson(data);
    } catch (e) {
      if (e is CatalogNetworkException) rethrow;
      throw CatalogNetworkException('Error al consultar metadatos de sincronización', cause: e);
    }
  }

  /// Descarga un snapshot completo de títulos publicados (usado para Full Resync tras compactación).
  Future<List<CatalogSummaryDto>> fetchCompleteSnapshot({
    int offset = 0,
    int limit = 500,
  }) async {
    try {
      final List<dynamic> rows = await _effectiveClient
          .from('titles')
          .select('''
            id, legacy_id, title, normalized_title, media_type,
            poster_url, backdrop_url, year, rating, is_featured, created_at,
            title_genres (
              genres (slug, name)
            )
          ''')
          .eq('is_published', true)
          .order('created_at', ascending: false)
          .order('id', ascending: false)
          .range(offset, offset + limit - 1);

      return rows
          .map((r) => CatalogSummaryDto.fromJson(r as Map<String, dynamic>))
          .toList();
    } catch (e) {
      if (e is CatalogNetworkException) rethrow;
      throw CatalogNetworkException('Error al descargar snapshot de catálogo en offset $offset', cause: e);
    }
  }
}
