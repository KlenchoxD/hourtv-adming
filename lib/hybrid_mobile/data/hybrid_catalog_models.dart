import 'package:flutter/foundation.dart';

import '../../studio_ui/data/studio_media_item.dart';

enum HybridMediaKind { movie, series, anime, novela }

enum HybridSortOrder { newest, oldest, titleAscending }

@immutable
class HybridMediaItem {
  const HybridMediaItem({required this.media, required this.kind});

  final StudioMediaItem media;
  final HybridMediaKind kind;

  String get id => media.id;
  String get title => media.title;
  Object get source => media.source;
  String? get posterUrl => media.posterUrl;
  String? get backdropUrl => media.backdropUrl;
  String? get genre => media.genre;
  String? get year => media.year;
  String? get rating => media.rating;
  String? get duration => media.duration;
  String? get description => media.description;
  String? get cast => media.cast;
  String? get director => media.director;
  String? get writer => media.writer;
  String? get releaseDate => media.releaseDate;
  List<String> get categories => media.categories;
  bool get isFeatured => media.isFeatured;
  DateTime? get lastWatched => media.lastWatched;
}

@immutable
class HybridMediaSection {
  const HybridMediaSection({
    required this.id,
    required this.title,
    required this.kind,
    required this.items,
  });

  final String id;
  final String title;
  final HybridMediaKind kind;
  final List<HybridMediaItem> items;
}
