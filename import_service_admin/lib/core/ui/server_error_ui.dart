import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:import_service_admin/core/auth/auth_session_controller.dart';
import 'package:import_service_admin/core/di/injection_container.dart';
import 'package:import_service_admin/core/error/exceptions.dart';

/// Не показывать экран ошибки, если сессия сброшена — идёт редирект на вход.
bool shouldHideErrorForAuth(Object? error) {
  if (error is UnauthorizedException) return true;
  return !sl<AuthSessionController>().isAuthenticated;
}

/// Экран «ошибка + Повторить»; при истёкшей сессии — пустой виджет.
Widget? buildRetryErrorPanel({
  required Object? error,
  required VoidCallback onRetry,
}) {
  if (error == null || shouldHideErrorForAuth(error)) return null;
  final text = error is ServerException ? error.message : error.toString();
  return Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(text),
        const Gap(12),
        FilledButton(onPressed: onRetry, child: const Text('Повторить')),
      ],
    ),
  );
}
