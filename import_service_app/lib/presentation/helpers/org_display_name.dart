import 'package:import_service_app/core/auth/auth_session_controller.dart';

/// Отображаемое наименование организации/ИП (не login/email).
///
/// Если в БД ошибочно лежит email (= login) — не показываем его как название.
String orgDisplayNameFromSession(AuthSessionController session) {
  final company = (session.companyName ?? '').trim();
  final fullName = (session.fullName ?? '').trim();
  final login = (session.login ?? '').trim();

  String? pick(String v) {
    if (v.isEmpty) return null;
    if (v == login) return null;
    if (v.contains('@')) return null;
    return v;
  }

  return pick(fullName) ?? pick(company) ?? '—';
}

bool looksLikeEmailOrLogin(String? raw, {String? login}) {
  final v = (raw ?? '').trim();
  if (v.isEmpty) return true;
  if (login != null && v == login.trim()) return true;
  return v.contains('@');
}
