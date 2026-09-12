import 'package:flutter_test/flutter_test.dart';
import 'package:streamtv/database/catalog_database.dart';
import 'package:streamtv/database/daos/user_data_dao.dart';
import 'package:streamtv/services/sync/profile_sync_engine.dart';
import 'package:streamtv/services/sync/profile_sync_gateway.dart';

class MockProfileSyncGateway implements ProfileSyncGateway {
  List<Map<String, dynamic>> lastPushedOperations = [];
  bool throwOnPush = false;
  bool returnFullResyncOnPull = false;
  int pullSinceRevisionReceived = 0;
  List<Map<String, dynamic>> operationsToReturnOnPull = [];
  Map<String, dynamic>? snapshotToReturn;

  @override
  Future<List<Map<String, dynamic>>> pushOperations(
    String profileId,
    List<Map<String, dynamic>> operations,
  ) async {
    if (throwOnPush) {
      throw Exception('Network error');
    }
    lastPushedOperations = operations;
    return operations.map((op) {
      return {
        'operation_id': op['operation_id'],
        'status': 'applied',
        'server_revision': 100,
      };
    }).toList();
  }

  @override
  Future<Map<String, dynamic>> pullChanges(
    String profileId, {
    int sinceRevision = 0,
    int limit = 100,
  }) async {
    pullSinceRevisionReceived = sinceRevision;
    if (returnFullResyncOnPull) {
      return {
        'profile_id': profileId,
        'latest_revision': 500,
        'minimum_available_revision': 200,
        'full_resync_required': true,
        'has_more': false,
        'next_cursor': 500,
        'operations': [],
      };
    }

    final maxRev = operationsToReturnOnPull.isNotEmpty
        ? (operationsToReturnOnPull.last['server_revision'] as num).toInt()
        : sinceRevision;

    return {
      'profile_id': profileId,
      'latest_revision': maxRev,
      'minimum_available_revision': 0,
      'full_resync_required': false,
      'has_more': false,
      'next_cursor': maxRev,
      'operations': operationsToReturnOnPull,
    };
  }

  @override
  Future<Map<String, dynamic>> getProfileSnapshot(String profileId) async {
    return snapshotToReturn ??
        {
          'profile_id': profileId,
          'snapshot_revision': 500,
          'favorites': [
            {
              'content_key': 'movie:snapshot_fav',
              'title_id': null,
              'is_favorite': true,
              'server_revision': 450,
            }
          ],
          'progress': [
            {
              'content_key': 'movie:snapshot_prog',
              'playback_session_id': 'sess-snap',
              'title_id': null,
              'episode_id': null,
              'position_ms': 5000,
              'duration_ms': 10000,
              'fraction': 0.5,
              'is_completed': false,
              'last_watched_at': '2026-09-12T10:00:00Z',
              'updated_at': '2026-09-12T10:00:00Z',
              'server_revision': 460,
            }
          ],
          'history': [],
          'preferences': null,
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
  late MockProfileSyncGateway gateway;
  late ProfileSyncEngine engine;

  setUp(() {
    db = CatalogDatabase.inMemory();
    dao = db.userDataDao;
    gateway = MockProfileSyncGateway();
    engine = ProfileSyncEngine(
      userDataDao: dao,
      gateway: gateway,
      deviceId: 'device-test-1',
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('ProfileSyncEngine Tests', () {
    test('1. Push de operaciones pendientes se envia por lote y limpia cola local', () async {
      final now = DateTime.utc(2026, 9, 12, 12, 0, 0);

      await dao.enqueueOperation(
        operationId: 'op-push-1',
        profileId: 'p-1',
        deviceId: 'device-test-1',
        clientSequence: 1,
        operationType: 'favorite_add',
        contentKey: 'movie:99',
        payload: '{}',
        clientTimestamp: now,
      );

      await dao.enqueueOperation(
        operationId: 'op-push-2',
        profileId: 'p-1',
        deviceId: 'device-test-1',
        clientSequence: 2,
        operationType: 'restart',
        contentKey: 'movie:99',
        payload: '{"duration_ms": 7200000}',
        clientTimestamp: now,
      );

      final result = await engine.pushPendingOperations('p-1');
      expect(result.sentCount, equals(2));
      expect(result.appliedCount, equals(2));
      expect(gateway.lastPushedOperations.length, equals(2));

      final remaining = await dao.getPendingOperations('p-1');
      expect(remaining.isEmpty, isTrue);
    });

    test('2. Pull incremental materializa cambios locales y actualiza checkpoint', () async {
      gateway.operationsToReturnOnPull = [
        {
          'operation_id': 'op-remote-1',
          'device_id': 'dev-remote',
          'client_sequence': 1,
          'operation_type': 'favorite_add',
          'apply_status': 'applied',
          'content_key': 'movie:remote_1',
          'payload': {},
          'server_revision': 15,
          'server_received_at': '2026-09-12T12:05:00Z',
        }
      ];

      await engine.pullRemoteChanges('p-1');

      final isFav = await dao.isFavorite('p-1', 'movie:remote_1');
      expect(isFav, isTrue);

      final cp = await dao.getCheckpoint('p-1');
      expect(cp, isNotNull);
      expect(cp!.latestServerRevision, equals(15));
    });

    test('3. Pull incremental omite materializar operaciones con apply_status ignored_stale', () async {
      // Estado local actual
      await dao.upsertProgress(
        profileId: 'p-1',
        contentKey: 'movie:conflict',
        playbackSessionId: 'sess-active',
        positionMs: 100,
        durationMs: 1000,
        fraction: 0.1,
        isCompleted: false,
        lastWatchedAt: DateTime.utc(2026, 9, 12, 13, 0, 0),
        updatedAt: DateTime.utc(2026, 9, 12, 13, 0, 0),
      );

      gateway.operationsToReturnOnPull = [
        {
          'operation_id': 'op-stale-1',
          'device_id': 'dev-stale',
          'client_sequence': 4,
          'operation_type': 'progress_update',
          'apply_status': 'ignored_stale',
          'content_key': 'movie:conflict',
          'playback_session_id': 'sess-stale',
          'payload': {'position_ms': 999, 'duration_ms': 1000},
          'server_revision': 20,
          'server_received_at': '2026-09-12T13:01:00Z',
        }
      ];

      await engine.pullRemoteChanges('p-1');

      final prog = await dao.getProgress('p-1', 'movie:conflict');
      expect(prog!.playbackSessionId, equals('sess-active'));
      expect(prog.positionMs, equals(100)); // No fue degradado por la operación stale
    });

    test('4. Full resync requerido solicita snapshot consistente y lo aplica atomicamente', () async {
      gateway.returnFullResyncOnPull = true;

      await engine.pullRemoteChanges('p-1');

      final isFav = await dao.isFavorite('p-1', 'movie:snapshot_fav');
      expect(isFav, isTrue);

      final prog = await dao.getProgress('p-1', 'movie:snapshot_prog');
      expect(prog, isNotNull);
      expect(prog!.positionMs, equals(5000));

      final cp = await dao.getCheckpoint('p-1');
      expect(cp!.latestServerRevision, equals(500));
    });

    test('5. Modo Invitado no sincroniza remotamente y se mantiene 100% offline', () async {
      final now = DateTime.utc(2026, 9, 12, 14, 0, 0);

      await engine.recordFavorite(
        profileId: 'guest',
        contentKey: 'movie:guest_local',
        isFavorite: true,
        updatedAt: now,
      );

      final isGuestFav = await dao.isFavorite('guest', 'movie:guest_local');
      expect(isGuestFav, isTrue);

      final result = await engine.syncProfile('guest');
      expect(result.skippedGuest, isTrue);
      expect(gateway.lastPushedOperations.isEmpty, isTrue);
    });

    test('6. Fallo de red conserva la cola en estado failed para posterior reintento', () async {
      final now = DateTime.utc(2026, 9, 12, 15, 0, 0);

      await dao.enqueueOperation(
        operationId: 'op-fail-1',
        profileId: 'p-1',
        deviceId: 'device-test-1',
        clientSequence: 1,
        operationType: 'favorite_add',
        contentKey: 'movie:fail',
        payload: '{}',
        clientTimestamp: now,
      );

      gateway.throwOnPush = true;

      final result = await engine.pushPendingOperations('p-1');
      expect(result.hasError, isTrue);

      final pending = await dao.getPendingOperations('p-1');
      expect(pending.length, equals(1));
      expect(pending.first.status, equals('failed'));
      expect(pending.first.retryCount, equals(1));
    });
  });
}
