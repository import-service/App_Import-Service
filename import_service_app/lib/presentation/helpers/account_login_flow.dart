import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:import_service_app/core/app_update/app_update_bootstrap.dart';
import 'package:import_service_app/core/app_update/app_update_service.dart';
import 'package:import_service_app/core/auth/auth_service.dart';
import 'package:import_service_app/core/auth/auth_session_controller.dart';
import 'package:import_service_app/core/auth/recent_account.dart';
import 'package:import_service_app/core/auth/session_preferences_keys.dart';
import 'package:import_service_app/core/auth/session_role.dart';
import 'package:import_service_app/core/di/injection_container.dart';
import 'package:import_service_app/core/i18n/json_strings_service.dart';
import 'package:import_service_app/core/ui/app_feedback_kind.dart';
import 'package:import_service_app/core/ui/app_feedback_service.dart';
import 'package:import_service_app/domain/entities/car_list_item.dart';
import 'package:import_service_app/domain/repositories/cars_repository.dart';
import 'package:import_service_app/presentation/bloc/car_inventory/car_inventory_cubit.dart';
import 'package:import_service_app/presentation/bloc/chat_list/chat_list_cubit.dart';
import 'package:import_service_app/presentation/bloc/request_chat_unread/request_chat_unread_cubit.dart';
import 'package:import_service_app/presentation/bloc/request_draft/request_draft_cubit.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Сброс prefs при выходе: язык + last email. История аккаунтов в secure storage.
Future<void> clearSessionPrefsKeepLanguage() async {
  final prefs = sl<SharedPreferences>();
  final lang = prefs.getString('app_language');
  final lastEmail = prefs.getString(SessionPreferencesKeys.authLastEmail);
  await prefs.clear();
  if (lang != null) {
    await prefs.setString('app_language', lang);
  }
  if (lastEmail != null) {
    await prefs.setString(SessionPreferencesKeys.authLastEmail, lastEmail);
  }
}

Future<void> resetLocalStateAfterLogout() async {
  await clearSessionPrefsKeepLanguage();
  await sl<RequestDraftCubit>().clearAll();
  await sl<CarInventoryCubit>().reloadFromDisk();
  sl<RequestChatUnreadCubit>().clearAll();
  sl<ChatListCubit>().reset();
  sl<AppUpdateService>().resetSessionFlag();
}

/// Обычный POST login + локальный bootstrap + переход в shell роли.
Future<void> completeCredentialLogin({
  required BuildContext context,
  required String login,
  required String password,
}) async {
  await sl<AuthService>().login(login: login, password: password);
  await sl<RequestDraftCubit>().clearAll();
  await sl<CarInventoryCubit>().replaceAll(const <CarListItem>[]);
  final session = sl<AuthSessionController>();
  if (!isSvhManagerSession(session)) {
    await sl<CarsRepository>().listVehicles();
  }
  final prefs = sl<SharedPreferences>();
  await prefs.setString(SessionPreferencesKeys.authLastEmail, login.trim());
  await prefs.remove(SessionPreferencesKeys.authLastPassword);
  if (!context.mounted) return;
  final strings = sl<JsonStringsService>();
  final roleLine = strings.text('sessionRoleSignedInAs').replaceAll(
        '{role}',
        roleDisplayLabel(session.role ?? kUserRole),
      );
  context.go(homeLocationForSession(session));
  sl<AppFeedbackService>().show(roleLine, kind: AppFeedbackKind.success);
  AppUpdateBootstrap.scheduleAfterLogin();
}

/// Выход из текущего + обычный вход сохранёнными логином/паролем.
Future<void> switchToRecentAccount({
  required BuildContext context,
  required RecentAccount account,
}) async {
  final session = sl<AuthSessionController>();
  final currentLogin = (session.login ?? session.email ?? '').trim().toLowerCase();
  if (session.isAuthenticated && currentLogin == account.email) {
    return;
  }

  if (session.isAuthenticated) {
    await sl<AuthService>().logout();
  } else {
    session.clear();
  }
  await resetLocalStateAfterLogout();
  if (!context.mounted) return;
  await completeCredentialLogin(
    context: context,
    login: account.email,
    password: account.password,
  );
}
