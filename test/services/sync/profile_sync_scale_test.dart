import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamtv/database/catalog_database.dart';
import 'package:streamtv/database/daos/user_data_dao.dart';
import 'package:streamtv/services/sync/profile_sync_engine.dart';
import 'package:streamtv/services/sync/profile_sync_gateway.dart';
import 'package:streamtv/services/sync/uuid_utils.dart';

class MockScaleGateway implements ProfileSyncGateway {
  final Map<String, List<Map<String, dynamic>>> _serverLedger = {};
  final Map<String, int> _serverRevisions = {};

  @override
  Future<List<Map<String, dynamic>>> pushOperations(
    String profileId,
    List<Map<String, dynamic>> operations,
  ) async {
    _serverLedger.putIfAbsent(profileId, () => []);
    final currentRev = _serverRevisions[profileId] ?? 0;
    var nextRev = currentRev;

    final results = <Map<String, dynamic>>[];

    for (final op in operations) {
      nextRev++;
      final opId = op['operation_id']?.toString() ?? UuidUtils.v4();
      final record = {
        'id': UuidUtils.v4(),
        'profile_id': profileId,
        'operation_id': opId,
        'server_revision': nextRev,
        'apply_status': 'applied',
        'operation_type': op['operation_type'],
        'content_key': op['content_key'],
        'title_id': op['title_id'],
        'payload': op['payload'] ?? {},
      };
      _serverLedger[profileId]!.add(record);

      results.add({
        'operation_id': opId,
        'server_revision': nextRev,
        'apply_status': 'applied',
        'conflict_detected': false,
      });
    }

    _serverRevisions[profileId] = nextRev;
    return results;
  }

  @override
  Future<Map<String, dynamic>> pullChanges(
    String profileId, {
    int sinceRevision = 0,
    int limit = 100,
  }) async {
    final ledger = _serverLedger[profileId] ?? [];
    final filtered = ledger.where((op) => (op['server_revision'] as int) > sinceRevision).toList();
    final page = filtered.take(limit).toList();
    final latestRev = _serverRevisions[profileId] ?? 0;

    final nextCursor = page.isNotEmpty ? page.last['server_revision'] as int : sinceRevision;
    final hasMore = filtered.length > page.length;

    return {
      'operations': page,
      'has_more': hasMore,
      'next_cursor': nextCursor,
      'latest_revision': latestRev,
      'minimum_available_revision': 0,
      'full_resync_required': false,
    };
  }

  @override
  Future<Map<String, dynamic>> getProfileSnapshot(String profileId) async {
    return {
      'snapshot_revision': _serverRevisions[profileId] ?? 0,
      'favorites': [],
      'playback_progress': [],
      'history': [],
      'preferences': {},
    };
  }

  @override
  Future<void> updateGuestImportAudit({
    required String profileId,
    required String importBatchId,
    required String status,
    int favoritesCount = 0,
    int progressCount = 0,
    int historyCount = 0,
    String? errorMessage,
  }) async {}
}

void main() {
  late CatalogDatabase db;
  late UserDataDao dao;
  late MockScaleGateway scaleGateway;

  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  setUp(() {
    db = CatalogDatabase.inMemory();
    dao = db.userDataDao;
    scaleGateway = MockScaleGateway();
  });

  tearDown(() async {
    await db.close();
  });

  group('ProfileSync Massive Concurrency & Scale Tests (5 perfiles, 2 dispositivos c/u)', () {
    test('Concurrencia masiva entre 5 perfiles con 2 dispositivos independientes cada uno', () async {
      final futures = <Future<void>>[];
      final dbs = <CatalogDatabase>[];

      for (int p = 1; p <= 5; p++) {
        final profileId = 'profile-$p';
        final dbA = CatalogDatabase.inMemory();
        final dbB = CatalogDatabase.inMemory();
        dbs.add(dbA);
        dbs.add(dbB);

        // Dispositivo A del perfil
        final engineA = ProfileSyncEngine(
          userDataDao: dbA.userDataDao,
          gateway: scaleGateway,
          deviceId: 'device-$p-A',
        );

        // Dispositivo B del perfil
        final engineB = ProfileSyncEngine(
          userDataDao: dbB.userDataDao,
          gateway: scaleGateway,
          deviceId: 'device-$p-B',
        );

        // Cada dispositivo genera operaciones concurrentes
        futures.add(() async {
          for (int i = 1; i <= 10; i++) {
            await engineA.recordFavorite(
              profileId: profileId,
              contentKey: 'movie:scale-$p-A-$i',
              titleId: 'scale-$p-A-$i',
              isFavorite: true,
            );
          }
          final pushResA = await engineA.pushPendingOperations(profileId);
          expect(pushResA.hasError, isFalse);
          expect(pushResA.appliedCount, equals(10));
        }());

        futures.add(() async {
          for (int i = 1; i <= 10; i++) {
            await engineB.recordFavorite(
              profileId: profileId,
              contentKey: 'movie:scale-$p-B-$i',
              titleId: 'scale-$p-B-$i',
              isFavorite: true,
            );
          }
          final pushResB = await engineB.pushPendingOperations(profileId);
          expect(pushResB.hasError, isFalse);
          expect(pushResB.appliedCount, equals(10));
        }());
      }

      await Future.wait(futures);
      for (final d in dbs) {
        await d.close();
      }

      // Verificar que los 5 perfiles tienen exactamente 20 operaciones registradas en el servidor
      for (int p = 1; p <= 5; p++) {
        final profileId = 'profile-$p';
        final pull = await scaleGateway.pullChanges(profileId, sinceRevision: 0, limit: 100);
        final ops = pull['operations'] as List;
        expect(ops.length, equals(20));

        // Verificar que las revisiones del servidor son continuas y estrictamente monótonas
        int lastRev = 0;
        for (final op in ops) {
          final rev = op['server_revision'] as int;
          expect(rev, greaterThan(lastRev));
          lastRev = rev;
        }
      }
    });

    test('Paginacion keyset por lotes sin perdida ni duplicados bajo volumen alto', () async {
      final profileId = 'profile-keyset-test';
      final engine = ProfileSyncEngine(
        userDataDao: dao,
        gateway: scaleGateway,
        deviceId: 'device-keyset',
      );

      // Generar 150 operaciones
      for (int i = 1; i <= 150; i++) {
        await engine.recordFavorite(
          profileId: profileId,
          contentKey: 'movie:keyset-$i',
          isFavorite: true,
        );
      }
      await engine.pushPendingOperations(profileId, batchSize: 200);

      // Paginación con límite de 40 operaciones por página
      final retrievedOps = <Map<String, dynamic>>[];
      int cursor = 0;
      bool hasMore = true;

      while (hasMore) {
        final pull = await scaleGateway.pullChanges(profileId, sinceRevision: cursor, limit: 40);
        final ops = (pull['operations'] as List).cast<Map<String, dynamic>>();
        retrievedOps.addAll(ops);
        cursor = pull['next_cursor'] as int;
        hasMore = pull['has_more'] as bool;
      }

      expect(retrievedOps.length, equals(150));

      // Verificar que todos los contentKey son únicos
      final keys = retrievedOps.map((o) => o['content_key']).toSet();
      expect(keys.length, equals(150));
    });
  });
}
