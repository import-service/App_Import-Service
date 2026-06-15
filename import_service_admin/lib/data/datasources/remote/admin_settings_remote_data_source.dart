import 'package:dio/dio.dart';
import 'package:import_service_admin/core/error/error_handler.dart';
import 'package:import_service_admin/core/error/exceptions.dart';
import 'package:import_service_admin/data/models/one_c_settings_model.dart';
import 'package:import_service_admin/domain/entities/one_c_settings.dart';

class AdminSettingsRemoteDataSource {
  AdminSettingsRemoteDataSource(this._dio);

  final Dio _dio;

  Future<OneCSettings> getOneCRequestCreate() async {
    try {
      final response =
          await _dio.get<dynamic>('admin/settings/one-c-request-create');
      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw const UnknownServerException('Некорректные настройки 1С');
      }
      return OneCSettingsModel.fromJson(data).toEntity();
    } on DioException catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  Future<OneCSettings> updateOneCRequestCreate({
    required String url,
    required String bearerToken,
    String? updateUrl,
  }) async {
    try {
      final response = await _dio.put<dynamic>(
        'admin/settings/one-c-request-create',
        data: <String, dynamic>{
          'oneCRequestCreateUrl': url,
          'oneCRequestCreateBearerToken': bearerToken,
          if (updateUrl != null) 'oneCRequestUpdateUrl': updateUrl,
        },
      );
      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw const UnknownServerException('Некорректный ответ сохранения');
      }
      return OneCSettingsModel.fromJson(data).toEntity();
    } on DioException catch (e) {
      throw ErrorHandler.handle(e);
    }
  }
}
