import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamtv/database/catalog_database.dart';
import 'package:streamtv/database/daos/catalog_dao.dart';
import 'package:streamtv/new_ui/hourtv_new_shell.dart';
import 'package:streamtv/new_ui/hourtv_detail_page.dart';
import 'package:streamtv/new_ui/hourtv_series_detail_page.dart';
import 'package:streamtv/new_ui/hourtv_player_screen.dart';
import 'package:streamtv/services/catalog/catalog_page_source.dart';
import 'package:streamtv/services/catalog/catalog_repository.dart';
import 'package:streamtv/services/catalog/catalog_sync_engine.dart';
import 'package:streamtv/services/catalog/supabase_catalog_gateway.dart';
import 'package:streamtv/services/device_type.dart';
import 'package:streamtv/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

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
      gateway: SupabaseCatalogGateway(),
      syncEngine: CatalogSyncEngine(gateway: SupabaseCatalogGateway(), dao: dao),
    );
    CatalogRepository.setInstanceForTesting(repository);
  });

  tearDown(() async {
    CatalogRepository.setInstanceForTesting(null);
    await db.close();
    DeviceProfile.overrideType.value = null;
  });

  group('HourTvNewShell TV and Tablet Integration Tests', () {
    testWidgets('1. TV Home renderiza películas y series provenientes de Drift', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      DeviceProfile.overrideType.value = DeviceType.tv;

      final now = DateTime.utc(2026, 9, 10, 12, 0, 0);

      // Insertar película Drift
      await dao.upsertTitle(
        LocalTitlesCompanion.insert(
          id: 'movie-drift-tv-1',
          mediaType: 'movie',
          title: 'Drift Movie TV',
          normalizedTitle: 'drift movie tv',
          createdAt: now,
          updatedAt: now,
        ),
      );

      // Insertar serie Drift
      await dao.upsertTitle(
        LocalTitlesCompanion.insert(
          id: 'series-drift-tv-1',
          mediaType: 'series',
          title: 'Drift Series TV',
          normalizedTitle: 'drift series tv',
          createdAt: now,
          updatedAt: now,
        ),
      );

      final moviesSource = CatalogPageSource(dao: dao, mediaType: 'movie', pageSize: 10);
      final seriesSource = CatalogPageSource(dao: dao, mediaType: 'series', pageSize: 10);
      await moviesSource.loadInitialPage();
      await seriesSource.loadInitialPage();

      await tester.pumpWidget(
        MaterialApp(
          home: HourTvNewShell(
            catalogRepository: repository,
            moviesPageSource: moviesSource,
            seriesPageSource: seriesSource,
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Drift Movie TV'), findsWidgets);
      expect(find.text('Drift Series TV'), findsWidgets);
    });

    testWidgets('2. TV Película: tarjeta -> hidratación asíncrona -> HourTvDetailPage -> reproducir -> PlayerScreen con HTTPS real', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      DeviceProfile.overrideType.value = DeviceType.tv;

      final now = DateTime.utc(2026, 9, 10, 12, 0, 0);

      await dao.upsertTitle(
        LocalTitlesCompanion.insert(
          id: 'movie-tv-interstellar',
          mediaType: 'movie',
          title: 'Interstellar TV Real',
          normalizedTitle: 'interstellar tv real',
          createdAt: now,
          updatedAt: now,
        ),
      );
      await dao.upsertSource(
        const LocalSourcesCompanion(
          id: Value('src-tv-movie-1'),
          titleId: Value('movie-tv-interstellar'),
          name: Value('Servidor TV Principal'),
          url: Value('https://cdn.example.com/interstellar_tv.mp4'),
          orderIndex: Value(0),
        ),
      );
      await dao.upsertSource(
        const LocalSourcesCompanion(
          id: Value('src-tv-movie-2'),
          titleId: Value('movie-tv-interstellar'),
          name: Value('Servidor TV Backup'),
          url: Value('https://mirror.example.com/interstellar_tv.mp4'),
          orderIndex: Value(1),
        ),
      );

      final moviesSource = CatalogPageSource(dao: dao, mediaType: 'movie', pageSize: 10);
      await moviesSource.loadInitialPage();

      await tester.pumpWidget(
        MaterialApp(
          home: HourTvNewShell(
            catalogRepository: repository,
            moviesPageSource: moviesSource,
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Seleccionar la tarjeta de la película en la fila de catálogo
      final movieFinder = find.text('Interstellar TV Real').last;
      await tester.ensureVisible(movieFinder);
      await tester.pump();
      await tester.tap(movieFinder);

      // Esperar hidratación asíncrona y navegación al detalle
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(HourTvDetailPage), findsOneWidget);
      final detailPage = tester.widget<HourTvDetailPage>(find.byType(HourTvDetailPage));
      expect(detailPage.channel.url, equals('https://cdn.example.com/interstellar_tv.mp4'));
      expect(detailPage.channel.servers.length, equals(2));

      // En Android TV, la acción de reproducir está enfocada por defecto (tvAction = 0)
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verificar que se abrió el PlayerScreen con la URL HTTPS real
      expect(find.byType(PlayerScreen), findsOneWidget);
      final player = tester.widget<PlayerScreen>(find.byType(PlayerScreen));
      expect(player.channel.url, equals('https://cdn.example.com/interstellar_tv.mp4'));
      expect(player.channel.servers.length, equals(2));
    });

    testWidgets('3. TV Serie: tarjeta -> hidratación -> HourTvSeriesDetailPage con temporadas y episodios -> PlayerScreen con HTTPS real', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      DeviceProfile.overrideType.value = DeviceType.tv;

      final now = DateTime.utc(2026, 9, 10, 12, 0, 0);

      await dao.upsertTitle(
        LocalTitlesCompanion.insert(
          id: 'series-tv-bb',
          mediaType: 'series',
          title: 'Breaking TV Drift',
          normalizedTitle: 'breaking tv drift',
          createdAt: now,
          updatedAt: now,
        ),
      );
      await dao.upsertSeason(
        const LocalSeasonsCompanion(
          id: Value('s1-tv-bb'),
          titleId: Value('series-tv-bb'),
          seasonNumber: Value(1),
          name: Value('Temporada 1'),
        ),
      );
      await dao.upsertSeason(
        const LocalSeasonsCompanion(
          id: Value('s2-tv-bb'),
          titleId: Value('series-tv-bb'),
          seasonNumber: Value(2),
          name: Value('Temporada 2'),
        ),
      );
      await dao.upsertEpisode(
        const LocalEpisodesCompanion(
          id: Value('ep1-tv-bb'),
          seasonId: Value('s1-tv-bb'),
          episodeNumber: Value(1),
          title: Value('Piloto Químico'),
          duration: Value('58m'),
        ),
      );
      await dao.upsertEpisode(
        const LocalEpisodesCompanion(
          id: Value('ep2-tv-bb'),
          seasonId: Value('s2-tv-bb'),
          episodeNumber: Value(1),
          title: Value('Siete Treinta y Siete'),
          duration: Value('47m'),
        ),
      );
      await dao.upsertSource(
        const LocalSourcesCompanion(
          id: Value('src-ep1-tv'),
          episodeId: Value('ep1-tv-bb'),
          name: Value('Servidor TV Ep 1'),
          url: Value('https://cdn.example.com/breaking_bad_s01e01.mp4'),
        ),
      );

      final seriesSource = CatalogPageSource(dao: dao, mediaType: 'series', pageSize: 10);
      await seriesSource.loadInitialPage();

      await tester.pumpWidget(
        MaterialApp(
          home: HourTvNewShell(
            catalogRepository: repository,
            seriesPageSource: seriesSource,
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final seriesCard = find.text('Breaking TV Drift').first;
      await tester.ensureVisible(seriesCard);
      await tester.pump();
      await tester.tap(seriesCard);

      // Esperar hidratación asíncrona de serie y navegación
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(HourTvSeriesDetailPage), findsOneWidget);
      final seriesDetail = tester.widget<HourTvSeriesDetailPage>(find.byType(HourTvSeriesDetailPage));
      expect(seriesDetail.series.name, equals('Breaking TV Drift'));
      expect(seriesDetail.series.episodes?.length, equals(2));

      // Verificar que el episodio 1 está visible
      final epFinder = find.text('Piloto Químico');
      expect(epFinder, findsOneWidget);
      await tester.ensureVisible(epFinder);
      await tester.pump();
      await tester.tap(epFinder);

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verificar que se abrió el PlayerScreen con la URL HTTPS del episodio
      expect(find.byType(PlayerScreen), findsOneWidget);
      final player = tester.widget<PlayerScreen>(find.byType(PlayerScreen));
      expect(player.channel.name, equals('Piloto Químico'));
      expect(player.channel.url, equals('https://cdn.example.com/breaking_bad_s01e01.mp4'));
    });

    testWidgets('4. Tablet: layout adaptado y navegación a detalles hidratados con fuente real', (tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      DeviceProfile.overrideType.value = DeviceType.tablet;

      final now = DateTime.utc(2026, 9, 10, 12, 0, 0);

      await dao.upsertTitle(
        LocalTitlesCompanion.insert(
          id: 'movie-tablet-1',
          mediaType: 'movie',
          title: 'Película Tablet 2K',
          normalizedTitle: 'pelicula tablet 2k',
          createdAt: now,
          updatedAt: now,
        ),
      );
      await dao.upsertSource(
        const LocalSourcesCompanion(
          id: Value('src-tablet-1'),
          titleId: Value('movie-tablet-1'),
          name: Value('Servidor Tablet'),
          url: Value('https://cdn.example.com/tablet_movie.mp4'),
        ),
      );

      final moviesSource = CatalogPageSource(dao: dao, mediaType: 'movie', pageSize: 10);
      await moviesSource.loadInitialPage();

      await tester.pumpWidget(
        MaterialApp(
          home: HourTvNewShell(
            catalogRepository: repository,
            moviesPageSource: moviesSource,
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Película Tablet 2K'), findsWidgets);

      final cardFinder = find.text('Película Tablet 2K').last;
      await tester.ensureVisible(cardFinder);
      await tester.pump();
      await tester.tap(cardFinder);

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(HourTvDetailPage), findsOneWidget);
      final detailPage = tester.widget<HourTvDetailPage>(find.byType(HourTvDetailPage));
      expect(detailPage.channel.url, equals('https://cdn.example.com/tablet_movie.mp4'));
    });
  });
}
