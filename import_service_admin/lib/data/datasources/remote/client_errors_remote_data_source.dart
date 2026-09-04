import 'package:dio/dio.dart';
import 'package:import_service_admin/core/error/error_handler.dart';
import 'package:import_service_admin/core/error/exceptions.dart';

class ClientErrorsRemoteDataSource {
  ClientErrorsRemoteDataSource(this._dio);

  final Dio _dio;

  Future<({int total, int retentionDays, List<Map<String, dynamic>> items})>
      fetchLatest({int limit = 50, int offset = 0}) async {
    try {
      final response = await _dio.get<dynamic>(
        'admin/client-errors',
        queryParameters: <String, dynamic>{
          'limit': limit,
          'offset': offset,
        },
      );
      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw const UnknownServerException('Некорректный ответ client-errors');
      }
      final raw = data['items'];
      final items = raw is List
          ? raw.whereType<Map<String, dynamic>>().toList(growable: false)
          : const <Map<String, dynamic>>[];
      return (
        total: (data['total'] as num?)?.toInt() ?? items.length,
        retentionDays: (data['retentionDays'] as num?)?.toInt() ?? 14,
        items: items,
      );
    } on DioException catch (e) {
      throw ErrorHandler.handle(e);
    }
  }
}
