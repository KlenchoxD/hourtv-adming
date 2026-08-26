import '../../models/channel.dart';
import '../../services/content_store.dart';
import '../../services/storage_service.dart';
import '../../services/xtream_service.dart';
import 'studio_media_item.dart';

abstract final class StudioCatalogAdapter {
  static StudioMediaItem fromChannel(Channel channel) {
    final kind = switch (channel.type) {
      MediaType.movie => StudioMediaKind.movie,
      MediaType.series => StudioMediaKind.series,
      MediaType.live => StudioMediaKind.live,
    };

    return StudioMediaItem(
      id: channel.tvgId?.trim().isNotEmpty == true
          ? channel.tvgId!.trim()
          : channel.url,
      title: channel.displayName,
      kind: kind,
      source: channel,
      posterUrl: channel.logo,
      backdropUrl: channel.backdrop,
      genre: channel.genre,
      year: channel.year,
      rating: channel.rating,
      duration: channel.duration,
      description: channel.plot,
      cast: channel.cast,
      director: channel.director,
      writer: channel.writer,
      releaseDate: channel.releaseDate,
      categories: List<String>.unmodifiable(channel.categories),
      isFavorite: channel.isFavorite,
      isFeatured: channel.isFeatured,
      lastWatched: channel.lastWatched,
    );
  }

  static StudioMediaItem fromSeries(XtreamSeries series) {
    return StudioMediaItem(
      id: 'series:${series.seriesId}',
      title: series.name,
      kind: StudioMediaKind.series,
      source: series,
      posterUrl: series.cover,
      backdropUrl: series.backdrop,
      genre: series.genre,
      year: series.year,
      rating: series.rating,
      duration: series.duration,
      description: series.plot,
      cast: series.cast,
      director: series.director,
      writer: series.writer,
      releaseDate: series.releaseDate,
      categories: List<String>.unmodifiable(series.categories),
      episodes: List<Channel>.unmodifiable(
        series.episodes ?? const <Channel>[],
      ),
      isFeatured: series.isFeatured,
    );
  }

  static StudioCatalogSnapshot fromStore(ContentStore store) {
    final channels = store.all.map(fromChannel).toList(growable: false);
    final series = store.series.map(fromSeries).toList(growable: false);
    final all = <StudioMediaItem>[...channels, ...series];
    final favorites = store.favorites.map(fromChannel).toList(growable: false);
    final recent = StorageService.loadRecent()
        .map(fromChannel)
        .toList(growable: false);

    return StudioCatalogSnapshot(
      all: List<StudioMediaItem>.unmodifiable(all),
      movies: List<StudioMediaItem>.unmodifiable(
        channels.where((item) => item.kind == StudioMediaKind.movie),
      ),
      series: List<StudioMediaItem>.unmodifiable(series),
      live: List<StudioMediaItem>.unmodifiable(
        channels.where((item) => item.kind == StudioMediaKind.live),
      ),
      favorites: List<StudioMediaItem>.unmodifiable(favorites),
      recent: List<StudioMediaItem>.unmodifiable(recent),
      originals: List<StudioMediaItem>.unmodifiable(
        all.where((item) => item.isFeatured),
      ),
    );
  }
}
