import 'package:flutter/material.dart';

/// Палитра и [ThemeData] (Material 3). Светлая / тёмная.
///
/// Адаптивные цвета (фон, карточки, текст) читают [brightness], который
/// выставляет [MaterialApp.builder] через [bindBrightness] — при смене
/// [ThemeMode] виджеты перестраиваются и берут актуальные значения.
///
/// [white] / [onAccent] — всегда белый (текст/иконки на primary/accent).
/// Для фона карточек используй [cardBackground].
abstract final class AppTheme {
  static Brightness _brightness = Brightness.light;

  /// Вызывать из [MaterialApp.builder] при каждой сборке.
  static void bindBrightness(Brightness value) {
    _brightness = value;
  }

  static bool get isDark => _brightness == Brightness.dark;

  static const Color primaryBlue = Color(0xFF175B98);
  static const Color accentRed = Color(0xFFC74C4E);

  /// Текст/иконки на синем или красном (не адаптируется).
  static const Color white = Color(0xFFFFFFFF);
  static const Color onAccent = white;

  static Color get textPrimary =>
      isDark ? const Color(0xFFE8EAED) : const Color(0xFF1A1A1A);

  static Color get textSecondary =>
      isDark ? const Color(0xFFB0B3B8) : const Color(0xFF4A4A4A);

  static Color get pageBackground =>
      isDark ? const Color(0xFF121212) : const Color(0xFFF5F6F8);

  /// Обводка полей на формах.
  static Color get inputOutlineGray =>
      isDark ? const Color(0xFF8A8A8A) : const Color(0xFF757575);

  /// Фон карточек / поверхностей.
  static Color get cardBackground =>
      isDark ? const Color(0xFF1E1E1E) : white;

  /// Светло-голубой тинт секций заявки (только light; в dark = card).
  static Color get sectionTint =>
      isDark ? cardBackground : const Color(0xFFF2F7FD);

  /// Кнопка-действие на карточке заявки.
  static Color get requestCardStatusPillBg =>
      isDark ? const Color(0xFF3D2A2A) : const Color(0xFFFFE8E8);

  static Color get requestCardBorder =>
      isDark ? const Color(0xFF3A3A3A) : const Color(0xFFE0E0E0);

  static Color get requestCardChatButtonBg =>
      isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF0F0F0);

  /// Исходящий пузырь чата (серый).
  static Color get chatOutgoingBubbleBg =>
      isDark ? const Color(0xFF2C2C2C) : const Color(0xFFE6E6E6);

  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final scheme = ColorScheme(
      brightness: brightness,
      primary: primaryBlue,
      onPrimary: white,
      secondary: primaryBlue,
      onSecondary: white,
      error: accentRed,
      onError: white,
      surface: dark ? const Color(0xFF1E1E1E) : white,
      onSurface: dark ? const Color(0xFFE8EAED) : const Color(0xFF1A1A1A),
      onSurfaceVariant:
          dark ? const Color(0xFFB0B3B8) : const Color(0xFF4A4A4A),
      surfaceContainerHighest:
          dark ? const Color(0xFF2A2A2A) : const Color(0xFFF0F0F0),
      outline: dark ? const Color(0xFF3A3A3A) : const Color(0xFFE0E0E0),
    );

    final pageBg = dark ? const Color(0xFF121212) : const Color(0xFFF5F6F8);
    final textPri = scheme.onSurface;
    final textSec = scheme.onSurfaceVariant;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: pageBg,
      dividerColor: scheme.outline,
      appBarTheme: AppBarTheme(
        backgroundColor: dark ? const Color(0xFF1E1E1E) : white,
        foregroundColor: textPri,
        surfaceTintColor: Colors.transparent,
      ),
      cardColor: scheme.surface,
      canvasColor: pageBg,
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: primaryBlue,
        surfaceTintColor: Colors.transparent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
      ),
      textTheme: TextTheme(
        bodyLarge: TextStyle(color: textPri),
        bodyMedium: TextStyle(color: textPri),
        bodySmall: TextStyle(color: textSec),
        titleLarge: TextStyle(color: textPri, fontWeight: FontWeight.w600),
        titleMedium: TextStyle(color: textPri, fontWeight: FontWeight.w600),
        headlineSmall: TextStyle(color: textPri, fontWeight: FontWeight.w700),
      ),
    );
  }
}
