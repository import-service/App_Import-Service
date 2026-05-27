abstract class ServerException implements Exception {
  const ServerException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}

class UnauthorizedException extends ServerException {
  const UnauthorizedException([
    String message = 'Неверный логин или пароль',
    String? code,
  ]) : super(message, code: code ?? 'UNAUTHORIZED');
}

class NotFoundException extends ServerException {
  const NotFoundException([String message = 'Не найдено'])
      : super(message, code: 'NOT_FOUND');
}

class ConflictException extends ServerException {
  const ConflictException(String message, {String? code})
      : super(message, code: code ?? 'CONFLICT');
}

class OneCNotConfiguredException extends ServerException {
  const OneCNotConfiguredException([
    String message = 'URL создания заявки в 1С не задан в настройках',
  ]) : super(message, code: 'ONE_C_URL_NOT_CONFIGURED');
}

class OneCCreateFailedException extends ServerException {
  const OneCCreateFailedException(
    String message, {
    this.oneC,
  }) : super(message, code: 'ONE_C_CREATE_FAILED');

  /// Ответ/ошибка 1С с сервера (`oneC` в теле 502).
  final Map<String, dynamic>? oneC;
}

class UnknownServerException extends ServerException {
  const UnknownServerException(String message) : super(message);
}
