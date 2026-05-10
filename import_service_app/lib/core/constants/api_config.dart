/// Базовый URL API (желательно с `/` на конце; иначе нормализуется в [DioClient]).
///
/// Дефолт совпадает с виртуальным хостом и сертификатом в панели (имя `*.sslip.io`, не IP).
/// Переопределяется при сборке: `flutter run --dart-define=API_BASE_URL=https://…/api/`
class ApiConfig {
  ApiConfig._();

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://157-22-173-7.sslip.io/api/',
  );

  /// [api-app.md]: `wss://<host>/ws/<requestId>/?token=…` (путь с завершающим `/` перед `?`).
  static String chatWebsocketUrl(String requestId, String accessToken) {
    final raw = baseUrl.trim();
    final u = Uri.parse(raw.endsWith('/') ? raw : '$raw/');
    final scheme = u.scheme == 'https' ? 'wss' : 'ws';
    final idEnc = Uri.encodeComponent(requestId);
    return Uri(
      scheme: scheme,
      host: u.host,
      port: u.hasPort ? u.port : null,
      path: '/ws/$idEnc/',
      queryParameters: <String, String>{'token': accessToken},
    ).toString();
  }
}
