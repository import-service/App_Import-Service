import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Типобезопасные переходы (дополняй по мере появления маршрутов в [app_router]).
///
/// Имена методов можно держать в унисон с `routing.mdc`: `goToLogin`, `goToUserProfile`, ...
extension AppNavigationX on BuildContext {
  void goHome() => go('/');

  void pushRequestDetail(String id) => push('/request/$id');

  Future<T?> pushRequestChat<T extends Object?>(String id) =>
      push<T>('/request/$id/chat');

  /// Пример: после добавления маршрута `/login`
  // void goToLogin() => go('/login');
}
