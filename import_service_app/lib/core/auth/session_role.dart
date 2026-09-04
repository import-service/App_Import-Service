import 'package:import_service_app/core/auth/auth_session_controller.dart';

/// Роль менеджера СВХ (organizations.role / JWT).
const String kSvhManagerRole = 'svh_manager';

bool isSvhManagerSession(AuthSessionController session) {
  if (session.isDemo) return false;
  return session.role == kSvhManagerRole;
}

/// Куда вести после логина / restore.
String homeLocationForSession(AuthSessionController session) {
  if (isSvhManagerSession(session)) return '/svh-home';
  return '/home';
}
