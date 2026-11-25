import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:import_service_app/core/auth/auth_session_controller.dart';
import 'package:import_service_app/core/di/injection_container.dart';
import 'package:import_service_app/presentation/bloc/request_draft/request_draft_cubit.dart';

/// Регрессия 1.0.61/1.0.62: initDependencies падал до runApp (белый экран),
/// когда обращение к `sl<AuthSessionController>` шло до его регистрации.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const secureChannel = MethodChannel(
    'plugins.it_nomads.com/flutter_secure_storage',
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureChannel, (call) async => null);
    await GetIt.instance.reset();
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureChannel, null);
    await GetIt.instance.reset();
  });

  test('initDependencies completes and registers core singletons', () async {
    await initDependencies();
    expect(sl.isRegistered<RequestDraftCubit>(), isTrue);
    expect(sl.isRegistered<AuthSessionController>(), isTrue);
    expect(sl.isRegistered<SharedPreferences>(), isTrue);
  });
}
