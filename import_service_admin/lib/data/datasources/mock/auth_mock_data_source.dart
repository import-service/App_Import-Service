import 'package:import_service_admin/core/constants/app_config.dart';
import 'package:import_service_admin/core/error/exceptions.dart';
import 'package:import_service_admin/data/datasources/mock/mock_json_loader.dart';
import 'package:import_service_admin/data/models/auth_login_request_model.dart';
import 'package:import_service_admin/data/models/auth_login_response_model.dart';
import 'package:import_service_admin/data/models/auth_me_response_model.dart';

class AuthMockDataSource {
  AuthMockDataSource(this._loader);

  final MockJsonLoader _loader;

  static const _loginAsset = 'assets/mocks/auth_login_success.json';
  static const _meAsset = 'assets/mocks/auth_me_admin.json';

  /// Совместимость с [AuthRemoteDataSource] — те же контракты, пути admin/* на сервере.

  Future<AuthLoginResponseModel> login(AuthLoginRequestModel request) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (request.login != AppConfig.mockLogin ||
        request.password != AppConfig.mockPassword) {
      throw const UnauthorizedException();
    }
    final json = await _loader.loadMap(_loginAsset);
    return AuthLoginResponseModel.fromJson(json);
  }

  Future<void> logout() async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }

  Future<AuthMeResponseModel> me() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final json = await _loader.loadMap(_meAsset);
    return AuthMeResponseModel.fromJson(json);
  }
}
