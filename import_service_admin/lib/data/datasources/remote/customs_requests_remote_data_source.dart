import 'package:dio/dio.dart';
import 'package:import_service_admin/core/error/error_handler.dart';
import 'package:import_service_admin/core/error/exceptions.dart';
import 'package:import_service_admin/core/logging/one_c_log.dart';
import 'package:import_service_admin/data/models/customs_request_mapper.dart';
import 'package:import_service_admin/domain/entities/customs_request.dart';

class CustomsRequestsRemoteDataSource {
  CustomsRequestsRemoteDataSource(this._dio);

  final Dio _dio;

  /// Сервер ждёт 1С до ~30 с — общий Dio 15 с обрывает запрос раньше ответа.
  static const _oneCTimeout = Duration(seconds: 65);

  Future<({List<CustomsRequest> items, int total})> listRequests({
    int limit = 100,
    int offset = 0,
    String? status,
  }) async {
    try {
      final q = <String, dynamic>{'limit': limit, 'offset': offset};
      if (status != null && status.isNotEmpty) q['status'] = status;

      final response = await _dio.get<dynamic>(
        'admin/customs-requests',
        queryParameters: q,
      );
      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw const UnknownServerException('Некорректный список заявок');
      }
      final raw = data['items'];
      final total = data['total'] is int
          ? data['total'] as int
          : int.tryParse('${data['total']}') ?? 0;
      final items = raw is List
          ? raw
              .whereType<Map<String, dynamic>>()
              .map(CustomsRequestMapper.fromJson)
              .toList(growable: false)
          : <CustomsRequest>[];
      return (items: items, total: total);
    } on DioException catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  Future<CustomsRequest> getRequest(String id) async {
    try {
      final response = await _dio.get<dynamic>(
        'admin/customs-requests/${Uri.encodeComponent(id)}',
      );
      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw const UnknownServerException('Некорректная деталка заявки');
      }
      return CustomsRequestMapper.fromJson(data);
    } on DioException catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  Future<CustomsRequest> resendTo1C(String id) async {
    try {
      final response = await _dio.post<dynamic>(
        'admin/customs-requests/${Uri.encodeComponent(id)}/resend-to-1c',
        options: Options(
          connectTimeout: _oneCTimeout,
          receiveTimeout: _oneCTimeout,
        ),
      );
      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw const UnknownServerException('Некорректный ответ отправки в 1С');
      }
      OneCLog.resendSuccess(id, data);
      final item = data['item'];
      if (item is Map<String, dynamic>) {
        return CustomsRequestMapper.fromJson(item);
      }
      throw const UnknownServerException('Нет данных заявки в ответе');
    } on DioException catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  Future<CustomsRequest> resendUpdateTo1C(String id) async {
    try {
      final response = await _dio.post<dynamic>(
        'admin/customs-requests/${Uri.encodeComponent(id)}/resend-update-to-1c',
        options: Options(
          connectTimeout: _oneCTimeout,
          receiveTimeout: _oneCTimeout,
        ),
      );
      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw const UnknownServerException(
          'Некорректный ответ повторной отправки update',
        );
      }
      OneCLog.resendSuccess(id, data);
      final item = data['item'];
      if (item is Map<String, dynamic>) {
        return CustomsRequestMapper.fromJson(item);
      }
      throw const UnknownServerException('Нет данных заявки в ответе');
    } on DioException catch (e) {
      throw ErrorHandler.handle(e);
    }
  }
}
