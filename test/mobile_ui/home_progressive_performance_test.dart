import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamtv/database/catalog_database.dart';
import 'package:streamtv/database/daos/catalog_dao.dart';
import 'package:streamtv/mobile_ui/hourtv_mobile_components.dart';
import 'package:streamtv/mobile_ui/hourtv_mobile_shell.dart';
import 'package:streamtv/models/channel.dart';
import 'package:streamtv/services/catalog/catalog_repository.dart';
import 'package:streamtv/services/catalog_presentation_index.dart';
import 'package:streamtv/services/content_store.dart';
import 'package:streamtv/services/image_resolution_service.dart';
import 'package:streamtv/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('1. ImageResolutionService Tests', () {
    test('normaliza posters de TMDB a w342', () {
      const url500 = 'https://image.tmdb.org/t/p/w500/poster123.jpg';
      const urlOriginal = 'https://image.tmdb.org/t/p/original/poster123.jpg';
      const url1280 = 'https://image.tmdb.org/t/p/w1280/poster123.jpg';

      expect(
        ImageResolutionService.normalize(url500, variant: ImageResolutionVariant.poster),
        'https://image.tmdb.org/t/p/w342/poster123.jpg',
      );
      expect(
        ImageResolutionService.normalize(urlOriginal, variant: ImageResolutionVariant.poster),
        'https://image.tmdb.org/t/p/w342/poster123.jpg',
      );
      expect(
        ImageResolutionService.normalize(url1280, variant: ImageResolutionVariant.poster),
        'https://image.tmdb.org/t/p/w342/poster123.jpg',
      );
    });

    test('normaliza miniaturas y episodios a w185', () {
      const url500 = 'https://image.tmdb.org/t/p/w500/thumb123.jpg';
      expect(
        ImageResolutionService.normalize(url500, variant: ImageResolutionVariant.thumbnail),
        'https://image.tmdb.org/t/p/w185/thumb123.jpg',
      );
    });

    test('normaliza hero backdrops a w780 como máximo', () {
      const url1280 = 'https://image.tmdb.org/t/p/w1280/hero123.jpg';
      const urlOriginal = 'https://image.tmdb.org/t/p/original/hero123.jpg';

      expect(
        ImageResolutionService.normalize(url1280, variant: ImageResolutionVariant.heroBackdrop),
        'https://image.tmdb.org/t/p/w780/hero123.jpg',
      );
      expect(
        ImageResolutionService.normalize(urlOriginal, variant: ImageResolutionVariant.heroBackdrop),
        'https://image.tmdb.org/t/p/w780/hero123.jpg',
      );
    });

    test('mantiene URLs no-TMDB sin alteraciones', () {
      const customUrl = 'https://miservidor.com/portada.jpg';
      expect(
        ImageResolutionService.normalize(customUrl, variant: ImageResolutionVariant.poster),
        customUrl,
      );
      expect(
        ImageResolutionService.normalize(null),
        '',
      );
    });
  });

  group('2. HourTvArtwork & PosterCard Placeholder Tests', () {
    testWidgets('placeholder conserva las dimensiones fijas del contenedor sin saltos de layout', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 120,
                height: 178,
                child: HourTvArtwork(
                  url: 'https://image.tmdb.org/t/p/w500/test.jpg',
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final renderBox = tester.renderObject<RenderBox>(find.byType(HourTvArtwork));
      expect(renderBox.size.width, equals(120.0));
      expect(renderBox.size.height, equals(178.0));
    });
  });

  group('3. CatalogPresentationIndex Build Count in Home', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await StorageService.init();
      CatalogPresentationIndex.resetBuildCountForTest();
    });

    testWidgets('Home no reconstruye el CatalogPresentationIndex en cada build', (tester) async {
      final store = ContentStore.instance;
      final testChannels = [
        Channel(name: 'Movie 1', url: 'https://test/1.mp4', forcedType: 'movie'),
        Channel(name: 'Movie 2', url: 'https://test/2.mp4', forcedType: 'movie'),
      ];
      store.all = testChannels;

      final featuredPrecalculated = [testChannels.first];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HourTvMobileHome(
              movies: testChannels,
              allContent: testChannels,
              featured: featuredPrecalculated,
              store: store,
              onOpen: (_) {},
              onSearch: () {},
              onProfile: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      final initialBuildCount = CatalogPresentationIndex.buildCountForTest;
      expect(initialBuildCount, equals(0), reason: 'Home no debe llamar a CatalogPresentationIndex.build si featured ya está precalculado');

      // Forzar reconstrucción de Home
      await tester.pump();
      expect(CatalogPresentationIndex.buildCountForTest, equals(0), reason: 'Reconstrucciones de Home no deben re-construir el índice');
    });
  });

  group('4. ContentStore Memoization Tests for Genres & Series', () {
    setUp(() {
      final store = ContentStore.instance;
      store.all = [
        Channel(name: 'Anime Movie', url: 'https://test/anime.mp4', forcedType: 'movie', genre: 'Anime'),
        Channel(name: 'K-Drama Series', url: 'https://test/kdrama.mp4', forcedType: 'series', genre: 'K-Drama'),
        Channel(name: 'Normal Movie', url: 'https://test/normal.mp4', forcedType: 'movie', genre: 'Acción'),
      ];
    });

    test('anime, kDramas y visibleSeries devuelven instancias memorizadas mientras el catálogo no cambie', () {
      final store = ContentStore.instance;

      final anime1 = store.anime;
      final anime2 = store.anime;
      expect(identical(anime1, anime2), isTrue, reason: 'store.anime debe estar memorizado');

      final kdramas1 = store.kDramas;
      final kdramas2 = store.kDramas;
      expect(identical(kdramas1, kdramas2), isTrue, reason: 'store.kDramas debe estar memorizado');

      final series1 = store.visibleSeries;
      final series2 = store.visibleSeries;
      expect(identical(series1, series2), isTrue, reason: 'store.visibleSeries debe estar memorizado');
    });
  });

  group('5. Progressive Home & Orientation/Density Stability', () {
    late CatalogDatabase db;
    late CatalogDao dao;
    late CatalogRepository repository;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await StorageService.init();
      db = CatalogDatabase.inMemory();
      dao = db.catalogDao;
      repository = CatalogRepository(
        dao: dao,
      );
      CatalogRepository.setInstanceForTesting(repository);
    });

    tearDown(() async {
      CatalogRepository.setInstanceForTesting(null);
      await db.close();
    });

    testWidgets('Home permite renderizado progresivo y no falla en cambios de orientación o alta densidad', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final pageSource = CatalogPageSource(
        dao: dao,
        mediaType: 'movie',
        pageSize: 10,
      );
      await pageSource.loadInitialPage();

      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(1.3),
            ),
            child: child!,
          ),
          home: Scaffold(
            body: HourTvMobileHome(
              movies: const [],
              allContent: const [],
              store: ContentStore.instance,
              onOpen: (_) {},
              onSearch: () {},
              onProfile: () {},
              catalogRepository: repository,
              moviesPageSource: pageSource,
            ),
          ),
        ),
      );
      await tester.pump();

      // Cambiar orientación a apaisado (landscape)
      await tester.binding.setSurfaceSize(const Size(844, 390));
      await tester.pump();

      expect(tester.takeException(), isNull, reason: 'Home no debe generar overflow ni excepciones en orientación apaisada con texto grande');
    });
  });
}
