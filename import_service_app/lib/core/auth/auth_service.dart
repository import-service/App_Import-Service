import 'dart:convert';

import 'package:import_service_app/core/auth/auth_session_controller.dart';
import 'package:import_service_app/core/auth/auth_storage_keys.dart';
import 'package:import_service_app/core/auth/session_preferences_keys.dart';
import 'package:import_service_app/core/storage/secure_storage_service.dart';
import 'package:import_service_app/data/datasources/remote/auth_remote_data_source.dart';
import 'package:import_service_app/data/models/auth_login_request_model.dart';
import 'package:import_service_app/data/models/auth_me_response_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  AuthService(
    this._remote,
    this._secureStorage,
    this._session,
    this._prefs,
  );

  final AuthRemoteDataSource _remote;
  final SecureStorageService _secureStorage;
  final AuthSessionController _session;
  final SharedPreferences _prefs;

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
  }

  Future<void> logout() async {
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
}
