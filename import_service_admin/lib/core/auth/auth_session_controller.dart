import 'package:flutter/foundation.dart';

class AuthSessionController extends ChangeNotifier {
  String? _accessToken;
  String? _userId;
  String? _login;
  String? _role;
  String? _companyName;

  bool get isAuthenticated =>
      _accessToken != null && _accessToken!.trim().isNotEmpty;

  String? get accessToken => _accessToken;
  String? get userId => _userId;
  String? get login => _login;
  String? get role => _role;
  String? get companyName => _companyName;

  void restore(String? token) {
    _accessToken = token;
    notifyListeners();
  }

  void setToken(String token) {
    _accessToken = token;
    notifyListeners();
  }

  void setProfile({
    String? userId,
    required String login,
    required String role,
    String? companyName,
  }) {
    _userId = userId;
    _login = login;
    _role = role;
    _companyName = companyName;
    notifyListeners();
  }

  void clear() {
    _accessToken = null;
    _userId = null;
    _login = null;
    _role = null;
    _companyName = null;
    notifyListeners();
  }
}
