import 'package:flutter/foundation.dart';

@immutable
class StudioLayoutMetrics {
  const StudioLayoutMetrics({
    required this.pagePadding,
    required this.posterWidth,
    required this.posterGap,
    required this.posterColumns,
    this.touchTarget = 48,
  });

  final double pagePadding;
  final double posterWidth;
  final double posterGap;
  final int posterColumns;
  final double touchTarget;

  factory StudioLayoutMetrics.forWidth(double width) {
    assert(width > 0, 'The viewport width must be positive.');
    const columns = 3;
    const gap = 10.0;
    final padding = width < 393
        ? 12.0
        : width >= 480
        ? 20.0
        : 16.0;
    final posterWidth = (width - padding * 2 - gap * (columns - 1)) / columns;

    return StudioLayoutMetrics(
      pagePadding: padding,
      posterWidth: posterWidth,
      posterGap: gap,
      posterColumns: columns,
    );
  }
}
