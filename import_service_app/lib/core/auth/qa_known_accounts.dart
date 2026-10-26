import 'package:flutter/foundation.dart';
import 'package:import_service_app/core/auth/recent_account.dart';

/// Канонические QA-учётки для быстрых входов (логин + профиль).
///
/// Попадают в [RecentAccountsService] даже на чистом устройстве —
/// **только в debug-сборках**. В release сиды не показываем и вычищаем
/// ранее записанные записи (см. [seedEmails]).
/// Пароли тестовые — не прод-секреты заказчика.
class QaKnownAccounts {
  QaKnownAccounts._();

  /// Фиксированная «старая» дата: реальные входы остаются сверху списка.
  static final DateTime _seedAt = DateTime.utc(2020, 1, 1);

  /// Клиентский shell (`/home`). На API роль `admin` (не `user`) — так в БД.
  static final List<RecentAccount> _seeds = <RecentAccount>[
    RecentAccount(
      email: 'admin@gmail.com',
      password: '123456',
      role: 'admin',
      lastLoginAt: _seedAt,
    ),
  ];

  /// Сиды активны только в debug; в release список пуст.
  static List<RecentAccount> get seeds =>
      kDebugMode ? _seeds : const <RecentAccount>[];

  /// Email всех сидов — для вычистки ранее записанных в release.
  static Set<String> get seedEmails => <String>{
    for (final s in _seeds) s.email,
  };
}
