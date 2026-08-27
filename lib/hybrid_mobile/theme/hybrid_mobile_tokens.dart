import 'package:flutter/material.dart';

abstract final class HybridMobileTokens {
  static const background = Color(0xFF151525);
  static const header = Color(0xFF0D0D1B);
  static const surface = Color(0xFF1B1A2C);
  static const surfaceElevated = Color(0xFF242238);
  static const border = Color(0xFF29283A);
  static const borderStrong = Color(0xFF3A3850);
  static const accent = Color(0xFF4305EE);
  static const accentPressed = Color(0xFF3400C8);
  static const accentSoft = Color(0x334305EE);
  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFFAAA8B7);
  static const textMuted = Color(0xFF7E7B90);
  static const error = Color(0xFFFF5D68);
  static const transparent = Colors.transparent;

  static const xxs = 2.0;
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 24.0;
  static const section = 32.0;
  static const minTouchTarget = 48.0;

  static const radiusSmall = 6.0;
  static const radiusControl = 10.0;
  static const radiusCard = 12.0;
  static const radiusSheet = 20.0;
  static const radiusRound = 999.0;

  static const bottomNavigationHeight = 64.0;
  static const headerHeight = 60.0;
  static const posterAspectRatio = 2 / 3;
}

abstract final class HybridMobileTypography {
  static const family = 'Inter';

  static const display = TextStyle(
    fontFamily: family,
    color: HybridMobileTokens.textPrimary,
    fontSize: 28,
    height: 1.08,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.7,
  );

  static const headline = TextStyle(
    fontFamily: family,
    color: HybridMobileTokens.textPrimary,
    fontSize: 22,
    height: 1.15,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.35,
  );

  static const title = TextStyle(
    fontFamily: family,
    color: HybridMobileTokens.textPrimary,
    fontSize: 16,
    height: 1.25,
    fontWeight: FontWeight.w700,
  );

  static const body = TextStyle(
    fontFamily: family,
    color: HybridMobileTokens.textSecondary,
    fontSize: 14,
    height: 1.45,
    fontWeight: FontWeight.w400,
  );

  static const label = TextStyle(
    fontFamily: family,
    color: HybridMobileTokens.textPrimary,
    fontSize: 12,
    height: 1.25,
    fontWeight: FontWeight.w600,
  );

  static const caption = TextStyle(
    fontFamily: family,
    color: HybridMobileTokens.textSecondary,
    fontSize: 11,
    height: 1.25,
    fontWeight: FontWeight.w400,
  );
}

@immutable
class HybridMobileMetrics {
  const HybridMobileMetrics({
    required this.width,
    required this.horizontalPadding,
    required this.gutter,
    required this.posterColumns,
  });

  factory HybridMobileMetrics.fromWidth(double width) {
    assert(width > 0, 'The viewport width must be positive.');
    final posterColumns = width >= 480 ? 4 : 3;
    final horizontalPadding = width <= 360
        ? 12.0
        : width >= 480
        ? 20.0
        : 16.0;

    return HybridMobileMetrics(
      width: width,
      horizontalPadding: horizontalPadding,
      gutter: width <= 360 ? 8 : 10,
      posterColumns: posterColumns,
    );
  }

  final double width;
  final double horizontalPadding;
  final double gutter;
  final int posterColumns;

  double get posterWidth =>
      (width -
          horizontalPadding * 2 -
          gutter * (posterColumns - 1)) /
      posterColumns;
}
