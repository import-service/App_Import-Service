import 'package:import_service_app/core/error/exceptions.dart';
import 'package:import_service_app/core/i18n/json_strings_service.dart';

/// Текст для SnackBar на экране входа — без сырых кодов API (`INVALID_CREDENTIALS`).
String loginErrorMessage(ServerException exception, JsonStringsService strings) {
  if (exception is NoInternetConnectionException ||
      exception is RequestTimeoutException) {
    return strings.loginNetworkError;
  }

  final code = exception.message.trim().toUpperCase();
  if (code == 'INVALID_CREDENTIALS') {
    return strings.loginInvalidCredentials;
  }

  if (_looksLikeApiErrorCode(code)) {
    return strings.loginUnknownError;
  }

  return strings.loginUnknownError;
}

bool _looksLikeApiErrorCode(String value) {
  if (value.isEmpty) return false;
  return RegExp(r'^[A-Z][A-Z0-9_]+$').hasMatch(value);
}
