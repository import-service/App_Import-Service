import 'package:dio/dio.dart';
import 'package:import_service_admin/core/error/error_handler.dart';
import 'package:import_service_admin/core/error/exceptions.dart';
import 'package:import_service_admin/data/models/auth_login_request_model.dart';
import 'package:import_service_admin/data/models/auth_login_response_model.dart';
import 'package:import_service_admin/data/models/auth_me_response_model.dart';

class AuthRemoteDataSource {
  AuthRemoteDataSource(this._dio);

  final Dio _dio;

  Future<AuthLoginResponseModel> login(AuthLoginRequestModel request) async {
    try {
      final response = await _dio.post<dynamic>(
        'admin/auth/login',
        data: request.toJson(),
      );
      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw const UnknownServerException('Некорректный ответ входа');
      }
      return AuthLoginResponseModel.fromJson(data);
    } on DioException catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  Future<void> logout() async {
    try {
      await _dio.post<dynamic>('admin/auth/logout');
    } on DioException catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  Future<AuthMeResponseModel> me() async {
    try {
      final response = await _dio.get<dynamic>('admin/auth/me');
      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw const UnknownServerException('Некорректный ответ профиля');
      }
      return AuthMeResponseModel.fromJson(data);
    } on DioException catch (e) {
      throw ErrorHandler.handle(e);
    }
  }
}
