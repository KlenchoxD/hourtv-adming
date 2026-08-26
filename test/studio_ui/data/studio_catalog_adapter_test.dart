import 'package:flutter_test/flutter_test.dart';
import 'package:streamtv/models/channel.dart';
import 'package:streamtv/services/xtream_service.dart';
import 'package:streamtv/studio_ui/data/studio_catalog_adapter.dart';
import 'package:streamtv/studio_ui/data/studio_media_item.dart';

void main() {
  test('maps a movie without losing playback identity or metadata', () {
    final channel = Channel(
      name: 'El último amanecer',
      url: 'https://example.test/movie.m3u8',
      logo: 'https://example.test/poster.jpg',
      backdrop: 'https://example.test/backdrop.jpg',
      forcedType: 'movie',
      genre: 'Drama',
      year: '2026',
      rating: '9.6',
      duration: '124 min',
      plot: 'Una historia después del eclipse.',
      director: 'Mariana Cordero',
      writer: 'Lucía Fernández',
      isFavorite: true,
      isFeatured: true,
    );

    final item = StudioCatalogAdapter.fromChannel(channel);

    expect(item.id, channel.url);
    expect(item.kind, StudioMediaKind.movie);
    expect(item.title, channel.name);
    expect(item.posterUrl, channel.logo);
    expect(item.backdropUrl, channel.backdrop);
    expect(item.genre, 'Drama');
    expect(item.rating, '9.6');
    expect(item.director, 'Mariana Cordero');
    expect(item.writer, 'Lucía Fernández');
    expect(item.isFavorite, isTrue);
    expect(item.isFeatured, isTrue);
    expect(item.source, same(channel));
  });

  test('maps a series and retains its episodes and credentials', () {
    final episode = Channel(
      name: 'Episodio 1',
      url: 'https://example.test/episode.m3u8',
      forcedType: 'series',
    );
    final series = XtreamSeries(
      seriesId: '42',
      name: 'Frontera Roja',
      cover: 'https://example.test/series.jpg',
      backdrop: 'https://example.test/series-wide.jpg',
      plot: 'Una frontera guarda un secreto.',
      host: 'https://provider.test',
      username: 'user',
      password: 'password',
      episodes: <Channel>[episode],
      genre: 'Crimen',
      year: '2026',
    );

    final item = StudioCatalogAdapter.fromSeries(series);

    expect(item.id, 'series:42');
    expect(item.kind, StudioMediaKind.series);
    expect(item.title, 'Frontera Roja');
    expect(item.episodes, <Channel>[episode]);
    expect(item.source, same(series));
  });
}
