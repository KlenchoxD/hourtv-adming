import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract final class HourTvMobileTokens {
  static const deepBlack = Color(0xFF050505);
  static const background = Color(0xFF080A09);
  static const surfacePrimary = Color(0xFF101412);
  static const surfaceControl = Color(0xFF151917);
  static const borderSubtle = Color(0xFF27302C);
  static const emerald = Color(0xFF00C781);
  static const emeraldHover = Color(0xFF00B876);
  static const textPrimary = Color(0xFFF5F5F5);
  static const textSecondary = Color(0xFFC4C8C6);
  static const textMuted = Color(0xFFA8ADAB);
  static const error = Color(0xFFFF4D4F);

  static const radiusSmall = 8.0;
  static const radiusMedium = 12.0;
  static const radiusLarge = 16.0;
  static const horizontalPadding = 16.0;
  static const bottomNavigationHeight = 68.0;
  static const minimumTouchTarget = 48.0;
}

abstract final class HourTvMobileTheme {
  static ThemeData build() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: HourTvMobileTokens.deepBlack,
      colorScheme: const ColorScheme.dark(
        primary: HourTvMobileTokens.emerald,
        onPrimary: HourTvMobileTokens.deepBlack,
        surface: HourTvMobileTokens.surfacePrimary,
        onSurface: HourTvMobileTokens.textPrimary,
        outline: HourTvMobileTokens.borderSubtle,
        error: HourTvMobileTokens.error,
      ),
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
      focusColor: Colors.transparent,
    );

    final text = GoogleFonts.robotoSerifTextTheme(base.textTheme).apply(
      bodyColor: HourTvMobileTokens.textPrimary,
      displayColor: HourTvMobileTokens.textPrimary,
    );

    return base.copyWith(
      textTheme: text.copyWith(
        headlineLarge: text.headlineLarge?.copyWith(
          fontSize: 30,
          height: 34 / 30,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.6,
        ),
        headlineMedium: text.headlineMedium?.copyWith(
          fontSize: 24,
          height: 30 / 24,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.35,
        ),
        titleLarge: text.titleLarge?.copyWith(
          fontSize: 20,
          height: 26 / 20,
          fontWeight: FontWeight.w700,
        ),
        titleMedium: text.titleMedium?.copyWith(
          fontSize: 14,
          height: 20 / 14,
          fontWeight: FontWeight.w600,
        ),
        bodyMedium: text.bodyMedium?.copyWith(
          fontSize: 12,
          height: 17 / 12,
          color: HourTvMobileTokens.textSecondary,
        ),
        bodySmall: text.bodySmall?.copyWith(
          fontSize: 11,
          height: 14 / 11,
          color: HourTvMobileTokens.textMuted,
        ),
        labelLarge: text.labelLarge?.copyWith(
          fontSize: 12,
          height: 16 / 12,
          fontWeight: FontWeight.w600,
        ),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: HourTvMobileTokens.background,
        indicatorColor: Colors.transparent,
        elevation: 0,
        height: HourTvMobileTokens.bottomNavigationHeight,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: HourTvMobileTokens.surfaceControl,
        hintStyle: const TextStyle(color: HourTvMobileTokens.textMuted),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(HourTvMobileTokens.radiusMedium),
          borderSide: const BorderSide(color: HourTvMobileTokens.borderSubtle),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(HourTvMobileTokens.radiusMedium),
          borderSide: const BorderSide(color: HourTvMobileTokens.borderSubtle),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(HourTvMobileTokens.radiusMedium),
          borderSide: const BorderSide(color: HourTvMobileTokens.emerald),
        ),
      ),
    );
  }
}
