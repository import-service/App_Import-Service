import 'package:dio/dio.dart';
import 'package:import_service_admin/core/error/error_handler.dart';
import 'package:import_service_admin/core/error/exceptions.dart';
import 'package:import_service_admin/data/models/organization_model.dart';
import 'package:import_service_admin/domain/entities/organization.dart';

class OrganizationsRemoteDataSource {
  OrganizationsRemoteDataSource(this._dio);

  final Dio _dio;

  Future<({List<Organization> items, int total})> list({
    int limit = 50,
    int offset = 0,
    String? query,
    bool includeDeleted = false,
  }) async {
    try {
      final q = <String, dynamic>{
        'limit': limit,
        'offset': offset,
        if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
        if (includeDeleted) 'includeDeleted': 'true',
      };
      final response = await _dio.get<dynamic>(
        'admin/organizations',
        queryParameters: q,
      );
      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw const UnknownServerException('Некорректный список организаций');
      }
      final raw = data['items'];
      final total = data['total'] is int
          ? data['total'] as int
          : int.tryParse('${data['total']}') ?? 0;
      final items = raw is List
          ? raw
              .whereType<Map<String, dynamic>>()
              .map(OrganizationModel.fromJson)
              .map((m) => m.toEntity())
              .toList(growable: false)
          : <Organization>[];
      return (items: items, total: total);
    } on DioException catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  Future<Organization> getById(int id) async {
    try {
      final response = await _dio.get<dynamic>('admin/organizations/$id');
      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw const UnknownServerException('Некорректная карточка организации');
      }
      final item = data['item'];
      if (item is! Map<String, dynamic>) {
        throw const NotFoundException();
      }
      return OrganizationModel.fromJson(item).toEntity();
    } on DioException catch (e) {
      throw ErrorHandler.handle(e);
    }
  }
}
