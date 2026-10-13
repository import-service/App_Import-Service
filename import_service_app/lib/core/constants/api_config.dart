/// Базовый URL API (желательно с `/` на конце; иначе нормализуется в [DioClient]).
///
/// Дефолт: прод `https://app.import-service.su/api/` (A-запись; при смене ЦОД меняется IP, не сборка).
/// Переопределяется при сборке: `flutter run --dart-define=API_BASE_URL=https://…/api/`
class ApiConfig {
  ApiConfig._();

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://app.import-service.su/api/',
  );

  /// [api-app.md]: `wss://<host>/ws/<requestId>/?token=…` (путь с завершающим `/` перед `?`).
  ///
  /// Важно: у схемы `wss`/`ws` в Dart нет default port → `Uri.port == 0`,
  /// а `WebSocketChannel` midает на `:0` и upgrade падает. Всегда задаём 443/80
  /// (или явный порт из API_BASE_URL, напр. `:3000`).
  static String chatWebsocketUrl(String requestId, String accessToken) {
    final raw = baseUrl.trim();
    final u = Uri.parse(raw.endsWith('/') ? raw : '$raw/');
    final scheme = u.scheme == 'https' ? 'wss' : 'ws';
    final idEnc = Uri.encodeComponent(requestId);
    return Uri(
      scheme: scheme,
      host: u.host,
      port: _websocketPort(u, scheme),
      path: '/ws/$idEnc/',
      queryParameters: <String, String>{'token': accessToken},
    ).toString();
  }

  /// Общий чат организации: `wss://<host>/ws/org/?token=…`
  static String orgChatWebsocketUrl(String accessToken) {
    final raw = baseUrl.trim();
    final u = Uri.parse(raw.endsWith('/') ? raw : '$raw/');
    final scheme = u.scheme == 'https' ? 'wss' : 'ws';
    return Uri(
      scheme: scheme,
      host: u.host,
      port: _websocketPort(u, scheme),
      path: '/ws/org/',
      queryParameters: <String, String>{'token': accessToken},
    ).toString();
  }

  static int _websocketPort(Uri apiBase, String wsScheme) {
    if (apiBase.hasPort && apiBase.port > 0) {
      return apiBase.port;
    }
    return wsScheme == 'wss' ? 443 : 80;
  }
}
