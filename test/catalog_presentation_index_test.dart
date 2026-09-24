import 'package:flutter_test/flutter_test.dart';
import 'package:streamtv/models/channel.dart';
import 'package:streamtv/mobile_ui/hourtv_genre_service.dart';
import 'package:streamtv/services/catalog_presentation_index.dart';

void main() {
  final sampleCatalog = [
    Channel(
      name: 'Caso Alfa',
      url: 'https://example.com/stream/caso_alfa.m3u8',
      genre: 'Drama',
      plot: 'Un gran misterio por resolver',
      year: '2023',
      forcedType: 'series',
      isFeatured: true,
      backdrop: 'https://example.com/backdrops/caso_alfa.jpg',
    ),
    Channel(
      name: 'Misterio en el Bosque',
      url: 'https://example.com/stream/bosque.m3u8',
      genre: 'Terror',
      plot: 'Mucho misterio',
      year: '2021',
      forcedType: 'series',
      isFeatured: false,
    ),
    Channel(
      name: 'Película de Misterio',
      url: 'https://example.com/stream/pelicula.mp4',
      genre: 'Drama',
      plot: 'Misterio en la ciudad',
      year: '2024',
      forcedType: 'movie',
      isFeatured: true,
      backdrop: 'https://example.com/backdrops/pelicula.jpg',
    ),
    Channel(
      name: 'Destacado Sin Backdrop',
      url: 'https://example.com/stream/sin_backdrop.mp4',
      genre: 'Acción',
      isFeatured: true,
      backdrop: '',
    ),
    Channel(
      name: 'Destacado Sin URL',
      url: '   ',
      genre: 'Acción',
      isFeatured: true,
      backdrop: 'https://example.com/backdrops/sin_url.jpg',
    ),
    Channel(
      name: 'Caso Beta',
      url: 'https://example.com/stream/caso_beta.m3u8',
      genre: 'Drama',
      plot: 'Otro caso y misterio',
      year: '2020',
      forcedType: 'series',
      isFeatured: false,
    ),
  ];

  test('search combines text type genre and sort', () {
    final index = CatalogPresentationIndex.build(sampleCatalog);
    final result = index.search(const CatalogQuery(
      text: 'misterio',
      type: ContentTypeFilter.series,
      genre: 'Drama',
      sort: CatalogSort.titleAscending,
    ));
    expect(result.map((e) => e.name), orderedEquals(['Caso Alfa', 'Caso Beta']));
  });

  test('featured requires flag artwork and playable source', () {
    final result = CatalogPresentationIndex.build(sampleCatalog).featured();
    expect(result.isNotEmpty, isTrue);
    expect(
      result.every((item) =>
          item.isFeatured &&
          (item.backdrop ?? '').trim().isNotEmpty &&
          item.url.trim().isNotEmpty),
      isTrue,
    );
    expect(result.any((item) => item.name == 'Destacado Sin Backdrop'), isFalse);
    expect(result.any((item) => item.name == 'Destacado Sin URL'), isFalse);
  });

  test('featured returns empty when nothing is marked Destacado (no silent fallback)', () {
    final catalogWithoutFeatured = [
      Channel(
        name: 'Incompleto 1',
        url: '',
        backdrop: 'https://example.com/bg1.jpg',
        isFeatured: false,
      ),
      Channel(
        name: 'Completo B',
        url: 'https://example.com/b.mp4',
        backdrop: 'https://example.com/b.jpg',
        year: '2022',
        isFeatured: false,
      ),
      Channel(
        name: 'Completo A',
        url: 'https://example.com/a.mp4',
        backdrop: 'https://example.com/a.jpg',
        year: '2024',
        isFeatured: false,
      ),
    ];
    final result = CatalogPresentationIndex.build(catalogWithoutFeatured).featured(limit: 2);
    expect(result, isEmpty);
  });

  test('genresFor returns sorted genres with defaultGenre first', () {
    final index = CatalogPresentationIndex.build(sampleCatalog);
    final seriesGenres = index.genresFor(ContentTypeFilter.series);
    expect(seriesGenres.first, HourTvGenreService.defaultGenre);
    expect(seriesGenres.contains('Drama'), isTrue);
    expect(seriesGenres.contains('Terror'), isTrue);
  });

  test('normalizationCountForTest does not increase after index construction', () {
    final largeCatalog = List.generate(
      10000,
      (i) => Channel(
        name: 'Título $i',
        url: 'https://example.com/video/$i.mp4',
        genre: i % 2 == 0 ? 'Acción' : 'Comedia',
        year: '${2000 + (i % 25)}',
        forcedType: i % 2 == 0 ? 'movie' : 'series',
      ),
    );

    final index = CatalogPresentationIndex.build(largeCatalog);
    final countAfterBuild = HourTvGenreService.normalizationCountForTest;

    for (var i = 0; i < 20; i++) {
      index.search(const CatalogQuery(
        type: ContentTypeFilter.movies,
        sort: CatalogSort.titleAscending,
      ));
    }

    expect(HourTvGenreService.normalizationCountForTest, equals(countAfterBuild));
  });
}
