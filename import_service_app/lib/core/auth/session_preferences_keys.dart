/// Ключи SharedPreferences для сессии (не секреты — только флаги UX).
abstract final class SessionPreferencesKeys {
  /// Демо-пользователь «как с токеном»: сохраняется между перезапусками.
  static const String demoUserActive = 'session_demo_user_active';
  static const String authLastEmail = 'auth_last_email';
  static const String authLastPassword = 'auth_last_password';
  /// Последний успешно полученный профиль `/auth/me` для offline-fallback в UI.
  static const String authProfileCache = 'auth_profile_cache_v1';
  /// Фильтр списка заявок по `managerExternal1cId` (СВХ / декларант / клиент).
  static const String managerFilterExternal1cId = 'manager_filter_external_1c_id';
}
