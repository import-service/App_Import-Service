import 'package:dio/dio.dart';
import 'package:import_service_admin/core/error/exceptions.dart';

class ErrorHandler {
  const ErrorHandler._();

  static ServerException handle(DioException exception) {
    if (_isTimeout(exception)) {
      return const UnknownServerException(
        'Превышено время ожидания: сервер ждёт ответа 1С. Повторите позже.',
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
        if (code == 'ONE_C_UPDATE_FAILED') {
          return OneCCreateFailedException(message, oneC: _oneCDetail(body));
        }
        return OneCCreateFailedException(message, oneC: _oneCDetail(body));
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
      if (e is String && e.trim().isNotEmpty) return e.trim();
    }
    final f = fallback?.trim();
    return (f == null || f.isEmpty) ? 'Ошибка сервера' : f;
  }
}
