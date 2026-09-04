import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:import_service_app/core/app_update/app_update_service.dart';
import 'package:import_service_app/core/di/injection_container.dart';

/// Soft-update один раз на cold start (логин), до входа.
/// Смена сессии / демо / logout флаг не сбрасывают — повтор только после
/// перезапуска процесса (или если диалог ещё не показали из‑за отсутствия context).
final class AppUpdateBootstrap {
  AppUpdateBootstrap._();

  static bool _wired = false;
  static Timer? _debounce;

  static void ensureWired() {
    if (_wired) return;
    _wired = true;
    // ignore: avoid_print
    print('[AppUpdate] bootstrap wired (once per process)');
    _schedulePrompt('startup');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _schedulePrompt('first-frame');
    });
  }

  static void _schedulePrompt(String reason) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 700), () {
      // ignore: avoid_print
      print('[AppUpdate] bootstrap fire maybePrompt reason=$reason');
      unawaited(sl<AppUpdateService>().maybePromptForUpdate(null));
    });
  }

  /// Повтор после login, если на логине не было navigator context.
  static void scheduleAfterLogin() {
    // ignore: avoid_print
    print('[AppUpdate] scheduleAfterLogin');
    _schedulePrompt('after-login');
  }
}
