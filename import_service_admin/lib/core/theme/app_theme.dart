import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const Color primaryBlue = Color(0xFF175B98);
  static const Color accentRed = Color(0xFFC74C4E);
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF4A4A4A);
  static const Color pageBackground = Color(0xFFF5F6F8);
  static const Color inputOutlineGray = Color(0xFF757575);
  static const Color white = Color(0xFFFFFFFF);
  static const Color requestCardStatusPillBg = Color(0xFFFFE8E8);
  static const Color requestCardBorder = Color(0xFFE0E0E0);
  static const Color requestCardNewBg = Color(0xFFFFF8E1);
  static const Color requestCardNewBorder = Color(0xFFFFB300);
  static const Color requestCardPendingBg = Color(0xFFFFEBEE);
  static const Color requestCardPendingBorder = Color(0xFFE53935);

  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryBlue,
        primary: primaryBlue,
        error: accentRed,
        surface: white,
        onSurface: textPrimary,
      ),
      scaffoldBackgroundColor: pageBackground,
      appBarTheme: const AppBarTheme(
        backgroundColor: white,
        foregroundColor: textPrimary,
        surfaceTintColor: Colors.transparent,
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: textPrimary),
        bodyMedium: TextStyle(color: textPrimary),
        bodySmall: TextStyle(color: textSecondary),
        titleLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
        titleMedium: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
