import 'package:flutter_test/flutter_test.dart';
import 'package:streamtv/database/catalog_database.dart';
import 'package:streamtv/database/daos/user_data_dao.dart';

void main() {
  late CatalogDatabase db;
  late UserDataDao dao;

  setUp(() {
    db = CatalogDatabase.inMemory();
    dao = db.userDataDao;
  });

  tearDown(() async {
    await db.close();
  });

  group('UserDataDao & UserDataTables Tests', () {
    test('1. Permite alternar y consultar favoritos para perfiles y modo invitado', () async {
      final now = DateTime.utc(2026, 9, 12, 10, 0, 0);

      // Perfil normal
      await dao.setFavorite(
        profileId: 'p-1',
        contentKey: 'movie:101',
        titleId: 'title-101',
        isFavorite: true,
        updatedAt: now,
      );

      var isFav = await dao.isFavorite('p-1', 'movie:101');
      expect(isFav, isTrue);

      var favs = await dao.getFavorites('p-1');
      expect(favs.length, equals(1));
      expect(favs.first.contentKey, equals('movie:101'));

      // Modo invitado
      await dao.setFavorite(
        profileId: 'guest',
        contentKey: 'movie:999',
        isFavorite: true,
        updatedAt: now,
      );

      var isGuestFav = await dao.isFavorite('guest', 'movie:999');
      expect(isGuestFav, isTrue);

      // Aislamiento entre perfiles
      var isP1GuestFav = await dao.isFavorite('p-1', 'movie:999');
      expect(isP1GuestFav, isFalse);
    });

    test('2. Registra progreso de reproduccion y lista Continue Watching excluyendo completados', () async {
      final t1 = DateTime.utc(2026, 9, 12, 12, 0, 0);
      final t2 = DateTime.utc(2026, 9, 12, 13, 0, 0);

      // Progreso 1: En curso (50%)
      await dao.upsertProgress(
        profileId: 'p-1',
        contentKey: 'movie:1',
        positionMs: 3600000,
        durationMs: 7200000,
        fraction: 0.5,
        isCompleted: false,
        lastWatchedAt: t1,
        updatedAt: t1,
      );

      // Progreso 2: Completado (95%)
      await dao.upsertProgress(
        profileId: 'p-1',
        contentKey: 'movie:2',
        positionMs: 6840000,
        durationMs: 7200000,
        fraction: 0.95,
        isCompleted: true,
        lastWatchedAt: t2,
        updatedAt: t2,
      );

      final continueWatching = await dao.getContinueWatching('p-1');
      expect(continueWatching.length, equals(1));
      expect(continueWatching.first.contentKey, equals('movie:1'));
      expect(continueWatching.first.positionMs, equals(3600000));
    });

    test('3. Mantiene historial limitado deterministamente a 500 entradas', () async {
      final baseDate = DateTime.utc(2026, 9, 12, 0, 0, 0);

      for (int i = 1; i <= 25; i++) {
        await dao.addHistoryEntry(
          id: 'hist-$i',
          profileId: 'p-1',
          playbackSessionId: 'sess-$i',
          contentKey: 'item:$i',
          stoppedAtMs: i * 1000,
          durationMs: 100000,
          fraction: 0.1,
          isCompleted: false,
          watchedAt: baseDate.add(Duration(minutes: i)),
        );
      }

      var history = await dao.getHistory('p-1', limit: 50);
      expect(history.length, equals(25));
      expect(history.first.contentKey, equals('item:25')); // Más reciente primero

      // Podar a max 10
      await dao.pruneHistory('p-1', maxEntries: 10);
      history = await dao.getHistory('p-1', limit: 50);
      expect(history.length, equals(10));
      expect(history.first.contentKey, equals('item:25'));
      expect(history.last.contentKey, equals('item:16'));
    });

    test('4. Cola de sincronizacion asigna secuencias monotonicas y preserva orden', () async {
      final now = DateTime.utc(2026, 9, 12, 14, 0, 0);

      final seq1 = await dao.getNextSequence('p-1', 'dev-A');
      expect(seq1, equals(1));

      await dao.enqueueOperation(
        operationId: 'op-1',
        profileId: 'p-1',
        deviceId: 'dev-A',
        clientSequence: seq1,
        operationType: 'favorite_add',
        contentKey: 'movie:1',
        payload: '{}',
        clientTimestamp: now,
      );

      final seq2 = await dao.getNextSequence('p-1', 'dev-A');
      expect(seq2, equals(2));

      await dao.enqueueOperation(
        operationId: 'op-2',
        profileId: 'p-1',
        deviceId: 'dev-A',
        clientSequence: seq2,
        operationType: 'restart',
        contentKey: 'movie:1',
        payload: '{"duration_ms": 7200000}',
        clientTimestamp: now.add(const Duration(seconds: 1)),
      );

      final pending = await dao.getPendingOperations('p-1');
      expect(pending.length, equals(2));
      expect(pending[0].operationId, equals('op-1'));
      expect(pending[1].operationId, equals('op-2'));

      // Marcar en vuelo y eliminar aplicadas
      await dao.updateOperationStatus('op-1', 'applied');
      await dao.removeOperations(['op-1']);

      final remaining = await dao.getPendingOperations('p-1');
      expect(remaining.length, equals(1));
      expect(remaining.first.operationId, equals('op-2'));
    });

    test('5. Checkpoint de sincronizacion guarda y actualiza ultima revision de 64 bits', () async {
      const largeRev = 9876543210;
      final now = DateTime.utc(2026, 9, 12, 15, 0, 0);

      await dao.updateCheckpoint(
        'p-1',
        latestServerRevision: largeRev,
        lastSyncedAt: now,
        lastSuccessfulSequence: 10,
      );

      final cp = await dao.getCheckpoint('p-1');
      expect(cp, isNotNull);
      expect(cp!.latestServerRevision, equals(largeRev));
      expect(cp.lastSuccessfulSequence, equals(10));
    });

    test('6. Auditoria de importacion de Invitado registra lotes idempotentes', () async {
      final now = DateTime.utc(2026, 9, 12, 16, 0, 0);

      await dao.upsertGuestImportAudit(
        id: 'audit-1',
        targetProfileId: 'p-1',
        importBatchId: 'batch-1',
        status: 'in_progress',
        favoritesCount: 5,
        progressCount: 2,
        historyCount: 10,
        createdAt: now,
      );

      var audit = await dao.getGuestImportAudit('p-1', 'batch-1');
      expect(audit, isNotNull);
      expect(audit!.status, equals('in_progress'));

      await dao.upsertGuestImportAudit(
        id: 'audit-1',
        targetProfileId: 'p-1',
        importBatchId: 'batch-1',
        status: 'completed',
        favoritesCount: 5,
        progressCount: 2,
        historyCount: 10,
        createdAt: now,
        completedAt: now.add(const Duration(seconds: 2)),
      );

      audit = await dao.getGuestImportAudit('p-1', 'batch-1');
      expect(audit!.status, equals('completed'));
    });
  });
}
