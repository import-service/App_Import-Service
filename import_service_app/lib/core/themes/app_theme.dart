import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const Color primaryBlue = Color(0xFF175B98);
  static const Color accentRed = Color(0xFFC74C4E);
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF4A4A4A);
  static const Color pageBackground = Color(0xFFF5F6F8);
  /// Обводка полей на формах (тёмно-серый, 1 px).
  static const Color inputOutlineGray = Color(0xFF757575);
  static const Color white = Color(0xFFFFFFFF);
  /// Кнопка-действие на карточке заявки (светло-розовая, как раньше).
  static const Color requestCardStatusPillBg = Color(0xFFFFE8E8);
  static const Color requestCardBorder = Color(0xFFE0E0E0);
  static const Color requestCardChatButtonBg = Color(0xFFF0F0F0);

  static ThemeData light() {
    final scheme = const ColorScheme(
      brightness: Brightness.light,
      primary: primaryBlue,
      onPrimary: white,
      secondary: primaryBlue,
      onSecondary: white,
      error: accentRed,
      onError: white,
      surface: white,
      onSurface: textPrimary,
      onSurfaceVariant: textSecondary,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
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
      ),
    );
  }
}
