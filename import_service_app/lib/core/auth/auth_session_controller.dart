import 'package:flutter/foundation.dart';

/// In-memory состояние авторизации для UI/роутера и интерсепторов.
class AuthSessionController extends ChangeNotifier {
  String? _accessToken;
  String? _userId;
  String? _external1cId;
  String? _login;
  String? _role;
  String? _companyName;
  String? _inn;
  String? _phone;
  String? _email;
  String? _managerName;
  String? _managerPhone;
  String? _managerEmail;
  String? _fullName;
  bool _isDemo = false;

  bool get isAuthenticated =>
      _accessToken != null && _accessToken!.trim().isNotEmpty;
  bool get isDemo => _isDemo;
  bool get hasActiveSession => isAuthenticated || _isDemo;
  String? get accessToken => _accessToken;
  String? get userId => _userId;
  String? get external1cId => _external1cId;
  String? get login => _login;
  String? get role => _role;
  String? get companyName => _companyName;
  String? get inn => _inn;
  String? get phone => _phone;
  String? get email => _email;
  String? get managerName => _managerName;
  String? get managerPhone => _managerPhone;
  String? get managerEmail => _managerEmail;
  String? get fullName => _fullName;

  void restore(String? token) {
    _accessToken = token;
    _isDemo = false;
    notifyListeners();
  }

  void setToken(String token) {
    _accessToken = token;
    _isDemo = false;
    notifyListeners();
  }

  void enableDemo() {
    _isDemo = true;
    _accessToken = null;
    _userId = null;
    _external1cId = null;
    _login = null;
    _role = null;
    _companyName = null;
    _inn = null;
    _phone = null;
    _email = null;
    _managerName = null;
    _managerPhone = null;
    _managerEmail = null;
    _fullName = null;
    notifyListeners();
  }

  void setProfile({
    String? userId,
    String? external1cId,
    required String login,
    required String role,
    String? companyName,
    String? inn,
    String? phone,
    String? email,
    String? managerName,
    String? managerPhone,
    String? managerEmail,
    String? fullName,
  }) {
    _userId = userId;
    _external1cId = external1cId;
    _login = login;
    _role = role;
    _companyName = companyName;
    _inn = inn;
    _phone = phone;
    _email = email;
    _managerName = managerName;
    _managerPhone = managerPhone;
    _managerEmail = managerEmail;
    _fullName = fullName;
    notifyListeners();
  }

  void clear() {
    _isDemo = false;
    _accessToken = null;
    _userId = null;
    _external1cId = null;
    _login = null;
    _role = null;
    _companyName = null;
    _inn = null;
    _phone = null;
    _email = null;
    _managerName = null;
    _managerPhone = null;
    _managerEmail = null;
    _fullName = null;
    notifyListeners();
  }
}
