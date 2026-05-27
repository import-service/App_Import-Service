import 'package:import_service_admin/data/models/auth_login_request_model.dart';
import 'package:import_service_admin/data/models/auth_me_response_model.dart';

abstract class AuthRepository {
  Future<String> login(AuthLoginRequestModel request);

  Future<void> logout();

  Future<AuthMeResponseModel> me();
}
