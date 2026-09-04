import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:import_service_app/core/constants/api_config.dart';
import 'package:import_service_app/presentation/helpers/session_auth_error.dart';

/// Обертка над [Dio]: base URL, таймауты, заголовки, перехватчики.
class DioClient {
  DioClient({
    String? Function()? tokenProvider,
    void Function(String rawError)? onSessionAuthError,
  })  : _tokenProvider = tokenProvider,
        _onSessionAuthError = onSessionAuthError {
    final baseUrl = _normalizeBaseUrl(ApiConfig.baseUrl);
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        sendTimeout: const Duration(seconds: 15),
        headers: <String, dynamic>{
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );
    _dio.interceptors.add(_AuthInterceptor(_tokenProvider));
    _dio.interceptors.add(_SessionAuthInterceptor(_onSessionAuthError));
    if (kDebugMode) {
      _dio.interceptors.add(
        LogInterceptor(
          requestBody: true,
          responseBody: true,
          error: true,
        ),
      );
    }
  }

  late final Dio _dio;
  final String? Function()? _tokenProvider;
  final void Function(String rawError)? _onSessionAuthError;

  Dio get dio => _dio;

  /// Без завершающего `/` Dio склеивает сегменты без слэша.
  static String _normalizeBaseUrl(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '/';
    return trimmed.endsWith('/') ? trimmed : '$trimmed/';
  }
}

class _AuthInterceptor extends Interceptor {
  _AuthInterceptor(this._tokenProvider);

  final String? Function()? _tokenProvider;

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) {
    final token = _tokenProvider?.call();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }
}

class _SessionAuthInterceptor extends Interceptor {
  _SessionAuthInterceptor(this._onSessionAuthError);

  final void Function(String rawError)? _onSessionAuthError;

  static bool _isAuthExempt(RequestOptions options) {
    final path = options.path.toLowerCase();
    final uri = options.uri.path.toLowerCase();
    final probe = '$path $uri';
    return probe.contains('auth/login') ||
        probe.contains('registration') ||
        probe.contains('auth/logout') ||
        probe.contains('store-versions') ||
        probe.contains('client-errors');
  }

  static String _errorCode(DioException err) {
    final data = err.response?.data;
    if (data is Map) {
      final e = data['error'] ?? data['message'] ?? data['detail'];
      if (e != null) return e.toString();
    }
    if (data is String) return data;
    return '';
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == 401 && !_isAuthExempt(err.requestOptions)) {
      final code = _errorCode(err).trim();
      if (code.isEmpty || isSessionAuthErrorMessage(code)) {
        _onSessionAuthError?.call(code.isEmpty ? 'UNAUTHORIZED' : code);
      }
    }
    handler.next(err);
  }
}
