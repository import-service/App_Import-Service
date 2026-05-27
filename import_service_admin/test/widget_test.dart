import 'package:flutter_test/flutter_test.dart';
import 'package:import_service_admin/core/constants/app_config.dart';

void main() {
  test('mock credentials are configured', () {
    expect(AppConfig.mockLogin, 'admin');
    expect(AppConfig.mockPassword, '123456');
    expect(AppConfig.useMockApi, isFalse);
  });
}
