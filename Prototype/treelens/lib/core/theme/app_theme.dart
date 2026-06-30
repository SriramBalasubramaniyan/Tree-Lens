// lib/core/theme/app_theme.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppColors {
  // Primary: deep forest green
  static const Color primary        = Color(0xFF1B4332);
  static const Color primaryLight   = Color(0xFF2D6A4F);
  static const Color primarySurface = Color(0xFFD8F3DC);

  // Accent: warm amber / earth
  static const Color accent         = Color(0xFFB7791F);
  static const Color accentSurface  = Color(0xFFFEF3C7);

  // Neutrals
  static const Color background     = Color(0xFFF7F5F0);
  static const Color surface        = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF0EDE6);
  static const Color border         = Color(0xFFE2DDD5);

  // Text
  static const Color textPrimary    = Color(0xFF1A1714);
  static const Color textSecondary  = Color(0xFF6B6560);
  static const Color textMuted      = Color(0xFF9E9890);

  // Semantic
  static const Color high   = Color(0xFF2D6A4F);
  static const Color medium = Color(0xFFB7791F);
  static const Color low    = Color(0xFF6B6560);
  static const Color error  = Color(0xFFB91C1C);

  // Dark mode
  static const Color darkBackground     = Color(0xFF0F1A14);
  static const Color darkSurface        = Color(0xFF1A2820);
  static const Color darkSurfaceVariant = Color(0xFF243329);
  static const Color darkBorder         = Color(0xFF2D4535);
  static const Color darkTextPrimary    = Color(0xFFF0EDE6);
  static const Color darkTextSecondary  = Color(0xFFA0B4A8);
}

class AppTheme {
  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.light(
        primary:          AppColors.primary,
        secondary:        AppColors.accent,
        surface:          AppColors.surface,
        surfaceContainerHighest: AppColors.surfaceVariant,
        onPrimary:        Colors.white,
        onSecondary:      Colors.white,
        onSurface:        AppColors.textPrimary,
        outline:          AppColors.border,
        error:            AppColors.error,
      ),
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: 'SpaceGrotesk',
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
        ),
        titleTextStyle: TextStyle(
          fontFamily: 'SpaceGrotesk',
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          textStyle: const TextStyle(
            fontFamily: 'SpaceGrotesk',
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          textStyle: const TextStyle(
            fontFamily: 'SpaceGrotesk',
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceVariant,
        labelStyle: const TextStyle(
          fontFamily: 'SpaceGrotesk',
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AppColors.textSecondary,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        side: BorderSide.none,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
    );
  }

  static ThemeData dark() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.dark(
        primary:          AppColors.primaryLight,
        secondary:        AppColors.accent,
        surface:          AppColors.darkSurface,
        surfaceContainerHighest: AppColors.darkSurfaceVariant,
        onPrimary:        Colors.white,
        onSecondary:      Colors.white,
        onSurface:        AppColors.darkTextPrimary,
        outline:          AppColors.darkBorder,
        error:            Color(0xFFFC8181),
      ),
      scaffoldBackgroundColor: AppColors.darkBackground,
      fontFamily: 'SpaceGrotesk',
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.darkBackground,
        foregroundColor: AppColors.darkTextPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
        titleTextStyle: TextStyle(
          fontFamily: 'SpaceGrotesk',
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.darkTextPrimary,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.darkBorder, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primaryLight,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          textStyle: const TextStyle(
            fontFamily: 'SpaceGrotesk',
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.darkBorder,
        thickness: 1,
        space: 1,
      ),
    );
  }
}
