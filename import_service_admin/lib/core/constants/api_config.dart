import 'package:flutter/foundation.dart';

/// Базовый URL API ([api-app.md]).
///
/// | Режим | Значение по умолчанию |
/// |-------|------------------------|
/// | `flutter run` (debug) | полный URL прод-сервера |
/// | `flutter build web` (release) | относительный `/api/` — тот же хост, что и `/admin/` |
///
/// Переопределение: `--dart-define=API_BASE_URL=…` (с завершающим `/`).
class ApiConfig {
  ApiConfig._();

  static const String _prodBaseUrl = 'https://157-22-173-7.sslip.io/api/';

  static String get baseUrl {
    const fromEnv = String.fromEnvironment('API_BASE_URL');
    if (fromEnv.trim().isNotEmpty) {
      return fromEnv;
    }
    // Деплой: админка на /admin/, API на /api/ — один origin, без хардкода домена.
    if (kIsWeb && kReleaseMode) {
      return '/api/';
    }
    // Локальная разработка (Chrome): запросы на прод — нужен CORS на API
    // (localhost/127.0.0.1 по умолчанию). Или открывайте /admin/ на том же хосте.
    return _prodBaseUrl;
  }
}
