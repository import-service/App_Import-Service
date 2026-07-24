enum OrganizationType { ooo, ip, person }

extension OrganizationTypeInn on OrganizationType {
  /// ООО — 10 цифр; ИП и физлицо — 12 цифр.
  int get innMaxDigits => this == OrganizationType.ooo ? 10 : 12;

  bool get isPersonLike => this == OrganizationType.ip || this == OrganizationType.person;

  /// Код регистрации МП → сервер.
  String get registrationApiCode {
    switch (this) {
      case OrganizationType.ooo:
        return 'OOO';
      case OrganizationType.ip:
        return 'IP';
      case OrganizationType.person:
        return 'FL';
    }
  }

  /// Значение orgType из /auth/me и 1С.
  String get profileApiLabel {
    switch (this) {
      case OrganizationType.ooo:
        return 'ООО';
      case OrganizationType.ip:
        return 'ИП';
      case OrganizationType.person:
        return 'Физическое лицо';
    }
  }

  static OrganizationType? tryParse(String? raw) {
    final s = (raw ?? '').trim();
    if (s.isEmpty) return null;
    final lower = s.toLowerCase();
    if (s == 'ООО' || lower == 'ooo') return OrganizationType.ooo;
    if (s == 'ИП' || lower == 'ip') return OrganizationType.ip;
    if (s == 'Физическое лицо' ||
        lower == 'fl' ||
        lower == 'person' ||
        lower == 'physical') {
      return OrganizationType.person;
    }
    return null;
  }
}

class RegistrationRequestModel {
  RegistrationRequestModel({
    required this.organizationType,
    required this.companyOrFullName,
    required this.inn,
    required this.phone,
    required this.email,
  });

  final OrganizationType organizationType;
  final String companyOrFullName;
  final String inn;
  final String phone;
  final String email;

  Map<String, dynamic> toJson() {
    final payload = <String, dynamic>{
      'orgType': organizationType.registrationApiCode,
      'inn': inn,
      'phone': phone,
      'email': email,
    };
    if (organizationType == OrganizationType.ooo) {
      payload['companyName'] = companyOrFullName;
    } else {
      payload['fullName'] = companyOrFullName;
    }
    return payload;
  }
}
