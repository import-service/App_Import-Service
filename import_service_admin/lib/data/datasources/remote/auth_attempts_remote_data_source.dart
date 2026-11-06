import 'package:dio/dio.dart';
import 'package:import_service_admin/core/error/error_handler.dart';
import 'package:import_service_admin/core/error/exceptions.dart';

class AuthAttemptsRemoteDataSource {
  AuthAttemptsRemoteDataSource(this._dio);

  final Dio _dio;

  Future<({int total, List<Map<String, dynamic>> items})> fetchLatest({
    int limit = 50,
    int offset = 0,
    String? query,
  }) async {
    try {
      final response = await _dio.get<dynamic>(
        'admin/auth-attempts',
        queryParameters: <String, dynamic>{
          'limit': limit,
          'offset': offset,
          if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
        },
      );
      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw const UnknownServerException('Некорректный ответ auth-attempts');
      }
      final raw = data['items'];
      final items = raw is List
          ? raw.whereType<Map<String, dynamic>>().toList(growable: false)
          : const <Map<String, dynamic>>[];
      return (
        total: (data['total'] as num?)?.toInt() ?? items.length,
        items: items,
      );
    } on DioException catch (e) {
      throw ErrorHandler.handle(e);
    }
  }
}
