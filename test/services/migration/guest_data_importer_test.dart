import 'package:flutter_test/flutter_test.dart';
import 'package:streamtv/database/catalog_database.dart';
import 'package:streamtv/database/daos/user_data_dao.dart';
import 'package:streamtv/services/migration/guest_data_importer.dart';
import 'package:streamtv/services/sync/profile_sync_engine.dart';

void main() {
  late CatalogDatabase db;
  late UserDataDao dao;
  late ProfileSyncEngine syncEngine;
  late GuestDataImporter importer;

  setUp(() {
    db = CatalogDatabase.inMemory();
    dao = db.userDataDao;
    syncEngine = ProfileSyncEngine(
      userDataDao: dao,
      deviceId: 'device-test-guest',
    );
    importer = GuestDataImporter(
      userDataDao: dao,
      syncEngine: syncEngine,
      deviceId: 'device-test-guest',
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('GuestDataImporter Tests', () {
    test('1. Inspecciona correctamente los datos existentes del modo invitado', () async {
      final now = DateTime.utc(2026, 9, 12, 10, 0, 0);

      // Crear datos de invitado
      await dao.setFavorite(
        profileId: 'guest',
        contentKey: 'movie:10',
        isFavorite: true,
        updatedAt: now,
      );

      await dao.upsertProgress(
        profileId: 'guest',
        contentKey: 'movie:20',
        positionMs: 3000,
        durationMs: 6000,
        fraction: 0.5,
        isCompleted: false,
        lastWatchedAt: now,
        updatedAt: now,
      );

      await dao.addHistoryEntry(
        id: 'hist-guest-1',
        profileId: 'guest',
        playbackSessionId: 'sess-guest-1',
        contentKey: 'movie:30',
        stoppedAtMs: 1000,
        durationMs: 5000,
        fraction: 0.2,
        isCompleted: false,
        watchedAt: now,
      );

      final summary = await importer.inspectGuestData();
      expect(summary.favoritesCount, equals(1));
      expect(summary.progressCount, equals(1));
      expect(summary.historyCount, equals(1));
      expect(summary.hasData, isTrue);
    });

    test('2. Importa datos a perfil destino de forma no destructiva preservando el modo invitado', () async {
      final now = DateTime.utc(2026, 9, 12, 11, 0, 0);

      await dao.setFavorite(
        profileId: 'guest',
        contentKey: 'movie:10',
        isFavorite: true,
        updatedAt: now,
      );

      await dao.upsertProgress(
        profileId: 'guest',
        contentKey: 'movie:20',
        positionMs: 3000,
        durationMs: 6000,
        fraction: 0.5,
        isCompleted: false,
        lastWatchedAt: now,
        updatedAt: now,
      );

      final result = await importer.importGuestData(targetProfileId: 'target-profile-1');
      expect(result.success, isTrue);
      expect(result.favoritesImported, equals(1));
      expect(result.progressImported, equals(1));

      // Verificar que el perfil destino tiene los datos
      final isTargetFav = await dao.isFavorite('target-profile-1', 'movie:10');
      expect(isTargetFav, isTrue);

      final targetProg = await dao.getProgress('target-profile-1', 'movie:20');
      expect(targetProg, isNotNull);
      expect(targetProg!.positionMs, equals(3000));

      // Verificar NO DESTRUCTIVIDAD: el invitado todavía tiene sus datos
      final isGuestFav = await dao.isFavorite('guest', 'movie:10');
      expect(isGuestFav, isTrue);

      final guestProg = await dao.getProgress('guest', 'movie:20');
      expect(guestProg, isNotNull);
      expect(guestProg!.positionMs, equals(3000));
    });

    test('3. Importacion idempotente con el mismo lote no duplica registros', () async {
      final now = DateTime.utc(2026, 9, 12, 12, 0, 0);

      await dao.setFavorite(
        profileId: 'guest',
        contentKey: 'movie:10',
        isFavorite: true,
        updatedAt: now,
      );

      // Primera importación
      final res1 = await importer.importGuestData(targetProfileId: 'target-profile-1');
      expect(res1.success, isTrue);

      // Segunda importación (idempotente)
      final res2 = await importer.importGuestData(targetProfileId: 'target-profile-1');
      expect(res2.success, isTrue);

      final favs = await dao.getFavorites('target-profile-1');
      expect(favs.length, equals(1)); // Sin duplicados

      final audit = await dao.getGuestImportAudit('target-profile-1', res1.importBatchId);
      expect(audit, isNotNull);
      expect(audit!.status, equals('completed'));
    });
  });
}
