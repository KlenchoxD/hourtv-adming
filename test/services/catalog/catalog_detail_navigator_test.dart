import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamtv/database/catalog_database.dart';
import 'package:streamtv/models/channel.dart';
import 'package:streamtv/new_ui/hourtv_detail_page.dart';
import 'package:streamtv/new_ui/hourtv_series_detail_page.dart';
import 'package:streamtv/services/catalog/catalog_detail_navigator.dart';
import 'package:streamtv/services/catalog/catalog_dtos.dart';
import 'package:streamtv/services/catalog/catalog_repository.dart';
import 'package:streamtv/services/catalog/catalog_sync_engine.dart';
import 'package:streamtv/services/catalog/supabase_catalog_gateway.dart';
import 'package:streamtv/services/content_store.dart';
import 'package:streamtv/services/xtream_service.dart';

class _FakeGateway extends SupabaseCatalogGateway {
  _FakeGateway() : super(null);

  @override
  Future<CatalogSyncMetadataDto> fetchSyncMetadata() async {
    return const CatalogSyncMetadataDto(
      minimumAvailableRevision: 1,
      latestRevision: 1,
    );
  }
}

void main() {
  late CatalogDatabase db;
  late CatalogRepository repo;

  setUp(() {
    ContentStore.instance.resetForTesting();
    db = CatalogDatabase.inMemory();
    final gateway = _FakeGateway();
    final syncEngine = CatalogSyncEngine(gateway: gateway, dao: db.catalogDao);
    repo = CatalogRepository(
      dao: db.catalogDao,
      gateway: gateway,
      syncEngine: syncEngine,
    );
    CatalogRepository.setInstanceForTesting(repo);
  });

  tearDown(() async {
    ContentStore.instance.resetForTesting();
    CatalogRepository.setInstanceForTesting(null);
    await db.close();
  });

  testWidgets(
    'tarjeta Drift sin temporadas abre todos los episodios publicados',
    (tester) async {
      final published = XtreamSeries(
        seriesId: 'catalog:complete',
        name: 'Serie completa',
        host: '',
        username: '',
        password: '',
        episodes: List.generate(
          24,
          (i) => Channel(
            name: 'Episodio ${i + 1}',
            url: 'https://example.test/${i + 1}',
            group: i < 12 ? 'T1' : 'T2',
            forcedType: 'series',
          ),
        ),
      );
      ContentStore.instance.series = [published];
      final card = Channel(
        name: published.name,
        url: 'catalog://catalog:complete',
        catalogTitleId: published.seriesId,
        forcedType: 'series',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => CatalogDetailNavigator.openDetails(
                context,
                card,
                repository: repo,
              ),
              child: const Text('Abrir publicada'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Abrir publicada'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final page = tester.widget<HourTvSeriesDetailPage>(
        find.byType(HourTvSeriesDetailPage),
      );
      expect(page.series, same(published));
      expect(page.series.episodes, hasLength(24));
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'CatalogDetailNavigator hidrata película y abre HourTvDetailPage con servidores reales',
    (tester) async {
      // 1. Insertar película con 2 fuentes en Drift
      await db.catalogDao.upsertTitle(
        LocalTitlesCompanion.insert(
          id: 'movie_123',
          mediaType: 'movie',
          title: 'Película Test',
          normalizedTitle: 'pelicula test',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      await db.catalogDao.upsertSource(
        LocalSourcesCompanion.insert(
          id: 'src_1',
          titleId: const Value('movie_123'),
          name: 'Servidor 1',
          url: 'https://stream.example.com/movie_1.mp4',
          orderIndex: const Value(0),
        ),
      );
      await db.catalogDao.upsertSource(
        LocalSourcesCompanion.insert(
          id: 'src_2',
          titleId: const Value('movie_123'),
          name: 'Servidor 2 (Mirror)',
          url: 'https://mirror.example.com/movie_2.mp4',
          orderIndex: const Value(1),
        ),
      );

      final unhydratedCard = Channel(
        name: 'Película Test',
        url: 'catalog://movie_123',
        catalogTitleId: 'movie_123',
        forcedType: 'movie',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => CatalogDetailNavigator.openDetails(
                  context,
                  unhydratedCard,
                  repository: repo,
                ),
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Abrir'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(HourTvDetailPage), findsOneWidget);
      final detailPage = tester.widget<HourTvDetailPage>(
        find.byType(HourTvDetailPage),
      );
      expect(detailPage.channel.url, 'https://stream.example.com/movie_1.mp4');
      expect(detailPage.channel.servers.length, 2);
      expect(
        detailPage.channel.servers.first.url,
        'https://stream.example.com/movie_1.mp4',
      );
      expect(
        detailPage.channel.servers.last.url,
        'https://mirror.example.com/movie_2.mp4',
      );
    },
  );

  testWidgets(
    'CatalogDetailNavigator hidrata serie y abre HourTvSeriesDetailPage con temporadas y episodios',
    (tester) async {
      // 1. Insertar serie con temporada y episodios en Drift
      await db.catalogDao.upsertTitle(
        LocalTitlesCompanion.insert(
          id: 'series_999',
          mediaType: 'series',
          title: 'Serie Test',
          normalizedTitle: 'serie test',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      await db.catalogDao.upsertSeason(
        LocalSeasonsCompanion.insert(
          id: 'season_1',
          titleId: 'series_999',
          seasonNumber: 1,
          name: const Value('Temporada 1'),
        ),
      );
      await db.catalogDao.upsertEpisode(
        LocalEpisodesCompanion.insert(
          id: 'ep_1',
          seasonId: 'season_1',
          episodeNumber: 1,
          title: 'Capítulo 1',
        ),
      );
      await db.catalogDao.upsertSource(
        LocalSourcesCompanion.insert(
          id: 'src_ep1',
          episodeId: const Value('ep_1'),
          name: 'Fuente Principal',
          url: 'https://stream.example.com/s1e1.mp4',
        ),
      );

      final unhydratedCard = Channel(
        name: 'Serie Test',
        url: 'catalog://series_999',
        catalogTitleId: 'series_999',
        forcedType: 'series',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => CatalogDetailNavigator.openDetails(
                  context,
                  unhydratedCard,
                  repository: repo,
                ),
                child: const Text('Abrir Serie'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Abrir Serie'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(HourTvSeriesDetailPage), findsOneWidget);
      final seriesPage = tester.widget<HourTvSeriesDetailPage>(
        find.byType(HourTvSeriesDetailPage),
      );
      expect(seriesPage.series.seriesId, 'series_999');
      expect(seriesPage.series.episodes?.length, 1);
      expect(
        seriesPage.series.episodes?.first.url,
        'https://stream.example.com/s1e1.mp4',
      );
    },
  );

  testWidgets(
    'CatalogDetailNavigator ante fallo de hidratación muestra Reintentar y no navega',
    (tester) async {
      // Tarjeta con ID inexistente en Drift
      final unhydratedCard = Channel(
        name: 'Desconocido',
        url: 'catalog://non_existent',
        catalogTitleId: 'non_existent',
        forcedType: 'movie',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => CatalogDetailNavigator.openDetails(
                  context,
                  unhydratedCard,
                  repository: repo,
                ),
                child: const Text('Abrir Fallido'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Abrir Fallido'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // No debe haber navegado
      expect(find.byType(HourTvDetailPage), findsNothing);
      expect(find.byType(HourTvSeriesDetailPage), findsNothing);

      // Debe mostrar SnackBar con Reintentar
      expect(find.text('Reintentar'), findsOneWidget);
      expect(
        find.text('No se pudieron cargar los detalles del título.'),
        findsOneWidget,
      );
    },
  );
}
