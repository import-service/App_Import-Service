class AuthMeResponseModel {
  AuthMeResponseModel({
    required this.id,
    required this.external1cId,
    required this.login,
    required this.role,
    required this.companyName,
    required this.orgType,
    required this.inn,
    required this.phone,
    required this.email,
    required this.managerName,
    required this.managerPhone,
    required this.managerEmail,
    required this.fullName,
  });

  final String id;
  final String external1cId;
  final String login;
  final String role;
  final String companyName;
  final String orgType;
  final String inn;
  final String phone;
  final String email;
  final String managerName;
  final String managerPhone;
  final String managerEmail;
  final String fullName;

  factory AuthMeResponseModel.fromJson(Map<String, dynamic> json) {
    return AuthMeResponseModel(
      id: _firstString(
        json,
        const ['id', 'userId', 'user_id'],
      ),
      external1cId: _firstString(
        json,
        const ['external1cId', 'external_1c_id', 'externalId1c'],
      ),
      login: _firstString(
        json,
        const ['login', 'userName', 'username', 'userLogin', 'email', 'legalEmail'],
      ),
      role: _firstString(
        json,
        const ['role', 'userRole'],
      ),
      companyName: _firstString(
        json,
        const ['legalEntityName', 'companyName', 'organizationName', 'orgName'],
      ),
      orgType: _firstString(
        json,
        const ['orgType', 'org_type', 'organizationType'],
      ),
      inn: _firstString(
        json,
        const ['inn', 'legalInn', 'companyInn'],
      ),
      phone: _firstString(
        json,
        const ['legalPhone', 'phone', 'companyPhone', 'individualPhone'],
      ),
      email: _firstString(
        json,
        const ['legalEmail', 'email', 'companyEmail', 'login'],
      ),
      managerName: _firstString(
        json,
        const ['managerName', 'managerFullName', 'assignedManagerName'],
      ),
      managerPhone: _firstString(
        json,
        const ['managerPhone', 'assignedManagerPhone'],
      ),
      managerEmail: _firstString(
        json,
        const ['managerEmail', 'assignedManagerEmail'],
      ),
      fullName: _firstString(
        json,
        const ['individualFullName', 'fullName', 'fio', 'name'],
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'external1cId': external1cId,
      'login': login,
      'role': role,
      'companyName': companyName,
      'orgType': orgType,
      'inn': inn,
      'phone': phone,
      'email': email,
      'managerName': managerName,
      'managerPhone': managerPhone,
      'managerEmail': managerEmail,
      'fullName': fullName,
    };
  }

  /// Берёт первое непустое строковое значение по списку ключей (API может
  /// отдавать логин под разными именами).
  static String _firstString(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final raw = json[key];
      if (raw is String) {
        final s = raw.trim();
        if (s.isNotEmpty) return s;
      } else if (raw is num) {
        return raw.toString();
      }
    }
    return '';
  }
}
