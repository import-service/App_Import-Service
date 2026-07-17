import 'package:dio/dio.dart';

/// При 401 (кроме входа) очищает локальную сессию — [GoRouter] уводит на `/login`.
class SessionExpiredInterceptor extends Interceptor {
  SessionExpiredInterceptor({Future<void> Function()? onSessionExpired})
      : _onSessionExpired = onSessionExpired;

  final Future<void> Function()? _onSessionExpired;

  static bool _isLoginRequest(RequestOptions options) {
    final path = options.path.toLowerCase();
    return path.contains('admin/auth/login');
  }

  /// Превью/скачивание файлов: 401 не значит «сессия админа умерла».
  static bool _skipSessionExpired(RequestOptions options) {
    if (options.extra['skipSessionExpired'] == true) return true;
    final path = options.path.toLowerCase();
    final full = options.uri.toString().toLowerCase();
    return path.contains('customs-requests/files/') ||
        full.contains('customs-requests/files/');
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == 401 &&
        !_isLoginRequest(err.requestOptions) &&
        !_skipSessionExpired(err.requestOptions)) {
      final callback = _onSessionExpired;
      if (callback != null) {
        callback();
      }
    }
    handler.next(err);
  }
}
