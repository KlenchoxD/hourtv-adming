import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamtv/database/catalog_database.dart';
import 'package:streamtv/models/channel.dart';
import 'package:streamtv/services/content_store.dart';
import 'package:streamtv/services/playback_progress.dart';
import 'package:streamtv/services/storage_service.dart';
import 'package:streamtv/services/sync/profile_cloud_sync.dart';
import 'package:streamtv/services/sync/profile_sync_engine.dart';
import 'package:streamtv/services/sync/uuid_utils.dart';

const _profile = '33333333-3333-4333-8333-333333333333';

Map<String, dynamic>? _op(
  String type,
  String payload, {
  String? session,
  String? titleId,
}) => ProfileSyncEngine.toServerOperation(
  profileId: _profile,
  operationId: UuidUtils.v4(),
  deviceId: 'dev',
  clientSequence: 1,
  operationType: type,
  contentKey: 'movie:coco',
  playbackSessionId: session,
  titleId: titleId,
  payload: payload,
  clientTimestamp: DateTime.utc(2026, 9, 27),
);

void main() {
  group('Contrato con push_profile_operations', () {
    test('sesión en formato UUID y sin title_id', () {
      final op = _op(
        'progress_update',
        '{"position_ms":90000,"duration_ms":6000000}',
        session: 'sess_Coco',
        titleId: 'catalog:abc',
      )!;
      expect(UuidUtils.isUuid(op['playback_session_id'] as String), isTrue);
      expect(op.containsKey('title_id'), isFalse);
      // Misma sesión estable para el mismo perfil y título.
      final again = _op(
        'progress_update',
        '{"position_ms":95000,"duration_ms":6000000}',
      )!;
      expect(again['playback_session_id'], op['playback_session_id']);
    });

    test('historial: history_append con position_ms, y solo si pasó 1 min', () {
      final op = _op(
        'history_add',
        '{"history_id":"x","stopped_at_ms":120000,"duration_ms":6000000,"is_completed":false}',
      )!;
      expect(op['operation_type'], 'history_append');
      expect(op['payload'], {'position_ms': 120000, 'duration_ms': 6000000});
      expect(
        _op('history_add', '{"stopped_at_ms":30000,"duration_ms":6000000}'),
        isNull,
      );
    });

    test('preferencias: solo claves que el servidor acepta', () {
      final op = _op(
        'preferences_update',
        '{"preferred_audio_language":"es","auto_play_next":true}',
      )!;
      expect(op['payload'], {'preferred_audio_language': 'es'});
      expect(_op('preferences_update', '{"auto_play_next":true}'), isNull);
    });
  });

  test('la secuencia sigue creciendo aunque la cola se vacíe', () async {
    final db = CatalogDatabase.inMemory();
    addTearDown(db.close);
    final dao = db.userDataDao;
    final first = await dao.getNextSequence(_profile, 'dev');
    await dao.enqueueOperation(
      operationId: 'a',
      profileId: _profile,
      deviceId: 'dev',
      clientSequence: first,
      operationType: 'favorite_add',
      contentKey: 'movie:1',
      payload: '{}',
      clientTimestamp: DateTime.utc(2026),
    );
    await dao.removeOperations(['a']);
    expect(await dao.getNextSequence(_profile, 'dev'), greaterThan(first));
  });

  test(
    'lo que llega de otro equipo aparece en favoritos y Continuar viendo',
    () async {
      SharedPreferences.setMockInitialValues({});
      await StorageService.init();
      final db = CatalogDatabase.inMemory();
      addTearDown(db.close);
      final dao = db.userDataDao;

      final coco = Channel(
        name: 'Coco',
        url: 'https://cdn/movie/coco.mp4',
        catalogTitleId: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      );
      final moana = Channel(
        name: 'Moana',
        url: 'https://cdn/movie/moana.mp4',
        catalogTitleId: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
      );
      ContentStore.instance.resetForTesting();
      ContentStore.instance.all = [coco, moana];

      // Lo que dejó el pull (otro teléfono): Coco en favoritos y Moana a
      // medias.
      final when = DateTime.utc(2026, 9, 27, 20);
      await dao.setFavorite(
        profileId: _profile,
        contentKey: PlaybackProgress.contentKey(coco),
        isFavorite: true,
        updatedAt: when,
      );
      await dao.upsertProgress(
        profileId: _profile,
        contentKey: PlaybackProgress.contentKey(moana),
        positionMs: 1800000,
        durationMs: 6000000,
        fraction: .3,
        isCompleted: false,
        lastWatchedAt: when,
        updatedAt: when,
      );

      expect(await ProfileCloudSync.apply(dao, _profile), isTrue);

      expect(
        StorageService.loadFavoritesFor(_profile).map((c) => c.name),
        ['Coco'],
      );
      final recent = StorageService.loadRecentFor(_profile);
      expect(recent.single.name, 'Moana');
      expect(recent.single.progressFraction, .3);
      final position = PlaybackProgress.positionsFor(
        _profile,
      )[PlaybackProgress.contentKey(moana)]!;
      expect(position.positionMs, 1800000);

      // Sin cambios nuevos: no reescribe nada.
      expect(await ProfileCloudSync.apply(dao, _profile), isFalse);
    },
  );

  test('sin posición exacta, estima con el porcentaje y la duración', () async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    final db = CatalogDatabase.inMemory();
    addTearDown(db.close);
    final engine = ProfileSyncEngine(
      userDataDao: db.userDataDao,
      deviceId: 'dev',
    );
    final emma = Channel(
      name: 'Emma.',
      url: 'https://cdn/movie/emma.mp4',
      duration: '100 min',
    )
      ..progressFraction = .25
      ..lastWatched = DateTime.utc(2026, 9, 20);
    await StorageService.saveRecentFor(_profile, [emma]);

    await ProfileCloudSync.backfill(engine, _profile);

    final row = await db.userDataDao.getProgress(
      _profile,
      PlaybackProgress.contentKey(emma),
    );
    expect(row, isNotNull);
    expect(row!.durationMs, 6000000);
    expect(row.positionMs, 1500000);
  });

  test('sync termina (no se queda esperándose a sí mismo)', () async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    final db = CatalogDatabase.inMemory();
    addTearDown(db.close);
    ProfileSyncEngine.setInstance(
      ProfileSyncEngine(userDataDao: db.userDataDao, deviceId: 'dev'),
    );
    addTearDown(() => ProfileSyncEngine.setInstance(null));
    await expectLater(
      ProfileCloudSync.sync(_profile).timeout(const Duration(seconds: 5)),
      completes,
    );
  });

  test('el historial propio que vuelve del servidor no se duplica', () async {
    final db = CatalogDatabase.inMemory();
    addTearDown(db.close);
    final dao = db.userDataDao;
    final when = DateTime.utc(2026, 9, 27, 21);
    Future<void> add(String id, {int? rev}) => dao.addHistoryEntry(
      id: id,
      profileId: _profile,
      playbackSessionId: 's',
      contentKey: 'movie:coco',
      stoppedAtMs: 120000,
      durationMs: 6000000,
      fraction: .02,
      isCompleted: false,
      watchedAt: when,
      serverRevision: rev,
    );
    await add('local-id');
    await add('server-op-id', rev: 7);
    expect(await dao.getHistory(_profile), hasLength(1));
  });
}
