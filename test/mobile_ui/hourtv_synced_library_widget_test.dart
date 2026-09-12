import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamtv/database/catalog_database.dart';
import 'package:streamtv/mobile_ui/hourtv_mobile_shell.dart';
import 'package:streamtv/models/channel.dart';
import 'package:streamtv/new_ui/hourtv_player_screen.dart';
import 'package:streamtv/services/content_store.dart';
import 'package:streamtv/services/storage_service.dart';
import 'package:streamtv/services/sync/profile_sync_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CatalogDatabase db;
  late ProfileSyncEngine syncEngine;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    ContentStore.instance.resetForTesting();

    db = CatalogDatabase.inMemory();
    syncEngine = ProfileSyncEngine(
      userDataDao: db.userDataDao,
      deviceId: 'test-device-synced-lib',
    );
    ProfileSyncEngine.setInstance(syncEngine);
  });

  tearDown(() async {
    ProfileSyncEngine.setInstance(null);
    await db.close();
  });

  group('HourTvMobileLibrary Synced Data Widget Tests', () {
    testWidgets('1. Sincroniza y refleja favoritos en la biblioteca para el perfil activo', (tester) async {
      await StorageService.setActiveProfile('Perfil Adulto 1');

      final fav1 = Channel(
        name: 'Película Favorita Sincronizada',
        url: 'catalog://sync-fav-1',
        catalogTitleId: 'sync-fav-1',
        genre: 'Ciencia Ficción',
        forcedType: 'movie',
      );

      await StorageService.toggleFavorite(fav1);

      // Verificar que syncEngine registró el favorito en la base de datos Drift
      final dbFavs = await db.userDataDao.getFavorites(StorageService.activeProfileId);
      expect(dbFavs.length, equals(1));
      expect(dbFavs.first.titleId, equals('sync-fav-1'));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HourTvMobileLibrary(
              store: ContentStore.instance,
              onOpen: (_) {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Película Favorita Sincronizada'), findsOneWidget);
    });

    testWidgets('2. Sincroniza progreso de reproduccion guardado por savePlaybackPosition', (tester) async {
      await StorageService.setActiveProfile('Perfil Adulto 2');

      final progMovie = Channel(
        name: 'Película En Progreso',
        url: 'catalog://sync-prog-1',
        catalogTitleId: 'sync-prog-1',
        forcedType: 'movie',
      );

      // Guardar avance de 10 minutos (600000ms) de una pelicula de 20 minutos (1200000ms)
      await savePlaybackPosition(
        progMovie,
        positionMs: 600000,
        durationMs: 1200000,
      );

      // Verificar que syncEngine y Drift persistieron el progreso
      final dbProg = await db.userDataDao.getProgress(
        StorageService.activeProfileId,
        'movie:sync-prog-1',
      );
      expect(dbProg, isNotNull);
      expect(dbProg!.positionMs, equals(600000));
      expect(dbProg.fraction, closeTo(0.5, 0.01));

      // Verificar que el historial tambien se persistió (>= 60s)
      final dbHist = await db.userDataDao.getHistory(StorageService.activeProfileId);
      expect(dbHist.isNotEmpty, isTrue);
      expect(dbHist.first.titleId, equals('sync-prog-1'));
    });
  });
}
