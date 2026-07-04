import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Fondos: negro con leve tinte azul
  static const Color primaryDark = Color(0xFF04060C);
  static const Color surfaceDark = Color(0xFF0A0F1A);
  static const Color cardDark = Color(0xFF101725);
  static const Color cardElevated = Color(0xFF182236);

  // Acento de marca: gradiente azul electrico
  static const Color accent = Color(0xFF2E7BFF);
  static const Color accentSecondary = Color(0xFF00C2FF);
  static const Color accentLight = Color(0xFF6FA8FF);

  // Texto (blanco)
  static const Color textPrimary = Color(0xFFF6F8FC);
  static const Color textSecondary = Color(0xFFAEB6C6);
  static const Color textMuted = Color(0xFF6B7384);

  // Estados
  static const Color success = Color(0xFF2DD4A8);
  static const Color error = Color(0xFFFF3B5C);
  static const Color warning = Color(0xFFFFB23E);
  static const Color live = Color(0xFFFF2E5B); // "LIVE" se mantiene rojo (convencion)
}

class AppTheme {
  /// Gradiente principal de marca, usado en botones, chips activos y acentos.
  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.accent, AppColors.accentSecondary],
  );

  /// Fondo de la app: negro con un sutil halo azul arriba.
  static const BoxDecoration gradientBackground = BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF0B1730), AppColors.primaryDark],
      stops: [0.0, 0.45],
    ),
  );

  /// Tarjeta con estilo glass (vidrio esmerilado sutil).
  static BoxDecoration glassCard({bool active = false}) => BoxDecoration(
    color: active ? AppColors.accent.withValues(alpha: 0.12) : AppColors.cardDark,
    borderRadius: BorderRadius.circular(18),
    border: Border.all(
      color: active ? AppColors.accent.withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.06),
      width: active ? 1.5 : 1,
    ),
    boxShadow: [
      BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 6)),
    ],
  );

  static BoxDecoration cardGradient({Color? color}) => BoxDecoration(
    color: color ?? AppColors.cardDark,
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
  );

  static ThemeData get darkTheme {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.primaryDark,
      primaryColor: AppColors.accent,
      splashColor: AppColors.accent.withValues(alpha: 0.12),
      highlightColor: AppColors.accent.withValues(alpha: 0.08),
      colorScheme: const ColorScheme.dark(
        primary: AppColors.accent,
        secondary: AppColors.accentSecondary,
        surface: AppColors.surfaceDark,
        error: AppColors.error,
        onPrimary: Colors.white,
        onSurface: AppColors.textPrimary,
      ),
    );

    return base.copyWith(
      textTheme: GoogleFonts.outfitTextTheme(base.textTheme).apply(
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      ).copyWith(
        headlineLarge: GoogleFonts.outfit(color: AppColors.textPrimary, fontWeight: FontWeight.w700, letterSpacing: -0.5),
        headlineMedium: GoogleFonts.outfit(color: AppColors.textPrimary, fontWeight: FontWeight.w700, letterSpacing: -0.5),
        titleLarge: GoogleFonts.outfit(color: AppColors.textPrimary, fontWeight: FontWeight.w600, letterSpacing: -0.3),
        titleMedium: GoogleFonts.outfit(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
        bodyLarge: GoogleFonts.outfit(color: AppColors.textPrimary),
        bodyMedium: GoogleFonts.outfit(color: AppColors.textSecondary),
        bodySmall: GoogleFonts.outfit(color: AppColors.textMuted),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: GoogleFonts.outfit(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w700),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      cardTheme: CardThemeData(
        color: AppColors.cardDark,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.cardDark,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.accent, width: 1.5)),
        hintStyle: const TextStyle(color: AppColors.textMuted),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: GoogleFonts.outfit(fontWeight: FontWeight.w600),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.cardElevated,
        contentTextStyle: const TextStyle(color: AppColors.textPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}
