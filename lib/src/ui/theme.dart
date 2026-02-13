import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  const AppColors._();

  static const Color ink = Color(0xFF0B0E12);
  static const Color canvas = Color(0xFF10141B);
  static const Color surface = Color(0xFF151B24);
  static const Color surfaceRaised = Color(0xFF1C2330);
  static const Color borderSubtle = Color(0xFF222B3A);

  static const Color textPrimary = Color(0xFFEAF1FF);
  static const Color textMuted = Color(0xFF9CA9C2);
  static const Color textFaint = Color(0xFF6C778C);

  static const Color brand = Color(0xFF7F9CFF);
  static const Color brandStrong = Color(0xFF5E7BFF);
  static const Color brandGlow = Color(0xFF9CB4FF);

  static const Color accent = Color(0xFF4EE1C1);
  static const Color warning = Color(0xFFF5B548);
  static const Color danger = Color(0xFFEF5B7A);
  static const Color success = Color(0xFF3DDC97);

  static const Color bubbleIncoming = Color(0xFF1A2231);
  static const Color bubbleOutgoing = Color(0xFF263458);
  static const Color bubbleOutgoingEdge = Color(0xFF2C4370);
}

class AppTypography {
  const AppTypography._();

  static const String primaryFont = 'Inter';
  static const List<String> fallbackFonts = ['sans-serif'];

  static final TextStyle display = GoogleFonts.inter(
    fontSize: 32,
    fontWeight: FontWeight.w600,
    height: 1.15,
    letterSpacing: -0.4,
  ).copyWith(fontFamilyFallback: fallbackFonts);

  static final TextStyle headline = GoogleFonts.inter(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    height: 1.2,
    letterSpacing: -0.2,
  ).copyWith(fontFamilyFallback: fallbackFonts);

  static final TextStyle title = GoogleFonts.inter(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 1.25,
  ).copyWith(fontFamilyFallback: fallbackFonts);

  static final TextStyle body = GoogleFonts.inter(
    fontSize: 15,
    fontWeight: FontWeight.w500,
    height: 1.5,
  ).copyWith(fontFamilyFallback: fallbackFonts);

  static final TextStyle bodyMuted = GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.4,
  ).copyWith(fontFamilyFallback: fallbackFonts);

  static final TextStyle caption = GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.3,
    letterSpacing: 0.2,
  ).copyWith(fontFamilyFallback: fallbackFonts);
}

class AppSpacing {
  const AppSpacing._();

  static const double base = 4;
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 40;
  static const double xxxl = 56;
}

class AppTheme {
  const AppTheme._();

  static ThemeData dark() {
    final colorScheme = const ColorScheme.dark().copyWith(
      primary: AppColors.brand,
      primaryContainer: AppColors.brandStrong,
      secondary: AppColors.accent,
      surface: AppColors.surface,
      error: AppColors.danger,
      onPrimary: AppColors.ink,
      onSecondary: AppColors.ink,
      onSurface: AppColors.textPrimary,
      onError: AppColors.textPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.canvas,
      fontFamily: AppTypography.primaryFont,
      textTheme: TextTheme(
        displayLarge: AppTypography.display,
        headlineMedium: AppTypography.headline,
        titleMedium: AppTypography.title,
        bodyLarge: AppTypography.body,
        bodyMedium: AppTypography.bodyMuted,
        labelSmall: AppTypography.caption,
      ).apply(
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.canvas,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      cardTheme: CardTheme(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.borderSubtle, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.borderSubtle, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.borderSubtle, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.brandGlow, width: 1.2),
        ),
        labelStyle: const TextStyle(color: AppColors.textMuted),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.brand,
          foregroundColor: AppColors.ink,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          textStyle: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.borderSubtle,
        thickness: 1,
        space: 1,
      ),
    );
  }
}
