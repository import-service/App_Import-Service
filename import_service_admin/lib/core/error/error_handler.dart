import 'package:dio/dio.dart';
import 'package:import_service_admin/core/error/exceptions.dart';

class ErrorHandler {
  const ErrorHandler._();

  static ServerException handle(DioException exception) {
    if (_isTimeout(exception)) {
      return const UnknownServerException(
        'Превышено время ожидания ответа сервера. Повторите позже.',
      );
    }

    final status = exception.response?.statusCode;
    final body = exception.response?.data;
    final code = _errorCode(body);
    final message = _message(body, exception.message);

    switch (status) {
      case 401:
        if (code == 'SESSION_REVOKED_OR_EXPIRED') {
          return const UnauthorizedException(
            'Сессия истекла',
            'SESSION_REVOKED_OR_EXPIRED',
          );
        }
        return UnauthorizedException(message, code);
      case 403:
        return UnknownServerException(message);
      case 404:
        return NotFoundException(message);
      case 409:
        return ConflictException(message, code: code);
      case 502:
        // 502 от интеграции 1С — только по коду ONE_C_*. Остальное — обычная ошибка сервера.
        if (code != null && code.startsWith('ONE_C_')) {
          if (code == 'ONE_C_URL_NOT_CONFIGURED') {
            return OneCNotConfiguredException(message);
          }
          return OneCCreateFailedException(message, oneC: _oneCDetail(body));
        }
        return UnknownServerException(message);
      case 503:
        if (code == 'ONE_C_URL_NOT_CONFIGURED') {
          return OneCNotConfiguredException(message);
        }
        return UnknownServerException(message);
      default:
        return UnknownServerException(message);
    }
  }

  static bool _isTimeout(DioException exception) {
    return switch (exception.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.sendTimeout =>
        true,
      _ => false,
    };
  }

  static Map<String, dynamic>? _oneCDetail(dynamic data) {
    if (data is Map<String, dynamic>) {
      final oneC = data['oneC'];
      if (oneC is Map<String, dynamic>) return oneC;
    }
    return null;
  }

  static String? _errorCode(dynamic data) {
    if (data is Map<String, dynamic>) {
      final e = data['error'];
      if (e is String) return e;
    }
    return null;
  }

  static String _message(dynamic data, String? fallback) {
    if (data is Map<String, dynamic>) {
      final m = data['message'];
      if (m is String && m.trim().isNotEmpty) return m.trim();
      final e = data['error'];
      if (e is String && e.trim().isNotEmpty) {
        return _localizeErrorCode(e.trim());
      }
    }
    final f = fallback?.trim();
    return (f == null || f.isEmpty) ? 'Ошибка сервера' : f;
  }

  /// Коды API → текст для UI (не показываем сырой ENGLISH_CODE).
  static String _localizeErrorCode(String code) {
    switch (code) {
      case 'INVALID_CREDENTIALS':
        return 'Неверный логин или пароль';
      case 'UNAUTHORIZED':
        return 'Нужна авторизация';
      case 'SESSION_REVOKED_OR_EXPIRED':
        return 'Сессия истекла';
      case 'FORBIDDEN':
        return 'Недостаточно прав';
      case 'NOT_FOUND':
        return 'Не найдено';
      case 'VALIDATION_ERROR':
        return 'Проверьте введённые данные';
      case 'LOGIN_ALREADY_EXISTS':
        return 'Такой логин уже занят';
      case 'GONE':
        return 'Действие больше не поддерживается';
      case 'TOO_MANY_REQUESTS':
        return 'Слишком много попыток входа, попробуйте позже';
      default:
        if (RegExp(r'^[A-Z][A-Z0-9_]+$').hasMatch(code)) {
          return 'Ошибка сервера';
        }
        return code;
    }
  }
}
