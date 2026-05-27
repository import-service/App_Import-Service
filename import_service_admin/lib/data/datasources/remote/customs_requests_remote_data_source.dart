import 'package:dio/dio.dart';
import 'package:import_service_admin/core/error/error_handler.dart';
import 'package:import_service_admin/core/error/exceptions.dart';
import 'package:import_service_admin/core/logging/one_c_log.dart';
import 'package:import_service_admin/domain/entities/customs_request_summary.dart';

class CustomsRequestsRemoteDataSource {
  CustomsRequestsRemoteDataSource(this._dio);

  final Dio _dio;

  /// Сервер ждёт 1С до ~30 с — общий Dio 15 с обрывает запрос раньше ответа.
  static const _oneCTimeout = Duration(seconds: 65);

  Future<({List<CustomsRequestSummary> items, int total})> listRequests({
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
              .map(_toEntity)
              .toList(growable: false)
          : <CustomsRequestSummary>[];
      return (items: items, total: total);
    } on DioException catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  Future<CustomsRequestSummary> resendTo1C(String id) async {
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
        return _toEntity(item);
      }
      throw const UnknownServerException('Нет данных заявки в ответе');
    } on DioException catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  Future<CustomsRequestSummary> resendUpdateTo1C(String id) async {
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
        throw const UnknownServerException('Некорректный ответ повторной отправки update');
      }
      OneCLog.resendSuccess(id, data);
      final item = data['item'];
      if (item is Map<String, dynamic>) {
        return _toEntity(item);
      }
      throw const UnknownServerException('Нет данных заявки в ответе');
    } on DioException catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  CustomsRequestSummary _toEntity(Map<String, dynamic> json) {
    return CustomsRequestSummary(
      id: json['id']?.toString() ?? '',
      ownerFullName: json['ownerFullName'] as String? ?? '',
      carMake: json['carMake'] as String? ?? '',
      carModel: json['carModel'] as String? ?? '',
      vin: json['vin'] as String? ?? '',
      status: json['status'] as String? ?? 'new',
      statusSinceDateLabel: json['statusSinceDateLabel'] as String?,
      isTest: json['isTest'] == true,
      managerFullName: json['managerFullName'] as String?,
      external1cId: json['external1cId'] as String?,
      oneCUpdatePending: json['oneCUpdatePending'] == true,
    );
  }
}
