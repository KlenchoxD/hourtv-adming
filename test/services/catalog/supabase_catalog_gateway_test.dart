import 'package:flutter_test/flutter_test.dart';
import 'package:streamtv/services/catalog/catalog_cursor.dart';
import 'package:streamtv/services/catalog/catalog_dtos.dart';
import 'package:streamtv/services/catalog/supabase_catalog_gateway.dart';

void main() {
  group('Supabase Catalog Gateway & DTOs Tests', () {
    test('1. CatalogCursor encode y tryDecode con base64url', () {
      final date = DateTime.utc(2026, 9, 10, 15, 30, 45, 123);
      const id = '0191db72-abcd-7000-8000-000000000001';

      final cursor = CatalogCursor(createdAt: date, id: id);
      final encoded = cursor.encode();

      expect(encoded, isNotEmpty);
      expect(encoded.contains('/'), isFalse); // base64url seguro

      final decoded = CatalogCursor.tryDecode(encoded);
      expect(decoded, isNotNull);
      expect(decoded!.createdAt, equals(date));
      expect(decoded.id, equals(id));

      // Strings corruptos o vacíos retornan null
      expect(CatalogCursor.tryDecode(null), isNull);
      expect(CatalogCursor.tryDecode(''), isNull);
      expect(CatalogCursor.tryDecode('invalido-no-base64'), isNull);
      expect(CatalogCursor.tryDecode('bm90LXNwZWNpZmlj'), isNull); // not-specific sin separador '|'
    });

    test('2. Construcción determinista del filtro PostgREST de cursor compuesto', () {
      final date = DateTime.utc(2026, 9, 10, 15, 30, 45, 0);
      const id = 'test-id-123';
      final cursor = CatalogCursor(createdAt: date, id: id);

      final filter = SupabaseCatalogGateway.buildCompositeCursorFilter(cursor);
      expect(
        filter,
        equals(
          'created_at.lt.2026-09-10T15:30:45.000Z,and(created_at.eq.2026-09-10T15:30:45.000Z,id.lt.test-id-123)',
        ),
      );
    });

    test('3. Mapeo de CatalogChangeDto con claves simples y compuestas', () {
      final changeJson = {
        'revision': 5000000000,
        'entity_type': 'title_genre',
        'entity_id': 'title-123:genre-456',
        'operation': 'upsert',
        'changed_at': '2026-09-10T16:00:00.000Z',
      };

      final change = CatalogChangeDto.fromJson(changeJson);
      expect(change.revision, equals(5000000000));
      expect(change.entityType, equals('title_genre'));
      expect(change.entityId, equals('title-123:genre-456'));
      expect(change.operation, equals('upsert'));
      expect(change.changedAt, equals(DateTime.utc(2026, 9, 10, 16, 0, 0)));
    });

    test('4. Mapeo de CatalogSyncMetadataDto', () {
      final metaJson = {
        'id': 1,
        'minimum_available_revision': 100,
        'latest_revision': 5000000000,
        'updated_at': '2026-09-10T16:00:00.000Z',
      };

      final meta = CatalogSyncMetadataDto.fromJson(metaJson);
      expect(meta.minimumAvailableRevision, equals(100));
      expect(meta.latestRevision, equals(5000000000));
    });

    test('5. Mapeo de CatalogSummaryDto con agregación de géneros', () {
      final summaryJson = {
        'id': 'uuid-1',
        'legacy_id': 'ch-1',
        'title': 'Test Movie',
        'normalized_title': 'test movie',
        'media_type': 'movie',
        'poster_url': 'https://image.tmdb.org/poster.jpg',
        'backdrop_url': 'https://image.tmdb.org/backdrop.jpg',
        'year': 2026,
        'rating': 8.5,
        'is_featured': true,
        'created_at': '2026-09-10T12:00:00.000Z',
        'title_genres': [
          {'genres': {'slug': 'action', 'name': 'Acción'}},
          {'genres': {'slug': 'sci-fi', 'name': 'Ciencia Ficción'}},
        ],
      };

      final summary = CatalogSummaryDto.fromJson(summaryJson);
      expect(summary.id, equals('uuid-1'));
      expect(summary.legacyId, equals('ch-1'));
      expect(summary.title, equals('Test Movie'));
      expect(summary.mediaType, equals('movie'));
      expect(summary.isFeatured, isTrue);
      expect(summary.genres, equals(['action', 'sci-fi']));
    });

    test('6. CatalogNetworkException envuelve errores de red de PostgREST', () {
      final exception = CatalogNetworkException(
        'Fallo al consultar catálogo remoto',
        cause: Exception('SocketException: Connection refused'),
      );

      expect(exception.message, contains('Fallo al consultar catálogo remoto'));
      expect(exception.cause.toString(), contains('Connection refused'));
      expect(exception.toString(), contains('CatalogNetworkException: Fallo al consultar catálogo remoto'));
    });
  });
}
