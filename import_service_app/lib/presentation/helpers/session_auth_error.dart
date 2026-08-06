import 'package:import_service_app/core/i18n/json_strings_service.dart';

/// Коды 401, когда сервер не принимает текущий accessToken.
bool isSessionAuthErrorMessage(String raw) {
  final code = raw.trim().toUpperCase();
  if (code == 'SESSION_REVOKED_OR_EXPIRED' ||
      code == 'UNAUTHORIZED' ||
      code == 'INVALID_TOKEN' ||
      code == 'USER_NOT_FOUND') {
    return true;
  }
  return raw.toUpperCase().contains('SESSION_REVOKED_OR_EXPIRED');
}

String sessionAuthErrorMessage(JsonStringsService strings) =>
    strings.text('sessionNeedRelogin');
