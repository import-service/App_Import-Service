import 'package:import_service_app/core/i18n/json_strings_service.dart';

/// Коды 401, когда сервер не принимает текущий accessToken.
bool isSessionAuthErrorMessage(String raw) {
  final code = raw.trim().toUpperCase();
  return code == 'SESSION_REVOKED_OR_EXPIRED' ||
      code == 'UNAUTHORIZED' ||
      code == 'USER_NOT_FOUND';
}

String sessionAuthErrorMessage(JsonStringsService strings) =>
    strings.text('sessionNeedRelogin');
