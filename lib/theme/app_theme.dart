import 'package:flutter/material.dart';

class AppColors {
  // Neutral Light Theme Colors (Screenshot 2 Visual Reference)
  static const Color background = Color(0xFFF5F5F5);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFEEEEEE);
  static const Color cardBorder = Color(0xFFE5E5E5);
  static const Color divider = Color(0xFFEEEEEE);
  static const Color dividerColor = divider;

  // Text Tokens
  static const Color textPrimary = Color(0xFF111111);
  static const Color textSecondary = Color(0xFF6B6B6B);
  static const Color textMuted = Color(0xFF8A8A8A);

  // Accent & Action Tokens (Restrained & Minimal)
  static const Color accentDark = Color(0xFF1A1A1A);
  static const Color iconColor = Color(0xFF222222);
  static const Color recordingRed = Color(0xFFEF4444);
  static const Color successGreen = Color(0xFF10B981);
  static const Color warningAmber = Color(0xFFF59E0B);

  // Capsule Dock
  static const Color dockBackground = Color(0xFFFFFFFF);
  static const Color dockSelected = Color(0xFFEFEFEF);
  static const Color dockBorder = Color(0xFFE2E2E2);

  // Compatibility aliases for existing references
  static const Color lightBackground = background;
  static const Color lightSurface = surface;
  static const Color lightSurfaceVariant = surfaceVariant;
  static const Color lightCardBorder = cardBorder;
  static const Color lightTextPrimary = textPrimary;
  static const Color lightTextSecondary = textSecondary;
  static const Color lightTextMuted = textMuted;

  static const Color darkBackground = Color(0xFF121212);
  static const Color darkSurface = Color(0xFF1E1E1E);
  static const Color darkSurfaceVariant = Color(0xFF2C2C2C);
  static const Color darkCardBorder = Color(0xFF333333);
  static const Color darkTextPrimary = Color(0xFFF5F5F5);
  static const Color darkTextSecondary = Color(0xFFAAAAAA);
  static const Color darkTextMuted = Color(0xFF777777);

  static const Color primaryBlue = accentDark;
  static const Color primarySky = accentDark;
  static const Color accentPurple = accentDark;
  static const Color accentEmerald = successGreen;
  static const Color accentAmber = warningAmber;
}

class AppTheme {
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: AppColors.background,
    fontFamily: 'Roboto',
    colorScheme: const ColorScheme.light(
      primary: AppColors.accentDark,
      onPrimary: Colors.white,
      primaryContainer: Color(0xFFEAEAEA),
      onPrimaryContainer: AppColors.textPrimary,
      secondary: AppColors.textSecondary,
      onSecondary: Colors.white,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      surfaceContainerHighest: AppColors.surfaceVariant,
      onSurfaceVariant: AppColors.textSecondary,
      outline: AppColors.cardBorder,
      outlineVariant: AppColors.divider,
      error: AppColors.recordingRed,
      onError: Colors.white,
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.cardBorder, width: 1),
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      iconTheme: IconThemeData(color: AppColors.textPrimary),
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.cardBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.cardBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.accentDark, width: 1.5),
      ),
      hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.divider,
      thickness: 1,
      space: 1,
    ),
  );

  static ThemeData darkTheme = lightTheme; // Default to the clean light theme design language
}
