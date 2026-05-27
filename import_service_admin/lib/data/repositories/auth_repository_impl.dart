import 'package:import_service_admin/core/constants/app_config.dart';
import 'package:import_service_admin/data/datasources/mock/auth_mock_data_source.dart';
import 'package:import_service_admin/data/datasources/remote/auth_remote_data_source.dart';
import 'package:import_service_admin/data/models/auth_login_request_model.dart';
import 'package:import_service_admin/data/models/auth_me_response_model.dart';
import 'package:import_service_admin/domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required AuthRemoteDataSource remote,
    required AuthMockDataSource mock,
  })  : _remote = remote,
        _mock = mock;

  final AuthRemoteDataSource _remote;
  final AuthMockDataSource _mock;

  @override
  Future<String> login(AuthLoginRequestModel request) async {
    final response = AppConfig.useMockApi
        ? await _mock.login(request)
        : await _remote.login(request);
    return response.accessToken;
  }

  @override
  Future<void> logout() {
    return AppConfig.useMockApi ? _mock.logout() : _remote.logout();
  }

  @override
  Future<AuthMeResponseModel> me() {
    return AppConfig.useMockApi ? _mock.me() : _remote.me();
  }
}
