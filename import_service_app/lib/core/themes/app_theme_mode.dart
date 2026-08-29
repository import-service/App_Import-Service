import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Глобальный режим темы (профиль + [MaterialApp.themeMode]).
final ValueNotifier<ThemeMode> appThemeMode =
    ValueNotifier<ThemeMode>(ThemeMode.system);

const String kAppThemeModePrefsKey = 'app_theme_mode';

ThemeMode themeModeFromPrefs(String? raw) {
  switch (raw) {
    case 'light':
      return ThemeMode.light;
    case 'dark':
      return ThemeMode.dark;
    case 'system':
    default:
      return ThemeMode.system;
  }
}

String themeModeToPrefs(ThemeMode mode) {
  switch (mode) {
    case ThemeMode.light:
      return 'light';
    case ThemeMode.dark:
      return 'dark';
    case ThemeMode.system:
      return 'system';
  }
}

Future<void> loadAppThemeMode(SharedPreferences prefs) async {
  appThemeMode.value = themeModeFromPrefs(prefs.getString(kAppThemeModePrefsKey));
}

Future<void> setAppThemeMode(
  SharedPreferences prefs,
  ThemeMode mode,
) async {
  appThemeMode.value = mode;
  await prefs.setString(kAppThemeModePrefsKey, themeModeToPrefs(mode));
}
