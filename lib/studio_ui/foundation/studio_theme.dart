import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'studio_tokens.dart';

abstract final class StudioTheme {
  static ThemeData build() {
    const colorScheme = ColorScheme.dark(
      primary: StudioColors.accent,
      onPrimary: StudioColors.deepBlack,
      secondary: StudioColors.accent,
      onSecondary: StudioColors.deepBlack,
      error: StudioColors.error,
      onError: StudioColors.deepBlack,
      surface: StudioColors.surface,
      onSurface: StudioColors.textPrimary,
      outline: StudioColors.border,
      outlineVariant: StudioColors.border,
    );

    const textTheme = TextTheme(
      displayLarge: StudioTypography.display,
      headlineLarge: StudioTypography.headline,
      headlineMedium: StudioTypography.headline,
      titleLarge: StudioTypography.title,
      titleMedium: StudioTypography.title,
      bodyLarge: StudioTypography.body,
      bodyMedium: StudioTypography.body,
      labelLarge: StudioTypography.label,
      labelMedium: StudioTypography.label,
      bodySmall: StudioTypography.caption,
      labelSmall: StudioTypography.caption,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: StudioColors.background,
      canvasColor: StudioColors.background,
      cardColor: StudioColors.surface,
      dividerColor: StudioColors.border,
      disabledColor: StudioColors.textMuted.withValues(alpha: 0.45),
      fontFamily: StudioTypography.family,
      textTheme: textTheme,
      splashFactory: NoSplash.splashFactory,
      splashColor: StudioColors.transparent,
      highlightColor: StudioColors.transparent,
      hoverColor: StudioColors.surfaceElevated,
      focusColor: StudioColors.transparent,
      appBarTheme: const AppBarTheme(
        backgroundColor: StudioColors.background,
        foregroundColor: StudioColors.textPrimary,
        surfaceTintColor: StudioColors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: StudioColors.background,
          statusBarIconBrightness: Brightness.light,
          systemNavigationBarColor: StudioColors.background,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: StudioColors.border,
        thickness: 1,
        space: 1,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(
            backgroundColor: StudioColors.background,
          ),
        },
      ),
    );
  }
}
