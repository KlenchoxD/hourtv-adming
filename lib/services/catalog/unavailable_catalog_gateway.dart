import 'catalog_cursor.dart';
import 'catalog_dtos.dart';
import 'supabase_catalog_gateway.dart';

/// Implementación segura y limpia para entornos donde Supabase no está configurado,
/// está deshabilitado o no está disponible.
///
/// Previene accesos ilegítimos a `Supabase.instance.client` y rechaza operaciones
/// de red remotas de forma determinista con `CatalogNetworkException`.
class UnavailableCatalogGateway extends SupabaseCatalogGateway {
  UnavailableCatalogGateway() : super(null);

  @override
  Future<CatalogSyncMetadataDto> fetchSyncMetadata() async {
    throw const CatalogNetworkException('Supabase no está disponible.');
  }

  @override
  Future<List<CatalogChangeDto>> fetchChanges({
    required int sinceRevision,
    int limit = 100,
  }) async {
    throw const CatalogNetworkException('Supabase no está disponible.');
  }

  @override
  Future<CatalogPageResult<CatalogSummaryDto>> fetchTitlesPage({
    CatalogCursor? cursor,
    int limit = 20,
    String? mediaType,
    String? genreSlug,
    CatalogSortOrder sort = CatalogSortOrder.recent,
  }) async {
    throw const CatalogNetworkException('Supabase no está disponible.');
  }

  @override
  Future<CatalogDetailDto?> fetchTitleDetails(String titleId) async {
    throw const CatalogNetworkException('Supabase no está disponible.');
  }

  @override
  Future<List<CatalogSourceDto>> fetchTitleSources(String titleId) async {
    throw const CatalogNetworkException('Supabase no está disponible.');
  }

  @override
  Future<List<CatalogSeasonDto>> fetchSeriesEpisodes(String titleId) async {
    throw const CatalogNetworkException('Supabase no está disponible.');
  }

  @override
  Future<List<CatalogSummaryDto>> fetchCompleteSnapshot({
    int limit = 200,
    int offset = 0,
  }) async {
    throw const CatalogNetworkException('Supabase no está disponible.');
  }
}
