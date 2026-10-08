import '../models/channel.dart';
import 'xtream_service.dart';

/// Shared identity and metadata for a structured series in catalog surfaces.
String hourTvSeriesKey(XtreamSeries series) =>
    'hourtv-series:${Uri.encodeComponent(series.host)}:${Uri.encodeComponent(series.seriesId)}';

Channel hourTvSeriesChannel(XtreamSeries series) => Channel(
  name: series.name,
  url: hourTvSeriesKey(series),
  logo: series.cover,
  backdrop: series.backdrop ?? series.cover,
  plot: series.plot,
  year: series.year,
  rating: series.rating,
  duration: series.duration,
  genre: series.genre,
  cast: series.cast,
  castPhotos: series.castPhotos,
  director: series.director,
  writer: series.writer,
  releaseDate: series.releaseDate,
  category: 'series',
  forcedType: 'series',
  categories: List<String>.of(series.categories),
);
