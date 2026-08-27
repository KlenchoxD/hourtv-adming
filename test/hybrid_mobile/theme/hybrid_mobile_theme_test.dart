import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamtv/hybrid_mobile/theme/hybrid_mobile_theme.dart';
import 'package:streamtv/hybrid_mobile/theme/hybrid_mobile_tokens.dart';

void main() {
  group('HybridMobileTokens', () {
    test('keeps the approved XuperTV colors exact', () {
      expect(HybridMobileTokens.background, const Color(0xFF151525));
      expect(HybridMobileTokens.header, const Color(0xFF0D0D1B));
      expect(HybridMobileTokens.accent, const Color(0xFF4305EE));
      expect(HybridMobileTokens.textPrimary, Colors.white);
    });

    test('keeps primary touch targets at least 48 logical pixels', () {
      expect(HybridMobileTokens.minTouchTarget, greaterThanOrEqualTo(48));
    });
  });

  group('HybridMobileMetrics', () {
    test('uses three poster columns at the 393px reference width', () {
      final metrics = HybridMobileMetrics.fromWidth(393);

      expect(metrics.posterColumns, 3);
      expect(metrics.horizontalPadding, 16);
      expect(metrics.gutter, 10);
      expect(
        metrics.posterWidth * metrics.posterColumns +
            metrics.gutter * (metrics.posterColumns - 1) +
            metrics.horizontalPadding * 2,
        closeTo(393, 0.001),
      );
    });

    test('adapts padding at narrow and wide phone widths', () {
      expect(HybridMobileMetrics.fromWidth(360).horizontalPadding, 12);
      expect(HybridMobileMetrics.fromWidth(428).posterColumns, 3);
      expect(HybridMobileMetrics.fromWidth(480).posterColumns, 4);
      expect(HybridMobileMetrics.fromWidth(480).horizontalPadding, 20);
    });

    test('rejects non-positive viewport widths', () {
      expect(() => HybridMobileMetrics.fromWidth(0), throwsAssertionError);
    });
  });

  test('dark theme uses Inter and reference surfaces', () {
    final theme = HybridMobileTheme.dark();

    expect(theme.brightness, Brightness.dark);
    expect(theme.textTheme.bodyMedium?.fontFamily, 'Inter');
    expect(theme.scaffoldBackgroundColor, HybridMobileTokens.background);
    expect(theme.appBarTheme.backgroundColor, HybridMobileTokens.header);
    expect(theme.splashFactory, NoSplash.splashFactory);
  });
}
