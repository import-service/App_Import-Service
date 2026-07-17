import 'package:dio/dio.dart';
import 'package:import_service_admin/core/error/error_handler.dart';
import 'package:import_service_admin/core/error/exceptions.dart';
import 'package:import_service_admin/data/models/admin_user_model.dart';
import 'package:import_service_admin/domain/entities/admin_user.dart';

class AdminUsersRemoteDataSource {
  AdminUsersRemoteDataSource(this._dio);

  final Dio _dio;

  Future<({List<AdminUser> items, int total})> list({
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final response = await _dio.get<dynamic>(
        'admin/users',
        queryParameters: {'limit': limit, 'offset': offset},
      );
      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw const UnknownServerException('Некорректный список администраторов');
      }
      final raw = data['items'];
      final total = data['total'] is int
          ? data['total'] as int
          : int.tryParse('${data['total']}') ?? 0;
      final items = raw is List
          ? raw
              .whereType<Map<String, dynamic>>()
              .map(AdminUserModel.fromJson)
              .map((m) => m.toEntity())
              .toList(growable: false)
          : <AdminUser>[];
      return (items: items, total: total);
    } on DioException catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  Future<AdminUser> create({
    required String login,
    required String password,
  }) async {
    try {
      final response = await _dio.post<dynamic>(
        'admin/users',
        data: {'login': login, 'password': password},
      );
      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw const UnknownServerException('Некорректный ответ при создании администратора');
      }
      final item = data['item'];
      if (item is! Map<String, dynamic>) {
        throw const UnknownServerException('Некорректный ответ при создании администратора');
      }
      return AdminUserModel.fromJson(item).toEntity();
    } on DioException catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  Future<void> delete(int id) async {
    try {
      await _dio.delete<dynamic>('admin/users/$id');
    } on DioException catch (e) {
      throw ErrorHandler.handle(e);
    }
  }
}
