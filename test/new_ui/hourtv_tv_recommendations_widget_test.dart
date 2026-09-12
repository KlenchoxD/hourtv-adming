import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamtv/database/catalog_database.dart';
import 'package:streamtv/models/channel.dart';
import 'package:streamtv/new_ui/hourtv_new_shell.dart';
import 'package:streamtv/services/catalog/catalog_repository.dart';
import 'package:streamtv/services/catalog/catalog_sync_engine.dart';
import 'package:streamtv/services/catalog/supabase_catalog_gateway.dart';
import 'package:streamtv/services/content_store.dart';
import 'package:streamtv/services/device_type.dart';
import 'package:streamtv/services/recommendations/recommendation_engine.dart';
import 'package:streamtv/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  late CatalogDatabase db;
  late CatalogRepository repository;
  late RecommendationEngine recommendationEngine;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    ContentStore.instance.resetForTesting();

    db = CatalogDatabase.inMemory();
    repository = CatalogRepository(
      dao: db.catalogDao,
      gateway: SupabaseCatalogGateway(),
      syncEngine: CatalogSyncEngine(gateway: SupabaseCatalogGateway(), dao: db.catalogDao),
    );
    CatalogRepository.setInstanceForTesting(repository);

    recommendationEngine = RecommendationEngine(userDataDao: db.userDataDao);
  });

  tearDown(() async {
    CatalogRepository.setInstanceForTesting(null);
    await db.close();
    DeviceProfile.overrideType.value = null;
  });

  group('HourTvNewShell TV Recommendations Tests', () {
    testWidgets('1. Muestra fila de recomendaciones explicables en interfaz TV/Desktop', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      DeviceProfile.overrideType.value = DeviceType.tv;

      final recChannel = Channel(
        name: 'Interstellar Recomendada',
        url: 'catalog://rec-interstellar',
        catalogTitleId: 'rec-interstellar',
        genre: 'Ciencia Ficción',
        rating: '8.9',
        isFeatured: true,
        forcedType: 'movie',
      );

      final recItem = RecommendationItem(
        channel: recChannel,
        reason: 'Porque te gusta la Ciencia Ficción',
        category: 'genre_match',
        score: 10.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HourTvNewShell(
              catalogRepository: repository,
              recommendationEngine: recommendationEngine,
              initialRecommendations: [recItem],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Recomendado para ti'), findsOneWidget);
      expect(find.text('Porque te gusta la Ciencia Ficción'), findsOneWidget);
      expect(find.text('Interstellar Recomendada'), findsWidgets);
    });

    testWidgets('2. Perfil infantil filtra contenido no seguro de las recomendaciones', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      DeviceProfile.overrideType.value = DeviceType.tv;
      await StorageService.setActiveProfile('Perfil Infantil');

      final safeKidsMovie = Channel(
        name: 'Cars Aventura Infantil',
        url: 'catalog://rec-cars',
        catalogTitleId: 'rec-cars',
        genre: 'Animación',
        isKidsSafe: true,
        forcedType: 'movie',
      );

      final safeRec = RecommendationItem(
        channel: safeKidsMovie,
        reason: 'Especial para niños',
        category: 'kids_safe',
        score: 9.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HourTvNewShell(
              catalogRepository: repository,
              recommendationEngine: recommendationEngine,
              initialRecommendations: [safeRec],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Recomendado para ti'), findsOneWidget);
      expect(find.text('Especial para niños'), findsOneWidget);
      expect(find.text('Cars Aventura Infantil'), findsWidgets);
    });

    testWidgets('3. Perfil infantil llamado "Pedro" activa filtro infantil estructurado', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      DeviceProfile.overrideType.value = DeviceType.tv;
      // Perfil infantil con nombre "Pedro" (sin palabras clave en el nombre)
      await StorageService.setCloudProfileContext(
        accountId: 'acc-1',
        profileId: 'profile-pedro',
        name: 'Pedro',
        avatarId: 'avatar_kids_1',
        isKids: true,
      );

      expect(StorageService.activeProfileIsKids, isTrue);

      final adultMovie = Channel(
        name: 'Deadpool Action +18',
        url: 'catalog://rec-deadpool',
        catalogTitleId: 'rec-deadpool',
        isKidsSafe: false,
        forcedType: 'movie',
      );
      final kidsMovie = Channel(
        name: 'Toy Story Infantil',
        url: 'catalog://rec-toystory',
        catalogTitleId: 'rec-toystory',
        isKidsSafe: true,
        forcedType: 'movie',
      );

      final recs = await recommendationEngine.getRecommendations(
        profileId: 'profile-pedro',
        isKids: StorageService.activeProfileIsKids,
        catalog: [adultMovie, kidsMovie],
      );

      expect(recs.any((r) => r.channel.name == 'Deadpool Action +18'), isFalse);
      expect(recs.any((r) => r.channel.name == 'Toy Story Infantil'), isTrue);
    });

    testWidgets('4. Perfil adulto llamado "Kids Movie Fan" NO activa filtro infantil por su nombre', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      DeviceProfile.overrideType.value = DeviceType.tv;
      // Perfil adulto con la palabra "Kids" en el nombre, pero estructurado isKids: false
      await StorageService.setCloudProfileContext(
        accountId: 'acc-1',
        profileId: 'profile-adult-fan',
        name: 'Kids Movie Fan',
        avatarId: 'avatar_adult_1',
        isKids: false,
      );

      expect(StorageService.activeProfileIsKids, isFalse);

      final adultMovie = Channel(
        name: 'Inception Sci-Fi',
        url: 'catalog://rec-inception',
        catalogTitleId: 'rec-inception',
        isKidsSafe: false,
        forcedType: 'movie',
      );

      final recs = await recommendationEngine.getRecommendations(
        profileId: 'profile-adult-fan',
        isKids: StorageService.activeProfileIsKids,
        catalog: [adultMovie],
      );

      expect(recs.any((r) => r.channel.name == 'Inception Sci-Fi'), isTrue);
    });
  });
}
