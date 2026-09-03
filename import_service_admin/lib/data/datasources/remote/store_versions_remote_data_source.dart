import 'package:dio/dio.dart';
import 'package:import_service_admin/core/error/error_handler.dart';
import 'package:import_service_admin/core/error/exceptions.dart';

class StoreVersionsRemoteDataSource {
  StoreVersionsRemoteDataSource(this._dio);

  final Dio _dio;

  Future<List<Map<String, dynamic>>> fetchLatest() async {
    try {
      final response = await _dio.get<dynamic>('admin/store-versions');
      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw const UnknownServerException('Некорректный ответ версий сторов');
      }
      final raw = data['stores'];
      if (raw is! List) return const [];
      return raw.whereType<Map<String, dynamic>>().toList(growable: false);
    } on DioException catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  Future<List<Map<String, dynamic>>> scanNow() async {
    try {
      final response = await _dio.post<dynamic>('admin/store-versions/scan');
      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw const UnknownServerException('Некорректный ответ сканирования');
      }
      final raw = data['stores'];
      if (raw is! List) return const [];
      return raw.whereType<Map<String, dynamic>>().toList(growable: false);
    } on DioException catch (e) {
      throw ErrorHandler.handle(e);
    }
  }
}
