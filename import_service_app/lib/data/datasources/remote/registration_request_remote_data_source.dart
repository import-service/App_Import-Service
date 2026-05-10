import 'package:dio/dio.dart';
import 'package:import_service_app/core/error/error_handler.dart';
import 'package:import_service_app/core/error/exceptions.dart';
import 'package:import_service_app/core/logging/app_log.dart';
import 'package:import_service_app/data/models/registration_request_model.dart';

class RegistrationRequestRemoteDataSource {
  RegistrationRequestRemoteDataSource(this._dio);

  final Dio _dio;

  Future<String> send(RegistrationRequestModel request) async {
    try {
      final response = await _dio.post<dynamic>(
        'registration-request',
        data: request.toJson(),
      );
      final data = response.data;
      if (data is Map<String, dynamic>) {
        final message = data['message'];
        if (message is String && message.isNotEmpty) {
          return message;
        }
      }
      return 'Заявка отправлена';
    } on DioException catch (e, st) {
      final mapped = ErrorHandler.handle(e);
      AppLog.error(
        'Registration request failed: /api/registration-request',
        tag: 'RegistrationRequestRemoteDataSource',
        error: e,
        stackTrace: st,
      );
      throw mapped;
    } on ServerException {
      rethrow;
    } catch (e, st) {
      AppLog.error(
        'Unexpected registration request failure',
        tag: 'RegistrationRequestRemoteDataSource',
        error: e,
        stackTrace: st,
      );
      throw const UnknownServerException('Не удалось отправить заявку');
    }
  }
}
