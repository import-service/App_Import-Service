/// Канал дистрибуции сборки (задаётся `--dart-define=APP_DISTRIBUTION=server|store`).
///
/// - [server] — APK с нашего API, самоустановка через FileProvider.
/// - [store] — Play / RuStore AAB/APK без REQUEST_INSTALL_PACKAGES.
final class AppDistribution {
  AppDistribution._();

  static const String channel = String.fromEnvironment(
    'APP_DISTRIBUTION',
    defaultValue: 'server',
  );

  static bool get isServer => channel == 'server';

  static bool get isStore => channel == 'store';
}
