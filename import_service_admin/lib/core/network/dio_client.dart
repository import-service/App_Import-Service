import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:import_service_admin/core/constants/api_config.dart';

class DioClient {
  DioClient({String? Function()? tokenProvider})
      : _tokenProvider = tokenProvider {
    final baseUrl = _normalizeBaseUrl(ApiConfig.baseUrl);
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        sendTimeout: kIsWeb ? null : const Duration(seconds: 15),
        headers: <String, dynamic>{
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );
    _dio.interceptors.add(_AuthInterceptor(_tokenProvider));
    if (kDebugMode) {
      _dio.interceptors.add(
        LogInterceptor(requestBody: true, responseBody: true, error: true),
      );
    }
  }

  late final Dio _dio;
  final String? Function()? _tokenProvider;

  Dio get dio => _dio;

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
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = _tokenProvider?.call();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }
}
