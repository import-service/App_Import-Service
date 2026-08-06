import 'dart:async';

import 'package:import_service_app/core/auth/auth_service.dart';
import 'package:import_service_app/core/auth/auth_session_controller.dart';
import 'package:import_service_app/core/i18n/json_strings_service.dart';
import 'package:import_service_app/core/ui/app_feedback_kind.dart';
import 'package:import_service_app/core/ui/app_feedback_service.dart';
import 'package:import_service_app/presentation/helpers/session_auth_error.dart';

/// Единая реакция на мёртвую сессию сервера во всём МП:
/// clear → snackbar → GoRouter уводит на `/login`.
final class SessionLostHandler {
  SessionLostHandler({
    required AuthService authService,
    required AuthSessionController session,
    required AppFeedbackService feedback,
    required JsonStringsService strings,
  })  : _authService = authService,
        _session = session,
        _feedback = feedback,
        _strings = strings;

  final AuthService _authService;
  final AuthSessionController _session;
  final AppFeedbackService _feedback;
  final JsonStringsService _strings;

  bool _inFlight = false;

  /// Возвращает `true`, если это сессионная ошибка и запущен relogin.
  bool handleIfSessionAuthError(String? rawMessage, {bool showFeedback = true}) {
    if (!isSessionAuthErrorMessage(rawMessage ?? '')) {
      return false;
    }
    unawaited(forceRelogin(showFeedback: showFeedback));
    return true;
  }

  Future<void> forceRelogin({bool showFeedback = true}) async {
    if (_inFlight) return;
    if (!_session.isAuthenticated) return;
    _inFlight = true;
    try {
      await _authService.clearLocalSession();
      if (showFeedback) {
        _feedback.show(
          sessionAuthErrorMessage(_strings),
          kind: AppFeedbackKind.warning,
        );
      }
    } finally {
      _inFlight = false;
    }
  }
}
