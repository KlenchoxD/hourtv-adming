import 'package:flutter_test/flutter_test.dart';
import 'package:streamtv/studio_ui/foundation/studio_breakpoints.dart';

void main() {
  test('keeps three poster columns inside every approved phone width', () {
    for (final width in <double>[360, 393, 412, 428, 480]) {
      final metrics = StudioLayoutMetrics.forWidth(width);
      final usedWidth =
          metrics.pagePadding * 2 +
          metrics.posterWidth * metrics.posterColumns +
          metrics.posterGap * (metrics.posterColumns - 1);

      expect(metrics.posterColumns, 3, reason: 'width $width');
      expect(usedWidth, closeTo(width, 0.001), reason: 'width $width');
      expect(metrics.posterWidth, greaterThan(96), reason: 'width $width');
      expect(metrics.touchTarget, greaterThanOrEqualTo(48));
    }
  });

  test('uses the compact and comfortable spacing bands deterministically', () {
    expect(StudioLayoutMetrics.forWidth(360).pagePadding, 12);
    expect(StudioLayoutMetrics.forWidth(393).pagePadding, 16);
    expect(StudioLayoutMetrics.forWidth(480).pagePadding, 20);
  });
}
