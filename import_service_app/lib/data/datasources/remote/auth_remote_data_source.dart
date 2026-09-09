import 'package:dio/dio.dart';
import 'package:import_service_app/core/error/error_handler.dart';
import 'package:import_service_app/core/error/exceptions.dart';
import 'package:import_service_app/core/logging/app_log.dart';
import 'package:import_service_app/data/models/auth_login_request_model.dart';
import 'package:import_service_app/data/models/auth_login_response_model.dart';
import 'package:import_service_app/data/models/auth_me_response_model.dart';

class AuthRemoteDataSource {
  AuthRemoteDataSource(this._dio);

  final Dio _dio;

  Future<AuthLoginResponseModel> login(AuthLoginRequestModel request) async {
    try {
      final response = await _dio.post<dynamic>(
        'auth/login',
        data: request.toJson(),
      );
      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw const UnknownServerException('Invalid login response format');
      }
      return AuthLoginResponseModel.fromJson(data);
    } on DioException catch (e, st) {
      final mapped = ErrorHandler.handle(e);
      final isExpectedAuth = mapped is UnauthorizedException ||
          e.response?.statusCode == 401;
      AppLog.error(
        'Login failed: /api/auth/login',
        tag: 'AuthRemoteDataSource',
        error: e,
        stackTrace: st,
        reportRemote: !isExpectedAuth,
      );
      throw mapped;
    } on ServerException {
      rethrow;
    } catch (e, st) {
      AppLog.error(
        'Unexpected login failure',
        tag: 'AuthRemoteDataSource',
        error: e,
        stackTrace: st,
      );
      throw const UnknownServerException('Не удалось выполнить вход');
    }
  }

  Future<void> logout() async {
    try {
      await _dio.post<dynamic>('auth/logout');
    } on DioException catch (e, st) {
      final mapped = ErrorHandler.handle(e);
      AppLog.error(
        'Logout failed: /api/auth/logout',
        tag: 'AuthRemoteDataSource',
        error: e,
        stackTrace: st,
      );
      throw mapped;
    } on ServerException {
      rethrow;
    } catch (e, st) {
      AppLog.error(
        'Unexpected logout failure',
        tag: 'AuthRemoteDataSource',
        error: e,
        stackTrace: st,
      );
      throw const UnknownServerException('Не удалось выполнить выход');
    }
  }

  Future<AuthMeResponseModel> me() async {
    try {
      final response = await _dio.get<dynamic>('auth/me');
      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw const UnknownServerException('Invalid profile response format');
      }
      return AuthMeResponseModel.fromJson(data);
    } on DioException catch (e, st) {
      final mapped = ErrorHandler.handle(e);
      AppLog.error(
        'Profile request failed: /api/auth/me',
        tag: 'AuthRemoteDataSource',
        error: e,
        stackTrace: st,
      );
      throw mapped;
    } on ServerException {
      rethrow;
    } catch (e, st) {
      AppLog.error(
        'Unexpected profile failure',
        tag: 'AuthRemoteDataSource',
        error: e,
        stackTrace: st,
      );
      throw const UnknownServerException('Не удалось получить профиль');
    }
  }

  Future<AuthMeResponseModel> updateMe({
    String? companyName,
    String? inn,
    String? phone,
    String? orgType,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (companyName != null) data['companyName'] = companyName;
      if (inn != null) data['inn'] = inn;
      if (phone != null) data['phone'] = phone;
      if (orgType != null) data['orgType'] = orgType;
      final response = await _dio.patch<dynamic>('auth/me', data: data);
      final body = response.data;
      if (body is! Map<String, dynamic>) {
        throw const UnknownServerException('Invalid profile update response');
      }
      return AuthMeResponseModel.fromJson(body);
    } on DioException catch (e, st) {
      final mapped = ErrorHandler.handle(e);
      AppLog.error(
        'Profile update failed: PATCH /api/auth/me',
        tag: 'AuthRemoteDataSource',
        error: e,
        stackTrace: st,
      );
      throw mapped;
    } on ServerException {
      rethrow;
    } catch (e, st) {
      AppLog.error(
        'Unexpected profile update failure',
        tag: 'AuthRemoteDataSource',
        error: e,
        stackTrace: st,
      );
      throw const UnknownServerException('Не удалось обновить профиль');
    }
  }
}
