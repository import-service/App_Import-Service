import 'package:flutter/material.dart';
import 'package:import_service_app/core/themes/app_theme.dart';
import 'package:import_service_app/core/ui/app_feedback_kind.dart';
import 'package:import_service_app/core/ui/app_scaffold_messenger_key.dart';

/// Централизованный показ SnackBar (успех / предупреждение / ошибка).
///
/// Регистрируется в GetIt как синглтон; требует [appScaffoldMessengerKey] в [MaterialApp].
class AppFeedbackService {
  static const Duration _duration = Duration(seconds: 4);

  void show(
    String message, {
    AppFeedbackKind kind = AppFeedbackKind.error,
    bool clearSnackBars = true,
  }) {
    final messenger = appScaffoldMessengerKey.currentState;
    if (messenger == null) return;

    final bg = _background(kind);
    final fg = _foreground(kind);

    if (clearSnackBars) {
      messenger.clearSnackBars();
    }
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(color: fg, fontWeight: FontWeight.w500),
        ),
        backgroundColor: bg,
        behavior: SnackBarBehavior.floating,
        duration: _duration,
      ),
    );
  }

  Color _background(AppFeedbackKind kind) {
    switch (kind) {
      case AppFeedbackKind.success:
        return const Color(0xFF2E7D32);
      case AppFeedbackKind.warning:
        return const Color(0xFFF9A825);
      case AppFeedbackKind.error:
        return AppTheme.accentRed;
    }
  }

  Color _foreground(AppFeedbackKind kind) {
    switch (kind) {
      case AppFeedbackKind.warning:
        return const Color(0xFF1A1A1A);
      case AppFeedbackKind.success:
      case AppFeedbackKind.error:
        return AppTheme.white;
    }
  }
}
