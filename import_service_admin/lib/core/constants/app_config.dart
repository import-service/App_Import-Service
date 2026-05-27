/// Флаги приложения.
///
/// `USE_MOCK_API=false` — реальные запросы через Dio.
class AppConfig {
  AppConfig._();

  static const bool useMockApi = bool.fromEnvironment(
    'USE_MOCK_API',
    defaultValue: false,
  );

  static const String mockLogin = 'admin';
  static const String mockPassword = '123456';
}
