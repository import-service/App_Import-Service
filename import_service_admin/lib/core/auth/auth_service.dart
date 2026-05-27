import 'dart:convert';

import 'package:import_service_admin/core/auth/auth_session_controller.dart';
import 'package:import_service_admin/core/auth/auth_storage_keys.dart';
import 'package:import_service_admin/core/auth/session_preferences_keys.dart';
import 'package:import_service_admin/core/storage/secure_storage_service.dart';
import 'package:import_service_admin/core/ui/app_snackbars.dart';
import 'package:import_service_admin/data/models/auth_login_request_model.dart';
import 'package:import_service_admin/data/models/auth_me_response_model.dart';
import 'package:import_service_admin/domain/repositories/auth_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  AuthService(
    this._repository,
    this._secureStorage,
    this._session,
    this._prefs,
  );

  final AuthRepository _repository;
  final SecureStorageService _secureStorage;
  final AuthSessionController _session;
  final SharedPreferences _prefs;

  bool get isAuthenticated => _session.isAuthenticated;

  Future<void> login({
    required String login,
    required String password,
  }) async {
    final token = await _repository.login(
      AuthLoginRequestModel(login: login, password: password),
    );
    _session.setToken(token);
    await Future.wait<void>([
      _secureStorage.write(AuthStorageKeys.accessToken, token),
      refreshProfile(),
    ]);
  }

  Future<void> logout({bool sessionExpired = false}) async {
    if (!_session.isAuthenticated) return;
    try {
      await _repository.logout();
    } catch (_) {}
    await _secureStorage.delete(AuthStorageKeys.accessToken);
    await _prefs.remove(SessionPreferencesKeys.authProfileCache);
    _session.clear();
    if (sessionExpired) {
      AppSnackBars.showError('Сессия истекла. Войдите снова.');
    }
  }

  Future<bool> restoreProfileFromCache() async {
    final raw = _prefs.getString(SessionPreferencesKeys.authProfileCache);
    if (raw == null || raw.trim().isEmpty) return false;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return false;
      _applyProfile(AuthMeResponseModel.fromJson(decoded));
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> refreshProfile() async {
    if (!_session.isAuthenticated) return;
    final profile = await _repository.me();
    _applyProfile(profile);
    await _prefs.setString(
      SessionPreferencesKeys.authProfileCache,
      jsonEncode(profile.toJson()),
    );
  }

  void _applyProfile(AuthMeResponseModel profile) {
    _session.setProfile(
      userId: profile.id,
      login: profile.login,
      role: 'admin',
      companyName: profile.login,
    );
  }
}
