import 'package:import_service_app/core/auth/recent_account.dart';

/// Канонические QA-учётки для быстрых входов (логин + профиль).
///
/// Попадают в [RecentAccountsService] даже на чистом устройстве.
/// Пароли тестовые — не прод-секреты заказчика.
class QaKnownAccounts {
  QaKnownAccounts._();

  /// Фиксированная «старая» дата: реальные входы остаются сверху списка.
  static final DateTime _seedAt = DateTime.utc(2020, 1, 1);

  /// Клиентский shell (`/home`). На API роль `admin` (не `user`) — так в БД.
  static final List<RecentAccount> seeds = <RecentAccount>[
    RecentAccount(
      email: 'admin@gmail.com',
      password: '123456',
      role: 'admin',
      lastLoginAt: _seedAt,
    ),
  ];
}
