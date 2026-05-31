import 'dart:convert';
import 'dart:async';

import 'package:dio/dio.dart';
import 'package:import_service_app/core/auth/auth_session_controller.dart';
import 'package:import_service_app/core/auth/auth_storage_keys.dart';
import 'package:import_service_app/core/auth/session_preferences_keys.dart';
import 'package:import_service_app/core/logging/app_log.dart';
import 'package:import_service_app/core/push/push_notifications_service.dart';
import 'package:import_service_app/core/storage/secure_storage_service.dart';
import 'package:import_service_app/data/datasources/remote/auth_remote_data_source.dart';
import 'package:import_service_app/data/models/auth_login_request_model.dart';
import 'package:import_service_app/data/models/auth_me_response_model.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  AuthService(
    this._remote,
    this._secureStorage,
    this._session,
    this._prefs,
    this._dio,
    this._pushNotifications,
  );

  final AuthRemoteDataSource _remote;
  final SecureStorageService _secureStorage;
  final AuthSessionController _session;
  final SharedPreferences _prefs;
  final Dio _dio;
  final PushNotificationsService _pushNotifications;
  StreamSubscription<String>? _tokenRefreshSubscription;

  bool get isAuthenticated => _session.isAuthenticated;

  Future<void> login({
    required String login,
    required String password,
  }) async {
    final response = await _remote.login(
      AuthLoginRequestModel(
        login: login,
        password: password,
      ),
    );
    final token = response.accessToken;
    // Сначала память: интерсептор Dio берёт токен из сессии.
    // Первый write в Secure Storage на Android может занять секунды (Keystore);
    // если ждать его до setToken и /auth/me, цепочка входа искусственно растягивается и чаще упирается в таймаут.
    _session.setToken(token);
    await _prefs.setBool(SessionPreferencesKeys.demoUserActive, false);
    await Future.wait<void>([
      _secureStorage.write(AuthStorageKeys.accessToken, token),
      refreshProfile(),
    ]);
    _bindPushTokenRefresh();
    await registerPushTokenIfNeeded();
  }

  /// После входа или восстановления сессии — получить FCM-токен и отправить на сервер.
  Future<void> registerPushTokenIfNeeded() async {
    if (!_session.isAuthenticated) return;
    _bindPushTokenRefresh();
    await _registerPushToken();
  }

  Future<void> logout() async {
    await _unregisterPushToken();
    try {
      await _remote.logout();
    } catch (_) {
      // Токен всё равно очищаем локально даже при ошибке backend logout.
    }
    await _secureStorage.delete(AuthStorageKeys.accessToken);
    await _prefs.remove(SessionPreferencesKeys.authProfileCache);
    _session.clear();
  }

  Future<bool> restoreProfileFromCache() async {
    final raw = _prefs.getString(SessionPreferencesKeys.authProfileCache);
    if (raw == null || raw.trim().isEmpty) return false;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return false;
      final profile = AuthMeResponseModel.fromJson(decoded);
      _applyProfile(profile);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> refreshProfile({bool allowCacheFallback = true}) async {
    if (!_session.isAuthenticated) return;
    try {
      final profile = await _remote.me();
      _applyProfile(profile);
      await _prefs.setString(
        SessionPreferencesKeys.authProfileCache,
        jsonEncode(profile.toJson()),
      );
    } catch (_) {
      if (allowCacheFallback && await restoreProfileFromCache()) {
        return;
      }
      rethrow;
    }
  }

  void _applyProfile(AuthMeResponseModel profile) {
    _session.setProfile(
      userId: profile.id,
      external1cId: profile.external1cId,
      login: profile.login,
      role: profile.role,
      companyName: profile.companyName,
      inn: profile.inn,
      phone: profile.phone,
      email: profile.email,
      managerName: profile.managerName,
      managerPhone: profile.managerPhone,
      managerEmail: profile.managerEmail,
      fullName: profile.fullName,
    );
  }

  void _bindPushTokenRefresh() {
    _tokenRefreshSubscription ??= _pushNotifications.tokenRefreshStream.listen(
      (token) {
        if (!_session.isAuthenticated) return;
        unawaited(_registerPushToken(tokenOverride: token));
      },
    );
  }

  Future<void> _registerPushToken({String? tokenOverride}) async {
    if (!_session.isAuthenticated) return;
    final token = (tokenOverride ??
            await _pushNotifications.ensureFcmToken() ??
            _pushNotifications.currentToken ??
            '')
        .trim();
    if (token.isEmpty) {
      AppLog.error(
        'push register skipped: FCM token empty after ensureFcmToken',
        tag: 'PushToken',
      );
      return;
    }
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      await _dio.post<dynamic>(
        'push/tokens',
        data: <String, dynamic>{
          'token': token,
          'platform': _pushNotifications.platformName,
          'appVersion': packageInfo.version,
        },
      );
      AppLog.trace('push token registered', tag: 'PushToken');
    } on DioException catch (e, st) {
      final statusCode = e.response?.statusCode;
      final message = _responseMessage(e.response?.data);
      final errorCode = _responseErrorCode(e.response?.data);
      if (statusCode == 503 && errorCode == 'PUSH_STORAGE_NOT_READY') {
        AppLog.trace('push register warn: PUSH_STORAGE_NOT_READY', tag: 'PushToken');
        return;
      }
      AppLog.error(
        'push register failed: code=$statusCode message=$message',
        tag: 'PushToken',
        error: e,
        stackTrace: st,
      );
    } catch (e, st) {
      AppLog.error(
        'push register failed',
        tag: 'PushToken',
        error: e,
        stackTrace: st,
      );
    }
  }

  Future<void> _unregisterPushToken() async {
    if (!_session.isAuthenticated) return;
    final token = (_pushNotifications.currentToken ?? '').trim();
    if (token.isEmpty) return;
    try {
      await _dio.delete<dynamic>(
        'push/tokens',
        data: <String, dynamic>{
          'token': token,
        },
      );
      AppLog.trace('push token unregistered', tag: 'PushToken');
    } on DioException catch (e, st) {
      final statusCode = e.response?.statusCode;
      final message = _responseMessage(e.response?.data);
      final errorCode = _responseErrorCode(e.response?.data);
      if (statusCode == 503 && errorCode == 'PUSH_STORAGE_NOT_READY') {
        AppLog.trace('push unregister warn: PUSH_STORAGE_NOT_READY', tag: 'PushToken');
        return;
      }
      AppLog.error(
        'push unregister failed: code=$statusCode message=$message',
        tag: 'PushToken',
        error: e,
        stackTrace: st,
      );
    } catch (e, st) {
      AppLog.error(
        'push unregister failed',
        tag: 'PushToken',
        error: e,
        stackTrace: st,
      );
    }
  }

  static String _responseErrorCode(dynamic data) {
    if (data is Map<String, dynamic>) {
      return (data['errorCode']?.toString() ?? '').trim();
    }
    return '';
  }

  static String _responseMessage(dynamic data) {
    if (data is Map<String, dynamic>) {
      final message = data['message']?.toString() ?? '';
      if (message.trim().isNotEmpty) return message;
      final error = data['error']?.toString() ?? '';
      if (error.trim().isNotEmpty) return error;
    }
    return 'unknown';
  }
}
