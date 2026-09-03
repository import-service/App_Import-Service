import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:import_service_app/core/auth/auth_service.dart';
import 'package:import_service_app/core/auth/auth_session_controller.dart';
import 'package:import_service_app/core/auth/auth_storage_keys.dart';
import 'package:import_service_app/core/auth/session_lost_handler.dart';
import 'package:import_service_app/core/error/exceptions.dart';
import 'package:import_service_app/core/i18n/app_locale.dart';
import 'package:import_service_app/core/i18n/json_strings_service.dart';
import 'package:import_service_app/core/themes/app_theme_mode.dart';
import 'package:import_service_app/core/network/dio_client.dart';
import 'package:import_service_app/core/navigation/home_cars_navigation_controller.dart';
import 'package:import_service_app/core/app_update/app_update_service.dart';
import 'package:import_service_app/core/push/push_notifications_service.dart';
import 'package:import_service_app/core/push/chat_screen_presence.dart';
import 'package:import_service_app/core/ui/app_feedback_service.dart';
import 'package:import_service_app/core/storage/secure_storage_service.dart';
import 'package:import_service_app/data/datasources/remote/auth_remote_data_source.dart';
import 'package:import_service_app/data/datasources/remote/customs_requests_remote_data_source.dart';
import 'package:import_service_app/data/datasources/remote/feedback_remote_data_source.dart';
import 'package:import_service_app/data/datasources/remote/request_chat_remote_data_source.dart';
import 'package:import_service_app/data/repositories/request_chat_repository_impl.dart';
import 'package:import_service_app/domain/repositories/request_chat_repository.dart';
import 'package:import_service_app/presentation/bloc/chat_list/chat_list_cubit.dart';
import 'package:import_service_app/data/datasources/remote/registration_request_remote_data_source.dart';
import 'package:import_service_app/data/local/car_inventory_state_holder.dart';
import 'package:import_service_app/data/local/request_detail_section_prefs.dart';
import 'package:import_service_app/data/repositories/cars_repository_impl.dart';
import 'package:import_service_app/domain/repositories/cars_repository.dart';
import 'package:import_service_app/presentation/bloc/car_inventory/car_inventory_cubit.dart';
import 'package:import_service_app/presentation/bloc/request_attention/request_attention_cubit.dart';
import 'package:import_service_app/presentation/bloc/request_draft/request_draft_cubit.dart';
import 'package:import_service_app/presentation/bloc/request_chat_unread/request_chat_unread_cubit.dart';
import 'package:import_service_app/presentation/helpers/session_auth_error.dart';

/// Глобальный контейнер зависимостей. Регистрации добавляй в [initDependencies].
final sl = GetIt.instance;

/// Вызывать из [main] после [WidgetsFlutterBinding.ensureInitialized].
Future<void> initDependencies() async {
  final prefs = await SharedPreferences.getInstance();
  sl.registerSingleton<SharedPreferences>(prefs);
  sl.registerLazySingleton<RequestDetailSectionPrefs>(
    () => RequestDetailSectionPrefs(sl()),
  );

  final requestDraftCubit = RequestDraftCubit(prefs);
  sl.registerSingleton<RequestDraftCubit>(requestDraftCubit);
  requestDraftCubit.reloadFromDisk();
  sl.registerSingleton<RequestAttentionCubit>(RequestAttentionCubit());
  sl.registerSingleton<RequestChatUnreadCubit>(RequestChatUnreadCubit());
  sl.registerSingleton<HomeCarsNavigationController>(
    HomeCarsNavigationController(),
  );
  sl.registerSingleton<ChatScreenPresence>(ChatScreenPresence());

  final carInventoryCubit = CarInventoryCubit(prefs);
  sl.registerSingleton<CarInventoryCubit>(carInventoryCubit);
  sl.registerSingleton<CarInventoryStateHolder>(carInventoryCubit);
  await carInventoryCubit.reloadFromDisk();

  sl.registerLazySingleton<AppFeedbackService>(AppFeedbackService.new);
  sl.registerLazySingleton<PushNotificationsService>(
    PushNotificationsService.new,
  );
  sl.registerLazySingleton<AppUpdateService>(
    () => AppUpdateService(sl<Dio>()),
  );

  sl.registerLazySingleton<SecureStorageService>(SecureStorageService.new);
  sl.registerLazySingleton<AuthSessionController>(AuthSessionController.new);

  final session = sl<AuthSessionController>();
  final restoredToken = await sl<SecureStorageService>().read(
    AuthStorageKeys.accessToken,
  );

  if (restoredToken != null && restoredToken.trim().isNotEmpty) {
    session.restore(restoredToken);
  } else {
    session.restore(null);
  }

  sl.registerLazySingleton<JsonStringsService>(JsonStringsService.new);
  final savedLanguage = prefs.getString('app_language');
  if (savedLanguage == 'zh') {
    appLocale.value = const Locale('zh');
  } else if (savedLanguage == 'ru') {
    appLocale.value = const Locale('ru');
  } else {
    final platform = WidgetsBinding.instance.platformDispatcher.locale;
    appLocale.value = Locale(platform.languageCode);
  }
  await sl<JsonStringsService>().load(appLocale.value);
  await loadAppThemeMode(prefs);

  // Callback ленивый: SessionLostHandler регистрируется ниже, до первых API.
  sl.registerLazySingleton<DioClient>(
    () => DioClient(
      tokenProvider: () => sl<AuthSessionController>().accessToken,
      onSessionAuthError: (raw) {
        if (!sl.isRegistered<SessionLostHandler>()) return;
        sl<SessionLostHandler>().handleIfSessionAuthError(raw);
      },
    ),
  );
  sl.registerLazySingleton<Dio>(() => sl<DioClient>().dio);

  sl.registerLazySingleton<AuthRemoteDataSource>(
    () => AuthRemoteDataSource(sl<Dio>()),
  );
  sl.registerLazySingleton<RegistrationRequestRemoteDataSource>(
    () => RegistrationRequestRemoteDataSource(sl<Dio>()),
  );
  sl.registerLazySingleton<CustomsRequestsRemoteDataSource>(
    () => CustomsRequestsRemoteDataSource(sl<Dio>()),
  );
  sl.registerLazySingleton<FeedbackRemoteDataSource>(
    () => FeedbackRemoteDataSource(sl<Dio>()),
  );
  sl.registerLazySingleton<RequestChatRemoteDataSource>(
    () => RequestChatRemoteDataSource(sl<Dio>()),
  );
  sl.registerLazySingleton<RequestChatRepository>(
    () => RequestChatRepositoryImpl(
      remote: sl<RequestChatRemoteDataSource>(),
      session: sl<AuthSessionController>(),
    ),
  );
  sl.registerLazySingleton<ChatListCubit>(
    () => ChatListCubit(
      repository: sl<RequestChatRepository>(),
      session: sl<AuthSessionController>(),
      inventory: sl<CarInventoryCubit>(),
      unread: sl<RequestChatUnreadCubit>(),
    ),
  );

  sl.registerLazySingleton<CarsRepository>(
    () => CarsRepositoryImpl(
      carInventory: sl<CarInventoryStateHolder>(),
      remoteDataSource: sl<CustomsRequestsRemoteDataSource>(),
      session: sl<AuthSessionController>(),
      sharedPreferences: prefs,
    ),
  );

  sl.registerLazySingleton<AuthService>(
    () => AuthService(
      sl<AuthRemoteDataSource>(),
      sl<SecureStorageService>(),
      sl<AuthSessionController>(),
      sl<SharedPreferences>(),
      sl<Dio>(),
      sl<PushNotificationsService>(),
    ),
  );

  sl.registerLazySingleton<SessionLostHandler>(
    () => SessionLostHandler(
      authService: sl<AuthService>(),
      session: sl<AuthSessionController>(),
      feedback: sl<AppFeedbackService>(),
      strings: sl<JsonStringsService>(),
    ),
  );

  await sl<AuthService>().restoreProfileFromCache();
  try {
    await sl<AuthService>().refreshProfile();
  } catch (e) {
    final msg = e is ServerException ? e.message : e.toString();
    if (isSessionAuthErrorMessage(msg)) {
      await sl<AuthService>().clearLocalSession();
    }
  }

  // BLoC/Cubit в GetIt: см. [CarInventoryCubit], [RequestDraftCubit].
}
