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

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == 401 &&
        !_isLoginRequest(err.requestOptions)) {
      final callback = _onSessionExpired;
      if (callback != null) {
        callback();
      }
    }
    handler.next(err);
  }
}
