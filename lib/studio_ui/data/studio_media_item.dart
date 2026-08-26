import 'package:flutter/foundation.dart';

import '../../models/channel.dart';

enum StudioMediaKind { movie, series, live }

@immutable
class StudioMediaItem {
  const StudioMediaItem({
    required this.id,
    required this.title,
    required this.kind,
    required this.source,
    this.posterUrl,
    this.backdropUrl,
    this.genre,
    this.year,
    this.rating,
    this.duration,
    this.description,
    this.cast,
    this.director,
    this.writer,
    this.releaseDate,
    this.categories = const <String>[],
    this.episodes = const <Channel>[],
    this.isFavorite = false,
    this.isFeatured = false,
    this.lastWatched,
  });

  final String id;
  final String title;
  final StudioMediaKind kind;
  final Object source;
  final String? posterUrl;
  final String? backdropUrl;
  final String? genre;
  final String? year;
  final String? rating;
  final String? duration;
  final String? description;
  final String? cast;
  final String? director;
  final String? writer;
  final String? releaseDate;
  final List<String> categories;
  final List<Channel> episodes;
  final bool isFavorite;
  final bool isFeatured;
  final DateTime? lastWatched;
}

@immutable
class StudioCatalogSnapshot {
  const StudioCatalogSnapshot({
    required this.all,
    required this.movies,
    required this.series,
    required this.live,
    required this.favorites,
    required this.recent,
    required this.originals,
  });

  final List<StudioMediaItem> all;
  final List<StudioMediaItem> movies;
  final List<StudioMediaItem> series;
  final List<StudioMediaItem> live;
  final List<StudioMediaItem> favorites;
  final List<StudioMediaItem> recent;
  final List<StudioMediaItem> originals;
}
