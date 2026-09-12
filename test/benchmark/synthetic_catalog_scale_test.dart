import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:streamtv/database/catalog_database.dart';
import 'package:streamtv/database/daos/catalog_dao.dart';
import '../../tool/import_catalog_to_supabase.dart';

void main() {
  late CatalogDatabase db;
  late CatalogDao dao;

  setUp(() {
    db = CatalogDatabase.inMemory();
    dao = db.catalogDao;
  });

  tearDown(() async {
    await db.close();
  });

  group('Synthetic Catalog Scale & Relational Graph Tests', () {
    test('1. Importador rechaza hosts remotos antes de abrir sockets', () {
      expect(
        () => CatalogDirectImporter.validateTargetHost('supabase.remote.co', 54322),
        throwsA(isA<ArgumentError>()),
      );

      expect(
        () => CatalogDirectImporter.validateTargetHost('192.168.1.50', 54322),
        throwsA(isA<ArgumentError>()),
      );

      expect(
        () => CatalogDirectImporter.validateTargetHost('127.0.0.1', 5432), // Puerto incorrecto
        throwsA(isA<ArgumentError>()),
      );

      // Hosts locales permitidos
      expect(
        () => CatalogDirectImporter.validateTargetHost('127.0.0.1', 54322),
        returnsNormally,
      );
      expect(
        () => CatalogDirectImporter.validateTargetHost('localhost', 54322),
        returnsNormally,
      );
    });

    test('2. Inserción de 10,000 títulos con grafo completo y paginación determinista de 500 páginas (0 duplicados, 0 pérdidas)', () async {
      final baseDate = DateTime.utc(2026, 9, 10, 0, 0, 0);

      // 1. Insertar 10 géneros base
      final genres = <LocalGenresCompanion>[
        for (var g = 1; g <= 10; g++)
          LocalGenresCompanion.insert(
            id: 'genre-$g',
            name: 'Genre $g',
            slug: 'genre-$g',
          ),
      ];
      await db.batch((b) {
        b.insertAll(db.localGenres, genres, mode: InsertMode.insertOrReplace);
      });

      // 2. Poblar grafo relacional completo de 10,000 títulos
      const totalCount = 10000;
      const batchSize = 1000;
      final expectedIds = <String>{};

      for (var b = 0; b < totalCount / batchSize; b++) {
        final titlesBatch = <LocalTitlesCompanion>[];
        final titleGenresBatch = <LocalTitleGenresCompanion>[];
        final seasonsBatch = <LocalSeasonsCompanion>[];
        final episodesBatch = <LocalEpisodesCompanion>[];
        final sourcesBatch = <LocalSourcesCompanion>[];

        for (var i = 0; i < batchSize; i++) {
          final index = b * batchSize + i;
          final titleId = 'title-${index.toString().padLeft(6, '0')}';
          expectedIds.add(titleId);

          final isMovie = index % 2 == 0;
          final mediaType = isMovie ? 'movie' : 'series';
          final date = baseDate.add(Duration(seconds: index ~/ 10));

          titlesBatch.add(
            LocalTitlesCompanion.insert(
              id: titleId,
              mediaType: mediaType,
              title: 'Synthetic Title $index Adventure',
              normalizedTitle: 'synthetic title $index adventure',
              plot: Value('An epic storyline number $index with galaxies and heroes.'),
              year: Value(2000 + (index % 26)),
              rating: Value(5.0 + (index % 50) / 10.0),
              createdAt: date,
              updatedAt: date,
            ),
          );

          // Relación con 1 o 2 géneros
          final genreId1 = 'genre-${(index % 10) + 1}';
          titleGenresBatch.add(LocalTitleGenresCompanion.insert(titleId: titleId, genreId: genreId1));

          if (isMovie) {
            // Fuente para película
            sourcesBatch.add(
              LocalSourcesCompanion.insert(
                id: 'source-$titleId-1',
                titleId: Value(titleId),
                name: 'Server HD',
                url: 'https://cdn.example.com/movies/$titleId.mp4',
                orderIndex: const Value(0),
              ),
            );
          } else {
            // Temporada y episodios para serie
            final seasonId = 'season-$titleId-1';
            seasonsBatch.add(
              LocalSeasonsCompanion.insert(
                id: seasonId,
                titleId: titleId,
                seasonNumber: 1,
                name: const Value('Temporada 1'),
              ),
            );

            for (var ep = 1; ep <= 2; ep++) {
              final episodeId = 'ep-$seasonId-$ep';
              episodesBatch.add(
                LocalEpisodesCompanion.insert(
                  id: episodeId,
                  seasonId: seasonId,
                  episodeNumber: ep,
                  title: 'Episodio $ep',
                ),
              );

              sourcesBatch.add(
                LocalSourcesCompanion.insert(
                  id: 'source-$episodeId-1',
                  episodeId: Value(episodeId),
                  name: 'Server 1080p',
                  url: 'https://cdn.example.com/episodes/$episodeId.m3u8',
                  orderIndex: const Value(0),
                ),
              );
            }
          }
        }

        await db.transaction(() async {
          await db.batch((batch) {
            batch.insertAll(db.localTitles, titlesBatch, mode: InsertMode.insertOrReplace);
            batch.insertAll(db.localTitleGenres, titleGenresBatch, mode: InsertMode.insertOrReplace);
            batch.insertAll(db.localSeasons, seasonsBatch, mode: InsertMode.insertOrReplace);
            batch.insertAll(db.localEpisodes, episodesBatch, mode: InsertMode.insertOrReplace);
            batch.insertAll(db.localSources, sourcesBatch, mode: InsertMode.insertOrReplace);
          });

          // Sincronizar FTS5
          for (final t in titlesBatch) {
            await dao.customStatement(
              'INSERT INTO local_titles_fts (title_id, normalized_title, original_title, plot) VALUES (?, ?, ?, ?)',
              [t.id.value, t.normalizedTitle.value, t.originalTitle.value ?? '', t.plot.value ?? ''],
            );
          }
        });
      }

      // 3. Recorrer de forma determinista las 500 páginas sucesivas (20 títulos por página = 10,000 títulos)
      const pagesToTest = 500;
      const pageSize = 20;
      final seenIds = <String>{};
      DateTime? cursorDate;
      String? cursorId;

      for (var page = 0; page < pagesToTest; page++) {
        final sw = Stopwatch()..start();
        final items = await dao.getPage(
          limit: pageSize,
          cursorCreatedAt: cursorDate,
          cursorId: cursorId,
        );
        sw.stop();

        // Permitir margen para la compilación de consulta en página 0 bajo carga concurrente
        final maxLatencyMs = page == 0 ? 150 : 50;
        expect(
          sw.elapsedMilliseconds,
          lessThan(maxLatencyMs),
          reason: 'Página $page tardó ${sw.elapsedMilliseconds}ms, superando el límite de ${maxLatencyMs}ms',
        );
        expect(items.length, equals(pageSize), reason: 'Página $page no devolvió exactamente $pageSize elementos');

        for (final item in items) {
          final isNew = seenIds.add(item.id);
          expect(isNew, isTrue, reason: 'ID duplicado detectado: ${item.id} en página $page');
        }

        final last = items.last;
        cursorDate = last.createdAt;
        cursorId = last.id;
      }

      // 4. Verificación de cero pérdidas y cero duplicados
      expect(seenIds.length, equals(10000));
      expect(seenIds, equals(expectedIds));

      // La página 501 debe estar vacía (fin de catálogo)
      final endPage = await dao.getPage(
        limit: pageSize,
        cursorCreatedAt: cursorDate,
        cursorId: cursorId,
      );
      expect(endPage, isEmpty);

      // 5. Verificación de coherencia del grafo relacional
      // Muestra de películas: debe tener sus fuentes correspondientes
      final sampleMovieSources = await dao.getSourcesForTitle('title-000000');
      expect(sampleMovieSources, isNotEmpty);
      expect(sampleMovieSources.first.titleId, equals('title-000000'));
      expect(sampleMovieSources.first.url, contains('title-000000'));

      // Muestra de series: debe tener temporadas y episodios
      final sampleSeriesSeasons = await dao.getSeasonsForTitle('title-000001');
      expect(sampleSeriesSeasons, isNotEmpty);
      expect(sampleSeriesSeasons.first.titleId, equals('title-000001'));

      final sampleEpisodes = await dao.getEpisodesForSeason(sampleSeriesSeasons.first.id);
      expect(sampleEpisodes.length, equals(2));

      // Muestra de géneros relacionados
      final sampleGenres = await dao.getGenresForTitle('title-000000');
      expect(sampleGenres, isNotEmpty);

      // Filtrado por género en getPage
      final genreFiltered = await dao.getPage(
        limit: pageSize,
        genreSlug: 'genre-1',
      );
      expect(genreFiltered, isNotEmpty);

      // 6. Verificación FTS5 no tautológica
      final ftsResults = await dao.searchTitlesFts(rawQuery: 'galaxies', limit: 20);
      expect(ftsResults, isNotEmpty);
      for (final r in ftsResults) {
        expect(
          r.plot?.toLowerCase().contains('galaxies') == true || r.title.toLowerCase().contains('galaxies'),
          isTrue,
        );
      }
    });
  });
}
