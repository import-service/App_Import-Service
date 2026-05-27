import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';
import 'package:import_service_admin/core/auth/auth_service.dart';
import 'package:import_service_admin/core/auth/auth_session_controller.dart';
import 'package:import_service_admin/core/auth/auth_storage_keys.dart';
import 'package:import_service_admin/core/network/dio_client.dart';
import 'package:import_service_admin/core/network/session_expired_interceptor.dart';
import 'package:import_service_admin/core/storage/secure_storage_service.dart';
import 'package:import_service_admin/data/datasources/mock/auth_mock_data_source.dart';
import 'package:import_service_admin/data/datasources/mock/customs_requests_mock_data_source.dart';
import 'package:import_service_admin/data/datasources/mock/mock_json_loader.dart';
import 'package:import_service_admin/data/datasources/remote/admin_settings_remote_data_source.dart';
import 'package:import_service_admin/data/datasources/remote/auth_remote_data_source.dart';
import 'package:import_service_admin/data/datasources/remote/customs_requests_remote_data_source.dart';
import 'package:import_service_admin/data/datasources/remote/organizations_remote_data_source.dart';
import 'package:import_service_admin/data/repositories/admin_settings_repository_impl.dart';
import 'package:import_service_admin/data/repositories/auth_repository_impl.dart';
import 'package:import_service_admin/data/repositories/customs_requests_repository_impl.dart';
import 'package:import_service_admin/data/repositories/organizations_repository_impl.dart';
import 'package:import_service_admin/domain/repositories/admin_settings_repository.dart';
import 'package:import_service_admin/domain/repositories/auth_repository.dart';
import 'package:import_service_admin/domain/repositories/customs_requests_repository.dart';
import 'package:import_service_admin/domain/repositories/organizations_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

final sl = GetIt.instance;

Future<void> initDependencies() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  sl.registerSingleton<SharedPreferences>(prefs);

  sl.registerLazySingleton<SecureStorageService>(SecureStorageService.new);
  sl.registerLazySingleton<AuthSessionController>(AuthSessionController.new);
  sl.registerLazySingleton<MockJsonLoader>(MockJsonLoader.new);

  final session = sl<AuthSessionController>();
  final restoredToken =
      await sl<SecureStorageService>().read(AuthStorageKeys.accessToken);
  session.restore(
    restoredToken != null && restoredToken.trim().isNotEmpty
        ? restoredToken
        : null,
  );

  sl.registerLazySingleton<DioClient>(
    () => DioClient(
      tokenProvider: () => sl<AuthSessionController>().accessToken,
    ),
  );
  sl.registerLazySingleton<Dio>(() => sl<DioClient>().dio);

  sl.registerLazySingleton<AuthRemoteDataSource>(
    () => AuthRemoteDataSource(sl<Dio>()),
  );
  sl.registerLazySingleton<CustomsRequestsRemoteDataSource>(
    () => CustomsRequestsRemoteDataSource(sl<Dio>()),
  );
  sl.registerLazySingleton<OrganizationsRemoteDataSource>(
    () => OrganizationsRemoteDataSource(sl<Dio>()),
  );
  sl.registerLazySingleton<AdminSettingsRemoteDataSource>(
    () => AdminSettingsRemoteDataSource(sl<Dio>()),
  );
  sl.registerLazySingleton<AuthMockDataSource>(
    () => AuthMockDataSource(sl<MockJsonLoader>()),
  );
  sl.registerLazySingleton<CustomsRequestsMockDataSource>(
    () => CustomsRequestsMockDataSource(sl<MockJsonLoader>()),
  );

  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(
      remote: sl<AuthRemoteDataSource>(),
      mock: sl<AuthMockDataSource>(),
    ),
  );
  sl.registerLazySingleton<CustomsRequestsRepository>(
    () => CustomsRequestsRepositoryImpl(
      remote: sl<CustomsRequestsRemoteDataSource>(),
      mock: sl<CustomsRequestsMockDataSource>(),
    ),
  );
  sl.registerLazySingleton<OrganizationsRepository>(
    () => OrganizationsRepositoryImpl(sl<OrganizationsRemoteDataSource>()),
  );
  sl.registerLazySingleton<AdminSettingsRepository>(
    () => AdminSettingsRepositoryImpl(sl<AdminSettingsRemoteDataSource>()),
  );

  sl.registerLazySingleton<AuthService>(
    () => AuthService(
      sl<AuthRepository>(),
      sl<SecureStorageService>(),
      sl<AuthSessionController>(),
      prefs,
    ),
  );

  if (session.isAuthenticated) {
    await sl<AuthService>().restoreProfileFromCache();
    try {
      await sl<AuthService>().refreshProfile();
    } catch (_) {}
  }

  sl<Dio>().interceptors.add(
    SessionExpiredInterceptor(
      onSessionExpired: () =>
          sl<AuthService>().logout(sessionExpired: true),
    ),
  );
}
