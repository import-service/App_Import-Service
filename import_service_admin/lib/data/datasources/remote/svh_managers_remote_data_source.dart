import 'package:dio/dio.dart';
import 'package:import_service_admin/core/error/error_handler.dart';
import 'package:import_service_admin/core/error/exceptions.dart';
import 'package:import_service_admin/data/models/svh_manager_model.dart';
import 'package:import_service_admin/domain/entities/svh_manager.dart';
import 'package:import_service_admin/domain/repositories/svh_managers_repository.dart';

class SvhManagersRemoteDataSource {
  SvhManagersRemoteDataSource(this._dio);

  final Dio _dio;

  Future<({List<SvhManager> items, int total})> list({
    int limit = 50,
    int offset = 0,
    bool includeDisabled = true,
  }) async {
    try {
      final response = await _dio.get<dynamic>(
        'admin/svh-managers',
        queryParameters: {
          'limit': limit,
          'offset': offset,
          if (includeDisabled) 'includeDisabled': '1',
        },
      );
      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw const UnknownServerException('Некорректный список менеджеров СВХ');
      }
      final raw = data['items'];
      final total = data['total'] is int
          ? data['total'] as int
          : int.tryParse('${data['total']}') ?? 0;
      final items = raw is List
          ? raw
              .whereType<Map<String, dynamic>>()
              .map(SvhManagerModel.fromJson)
              .map((m) => m.toEntity())
              .toList(growable: false)
          : <SvhManager>[];
      return (items: items, total: total);
    } on DioException catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  Future<SvhManager> getById(int id) async {
    try {
      final response = await _dio.get<dynamic>('admin/svh-managers/$id');
      return _parseItem(response.data, 'загрузке менеджера').item;
    } on DioException catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  Future<SvhManagerMutationResult> create({
    required String login,
    required String password,
    String? fullName,
    String? phone,
  }) async {
    try {
      final body = <String, dynamic>{
        'login': login,
        'password': password,
      };
      final name = fullName?.trim() ?? '';
      if (name.isNotEmpty) body['fullName'] = name;
      final phoneTrim = phone?.trim() ?? '';
      if (phoneTrim.isNotEmpty) body['phone'] = phoneTrim;

      final response = await _dio.post<dynamic>('admin/svh-managers', data: body);
      return _parseItem(response.data, 'создании менеджера');
    } on DioException catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  Future<SvhManagerMutationResult> update({
    required int id,
    String? login,
    String? password,
    String? fullName,
    String? phone,
    bool? active,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (login != null) body['login'] = login;
      if (password != null) body['password'] = password;
      if (fullName != null) body['fullName'] = fullName;
      if (phone != null) body['phone'] = phone;
      if (active != null) body['active'] = active;
      final response =
          await _dio.patch<dynamic>('admin/svh-managers/$id', data: body);
      return _parseItem(response.data, 'обновлении менеджера');
    } on DioException catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  Future<void> delete(int id) async {
    try {
      await _dio.delete<dynamic>('admin/svh-managers/$id');
    } on DioException catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  SvhManagerMutationResult _parseItem(dynamic data, String action) {
    if (data is! Map<String, dynamic>) {
      throw UnknownServerException('Некорректный ответ при $action');
    }
    final item = data['item'];
    if (item is! Map<String, dynamic>) {
      throw UnknownServerException('Некорректный ответ при $action');
    }
    return SvhManagerMutationResult(
      item: SvhManagerModel.fromJson(item).toEntity(),
      emailSent: data['emailSent'] == true,
    );
  }
}
