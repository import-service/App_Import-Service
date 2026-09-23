import 'package:import_service_app/core/auth/auth_session_controller.dart';

/// Роль менеджера СВХ (organizations.role / JWT).
const String kSvhManagerRole = 'svh_manager';

/// Роль менеджера-декларанта (каталог заявок без медиа СВХ).
const String kDeclarantManagerRole = 'declarant_manager';

/// Обычный клиент / заявитель.
const String kUserRole = 'user';

bool isSvhManagerSession(AuthSessionController session) {
  if (session.isDemo) return false;
  return session.role == kSvhManagerRole;
}

bool isDeclarantManagerSession(AuthSessionController session) {
  if (session.isDemo) return false;
  return session.role == kDeclarantManagerRole;
}

/// СВХ или декларант: каталог всех заявок.
bool isCatalogStaffSession(AuthSessionController session) {
  return isSvhManagerSession(session) || isDeclarantManagerSession(session);
}

/// Куда вести после логина / restore / смены роли.
String homeLocationForSession(AuthSessionController session) {
  if (isSvhManagerSession(session)) return '/svh-home';
  if (isDeclarantManagerSession(session)) return '/declarant-home';
  return '/home';
}

/// Человекочитаемая подпись роли для UI переключения.
String roleDisplayLabel(String role) {
  switch (role) {
    case kSvhManagerRole:
      return 'Менеджер СВХ';
    case kDeclarantManagerRole:
      return 'Декларант';
    case 'admin':
      return 'Админ';
    case kUserRole:
    default:
      return 'Клиент';
  }
}
