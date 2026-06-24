import 'package:dio/dio.dart';
import 'package:import_service_admin/core/error/error_handler.dart';
import 'package:import_service_admin/core/error/exceptions.dart';

class StorageRemoteDataSource {
  StorageRemoteDataSource(this._dio);

  final Dio _dio;

  Future<Map<String, dynamic>> fetchStats() async {
    try {
      final response = await _dio.get<dynamic>('admin/storage/stats');
      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw const UnknownServerException('Некорректная статистика хранилища');
      }
      return data;
    } on DioException catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  Future<List<Map<String, dynamic>>> fetchExpiredClosed() async {
    try {
      final response = await _dio.get<dynamic>('admin/storage/expired-closed');
      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw const UnknownServerException('Некорректный список просроченных');
      }
      final raw = data['items'];
      if (raw is! List) return const [];
      return raw.whereType<Map<String, dynamic>>().toList(growable: false);
    } on DioException catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  Future<int> updateRetentionMonths(int months) async {
    try {
      final response = await _dio.put<dynamic>(
        'admin/storage/retention',
        data: {'retentionMonths': months},
      );
      final data = response.data;
      if (data is! Map<String, dynamic>) return months;
      return data['retentionMonths'] is int
          ? data['retentionMonths'] as int
          : int.tryParse('${data['retentionMonths']}') ?? months;
    } on DioException catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  Future<Map<String, dynamic>> purgeExpired() async {
    try {
      final response = await _dio.post<dynamic>('admin/storage/purge-expired');
      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw const UnknownServerException('Некорректный ответ очистки');
      }
      return data;
    } on DioException catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  Future<void> deleteRequest(String id) async {
    try {
      await _dio.delete<dynamic>(
        'admin/customs-requests/${Uri.encodeComponent(id)}',
      );
    } on DioException catch (e) {
      throw ErrorHandler.handle(e);
    }
  }
}
