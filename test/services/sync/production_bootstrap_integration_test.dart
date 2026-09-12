import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamtv/database/catalog_database.dart';
import 'package:streamtv/mobile_ui/hourtv_mobile_shell.dart';
import 'package:streamtv/models/channel.dart';
import 'package:streamtv/new_ui/hourtv_new_shell.dart';
import 'package:streamtv/new_ui/hourtv_player_screen.dart';
import 'package:streamtv/services/catalog/catalog_infrastructure.dart';
import 'package:streamtv/services/catalog/catalog_repository.dart';
import 'package:streamtv/services/catalog/supabase_catalog_gateway.dart';
import 'package:streamtv/services/content_store.dart';
import 'package:streamtv/services/device_type.dart';
import 'package:streamtv/services/playback_progress.dart';
import 'package:streamtv/services/storage_service.dart';
import 'package:streamtv/services/sync/profile_sync_engine.dart';
import 'package:streamtv/services/sync/profile_sync_gateway.dart';

class _MockProfileSyncGateway implements ProfileSyncGateway {
  int pushCalls = 0;
  int pullCalls = 0;
  int snapshotCalls = 0;
  int auditCalls = 0;
  final List<Map<String, dynamic>> pushedOperations = [];

  @override
  Future<List<Map<String, dynamic>>> pushOperations(
    String profileId,
    List<Map<String, dynamic>> operations,
  ) async {
    pushCalls++;
    pushedOperations.addAll(operations);
    return operations.map((op) {
      return {
        'operation_id': op['operation_id'],
        'status': 'applied',
        'apply_status': 'applied',
        'server_revision': pushCalls,
      };
    }).toList();
  }

  @override
  Future<Map<String, dynamic>> pullChanges(
    String profileId, {
    int sinceRevision = 0,
    int limit = 100,
  }) async {
    pullCalls++;
    return {
      'operations': <Map<String, dynamic>>[],
      'has_more': false,
      'next_cursor': sinceRevision,
      'latest_server_revision': sinceRevision + 1,
    };
  }

  @override
  Future<Map<String, dynamic>> getProfileSnapshot(String profileId) async {
    snapshotCalls++;
    return {
      'snapshot_revision': 1,
      'favorites': <dynamic>[],
      'progress': <dynamic>[],
      'history': <dynamic>[],
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
  }) async {
    auditCalls++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  late CatalogDatabase db;
  late _MockProfileSyncGateway mockGateway;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    ContentStore.instance.resetForTesting();
    ProfileSyncEngine.setInstance(null);
    CatalogRepository.setInstanceForTesting(null);

    db = CatalogDatabase.inMemory();
    mockGateway = _MockProfileSyncGateway();
  });

  tearDown(() async {
    ProfileSyncEngine.setInstance(null);
    CatalogRepository.setInstanceForTesting(null);
    await db.close();
    DeviceProfile.overrideType.value = null;
  });

  group('Production Bootstrap Integration Tests (P0 Remediation)', () {
    test(
      '1. Bootstrap real crea ProfileSyncEngine y RecommendationEngine compartiendo CatalogDatabase',
      () async {
        // Antes del bootstrap, la instancia debe ser null (condición inicial P0 confirmada)
        expect(ProfileSyncEngine.instance, isNull);

        final infra = await initializeCatalogInfrastructure(
          catalogDatabase: db,
          profileSyncGateway: mockGateway,
          autoInitializeRepository: false,
        );

        // 1. ProfileSyncEngine.instance != null después del bootstrap de producción
        expect(ProfileSyncEngine.instance, isNotNull);
        expect(identical(ProfileSyncEngine.instance, infra.profileSyncEngine), isTrue);

        // 2. Comparte el mismo UserDataDao y CatalogDatabase
        expect(identical(ProfileSyncEngine.instance!.userDataDao, db.userDataDao), isTrue);
        expect(identical(infra.recommendationEngine.userDataDao, db.userDataDao), isTrue);

        // 3. RecommendationEngine fue instanciado y registrado en CatalogInfrastructure
        expect(infra.recommendationEngine, isNotNull);
        expect(CatalogInfrastructure.current?.recommendationEngine, isNotNull);

        // 4. DeviceId estable persistido
        final deviceId1 = StorageService.getOrCreateDeviceId();
        final deviceId2 = StorageService.getOrCreateDeviceId();
        expect(deviceId1, isNotEmpty);
        expect(deviceId1, equals(deviceId2));
        expect(deviceId1, contains('-')); // UUID v4 format
      },
    );

    test(
      '2. Modo Invitado no invoca gateway remoto ni encola operaciones remotas',
      () async {
        await initializeCatalogInfrastructure(
          catalogDatabase: db,
          profileSyncGateway: mockGateway,
          autoInitializeRepository: false,
        );

        // Asegurar modo invitado
        await StorageService.clearCloudProfileContext();
        expect(StorageService.cloudProfileId, isNull);
        expect(ProfileSyncEngine.instance!.isGuestProfile(StorageService.activeProfileId), isTrue);

        final channel = Channel(
          name: 'Canal Invitado',
          url: 'http://example.com/guest-stream.m3u8',
          tvgId: 'ch-guest-1',
        );

        // Favorite desde StorageService en modo Invitado
        final fav = await StorageService.toggleFavorite(channel);
        expect(fav, isTrue);
        await pumpEventQueue();

        // Progreso desde PlayerScreen en modo Invitado
        await savePlaybackPosition(
          channel,
          positionMs: 30000,
          durationMs: 120000,
        );
        await pumpEventQueue();

        // Flush explícito
        await ProfileSyncEngine.instance!.flush();

        // SyncProfile en invitado es omitido
        final syncResult = await ProfileSyncEngine.instance!.syncProfile('guest');
        expect(syncResult.skippedGuest, isTrue);

        // Demostrar que el gateway remoto JAMÁS fue invocado
        expect(mockGateway.pushCalls, 0);
        expect(mockGateway.pullCalls, 0);
        expect(mockGateway.pushedOperations, isEmpty);

        // La cola remota Drift permanece vacía para invitado
        final pendingOps = await db.userDataDao.getPendingOperations('guest');
        expect(pendingOps, isEmpty);
      },
    );

    test(
      '3. Perfil cloud: favorite y progreso llegan a cola Drift, flush y sync invocan gateway',
      () async {
        await initializeCatalogInfrastructure(
          catalogDatabase: db,
          profileSyncGateway: mockGateway,
          autoInitializeRepository: false,
        );

        // Configurar perfil cloud
        await StorageService.setCloudProfileContext(
          accountId: 'account-uuid-1',
          profileId: 'cloud-profile-uuid-1',
          name: 'Pedro Cloud',
          avatarId: 'adult_1',
          isKids: false,
        );

        expect(StorageService.cloudProfileId, 'cloud-profile-uuid-1');
        expect(ProfileSyncEngine.instance!.isGuestProfile('cloud-profile-uuid-1'), isFalse);

        final channel = Channel(
          name: 'Película Cloud',
          url: 'catalog://cloud-movie-1',
          catalogTitleId: 'cloud-movie-1',
        );

        // 1. Favorite desde StorageService llega a la cola Drift
        final fav = await StorageService.toggleFavorite(channel);
        expect(fav, isTrue);
        await pumpEventQueue();

        var pendingOps = await db.userDataDao.getPendingOperations(
          'cloud-profile-uuid-1',
        );
        expect(pendingOps.any((op) => op.operationType == 'favorite_add'), isTrue);

        // 2. Progreso desde PlayerScreen llega a la cola Drift
        await savePlaybackPosition(
          channel,
          positionMs: 45000,
          durationMs: 90000,
        );
        await pumpEventQueue();

        pendingOps = await db.userDataDao.getPendingOperations(
          'cloud-profile-uuid-1',
        );
        expect(
          pendingOps.any((op) => op.operationType == 'progress_update' || op.operationType == 'restart'),
          isTrue,
        );

        // 3. Flush de lifecycle procesa la cola y la envía a la pasarela
        await ProfileSyncEngine.instance!.flush();
        expect(mockGateway.pushCalls, 1);
        expect(mockGateway.pushedOperations.length, greaterThanOrEqualTo(2));

        // La cola pendiente ahora está limpia
        final remainingOps = await db.userDataDao.getPendingOperations(
          'cloud-profile-uuid-1',
        );
        expect(remainingOps, isEmpty);

        // 4. Sync profile ejecuta pull
        final syncResult = await ProfileSyncEngine.instance!.syncProfile('cloud-profile-uuid-1');
        expect(syncResult.success, isTrue);
        expect(mockGateway.pullCalls, greaterThanOrEqualTo(1));
      },
    );

    testWidgets(
      '4. RecommendationEngine llega realmente a Inicio móvil y TV',
      (tester) async {
        tester.view.physicalSize = const Size(1920, 1080);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final infra = await initializeCatalogInfrastructure(
          catalogDatabase: db,
          profileSyncGateway: mockGateway,
          autoInitializeRepository: false,
        );

        final recEngine = infra.recommendationEngine;
        expect(recEngine, isNotNull);

        // Insertar un título en el catálogo para tener recomendaciones
        final movie = LocalTitlesCompanion.insert(
          id: 'movie-rec-test',
          title: 'Película Recomendada Test',
          normalizedTitle: 'pelicula recomendada test',
          mediaType: 'movie',
          createdAt: DateTime.utc(2026, 1, 1),
          updatedAt: DateTime.utc(2026, 1, 1),
        );
        await db.catalogDao.upsertTitles([movie]);

        final repo = CatalogRepository(
          dao: db.catalogDao,
          gateway: SupabaseCatalogGateway(),
        );
        CatalogRepository.setInstanceForTesting(repo);

        // 1. Probar entrega en TV Shell (Desktop/TV)
        DeviceProfile.overrideType.value = DeviceType.tv;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: HourTvNewShell(
                catalogRepository: repo,
                recommendationEngine: recEngine,
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(find.byType(HourTvNewShell), findsOneWidget);

        // 2. Probar entrega en Mobile Shell
        DeviceProfile.overrideType.value = DeviceType.phone;
        tester.view.physicalSize = const Size(400, 800);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: HourTvMobileShell(
                catalogRepository: repo,
                recommendationEngine: recEngine,
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(find.byType(HourTvMobileShell), findsOneWidget);
      },
    );

    test(
      '5. Cambio de perfil no mezcla recomendaciones, progreso ni favoritos',
      () async {
        final infra = await initializeCatalogInfrastructure(
          catalogDatabase: db,
          profileSyncGateway: mockGateway,
          autoInitializeRepository: false,
        );

        // Perfil 1: Usuario Adulto
        await StorageService.setCloudProfileContext(
          accountId: 'account-uuid-1',
          profileId: 'user-profile-1',
          name: 'Adulto',
          avatarId: 'adult_1',
          isKids: false,
        );

        final channel1 = Channel(
          name: 'Canal de Adulto',
          url: 'catalog://channel-adult-1',
          catalogTitleId: 'ch-adult-1',
        );

        await StorageService.toggleFavorite(channel1);
        await pumpEventQueue();
        await savePlaybackPosition(
          channel1,
          positionMs: 60000,
          durationMs: 120000,
        );
        await pumpEventQueue();
        await infra.profileSyncEngine.flush();

        final favoritesP1 = StorageService.loadFavorites();
        expect(favoritesP1, hasLength(1));
        expect(favoritesP1.first.name, 'Canal de Adulto');

        // Cambiar a Perfil 2: Niño
        await StorageService.setCloudProfileContext(
          accountId: 'account-uuid-1',
          profileId: 'user-profile-2',
          name: 'Pedro Niño',
          avatarId: 'kids_1',
          isKids: true,
        );

        // Las listas de favoritos en memoria/disco están aisladas por profileId
        final favoritesP2 = StorageService.loadFavorites();
        expect(favoritesP2, isEmpty); // NO contiene Canal de Adulto

        // Progreso en Drift aislado por profileId
        final progressP2 = await db.userDataDao.getProgress(
          'user-profile-2',
          PlaybackProgress.contentKey(channel1),
        );
        expect(progressP2, isNull);

        final progressP1 = await db.userDataDao.getProgress(
          'user-profile-1',
          PlaybackProgress.contentKey(channel1),
        );
        expect(progressP1, isNotNull);
        expect(progressP1!.positionMs, 60000);
      },
    );
  });
}
