import 'package:flutter/material.dart';

abstract final class StudioColors {
  static const deepBlack = Color(0xFF050505);
  static const background = Color(0xFF080A09);
  static const surface = Color(0xFF101412);
  static const surfaceElevated = Color(0xFF151917);
  static const border = Color(0xFF27302C);
  static const borderStrong = Color(0xFF38443F);
  static const accent = Color(0xFF00C781);
  static const accentHover = Color(0xFF00E595);
  static const accentGlow = Color(0x2E00C781);
  static const textPrimary = Color(0xFFF5F5F5);
  static const textSecondary = Color(0xFFC4C8C6);
  static const textMuted = Color(0xFFA8ADAB);
  static const error = Color(0xFFFF5D68);
  static const warning = Color(0xFFFFC857);
  static const transparent = Colors.transparent;
}

abstract final class StudioSpacing {
  static const xxs = 2.0;
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 24.0;
  static const section = 32.0;
  static const hero = 40.0;
  static const touchTarget = 48.0;
}

abstract final class StudioRadii {
  static const compact = 4.0;
  static const small = 8.0;
  static const control = 12.0;
  static const card = 16.0;
  static const sheet = 24.0;
  static const round = 999.0;
}

abstract final class StudioMotion {
  static const press = Duration(milliseconds: 120);
  static const screenEnter = Duration(milliseconds: 200);
  static const sheetEnter = Duration(milliseconds: 220);
  static const skeletonPulse = Duration(milliseconds: 1800);

  static const emphasizedCurve = Cubic(0.16, 1, 0.3, 1);
}

abstract final class StudioTypography {
  static const family = 'Inter';

  static const display = TextStyle(
    fontFamily: family,
    fontSize: 32,
    height: 1.08,
    fontWeight: FontWeight.w800,
    color: StudioColors.textPrimary,
    letterSpacing: -0.8,
  );

  static const headline = TextStyle(
    fontFamily: family,
    fontSize: 24,
    height: 1.16,
    fontWeight: FontWeight.w700,
    color: StudioColors.textPrimary,
    letterSpacing: -0.4,
  );

  static const title = TextStyle(
    fontFamily: family,
    fontSize: 18,
    height: 1.25,
    fontWeight: FontWeight.w700,
    color: StudioColors.textPrimary,
    letterSpacing: -0.2,
  );

  static const body = TextStyle(
    fontFamily: family,
    fontSize: 14,
    height: 1.45,
    fontWeight: FontWeight.w400,
    color: StudioColors.textSecondary,
  );

  static const label = TextStyle(
    fontFamily: family,
    fontSize: 12,
    height: 1.25,
    fontWeight: FontWeight.w600,
    color: StudioColors.textPrimary,
  );

  static const caption = TextStyle(
    fontFamily: family,
    fontSize: 11,
    height: 1.25,
    fontWeight: FontWeight.w400,
    color: StudioColors.textMuted,
  );
}
