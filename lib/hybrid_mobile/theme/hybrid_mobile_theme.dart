import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'hybrid_mobile_tokens.dart';

abstract final class HybridMobileTheme {
  static ThemeData dark() {
    const colorScheme = ColorScheme.dark(
      primary: HybridMobileTokens.accent,
      onPrimary: HybridMobileTokens.textPrimary,
      secondary: HybridMobileTokens.accent,
      onSecondary: HybridMobileTokens.textPrimary,
      error: HybridMobileTokens.error,
      onError: HybridMobileTokens.textPrimary,
      surface: HybridMobileTokens.surface,
      onSurface: HybridMobileTokens.textPrimary,
      outline: HybridMobileTokens.border,
      outlineVariant: HybridMobileTokens.border,
    );

    const textTheme = TextTheme(
      displayLarge: HybridMobileTypography.display,
      headlineLarge: HybridMobileTypography.headline,
      headlineMedium: HybridMobileTypography.headline,
      titleLarge: HybridMobileTypography.title,
      titleMedium: HybridMobileTypography.title,
      bodyLarge: HybridMobileTypography.body,
      bodyMedium: HybridMobileTypography.body,
      labelLarge: HybridMobileTypography.label,
      labelMedium: HybridMobileTypography.label,
      bodySmall: HybridMobileTypography.caption,
      labelSmall: HybridMobileTypography.caption,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: HybridMobileTokens.background,
      canvasColor: HybridMobileTokens.background,
      cardColor: HybridMobileTokens.surface,
      dividerColor: HybridMobileTokens.border,
      disabledColor: HybridMobileTokens.textMuted.withValues(alpha: 0.45),
      fontFamily: HybridMobileTypography.family,
      textTheme: textTheme,
      splashFactory: NoSplash.splashFactory,
      splashColor: HybridMobileTokens.transparent,
      highlightColor: HybridMobileTokens.transparent,
      focusColor: HybridMobileTokens.transparent,
      hoverColor: HybridMobileTokens.surfaceElevated,
      appBarTheme: const AppBarTheme(
        backgroundColor: HybridMobileTokens.header,
        foregroundColor: HybridMobileTokens.textPrimary,
        surfaceTintColor: HybridMobileTokens.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: HybridMobileTokens.header,
          statusBarIconBrightness: Brightness.light,
          systemNavigationBarColor: HybridMobileTokens.background,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: HybridMobileTokens.border,
        thickness: 1,
        space: 1,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(
            backgroundColor: HybridMobileTokens.background,
          ),
        },
      ),
    );
  }
}
