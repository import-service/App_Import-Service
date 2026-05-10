enum OrganizationType { ooo, ip }

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
      'orgType': organizationType == OrganizationType.ooo ? 'OOO' : 'IP',
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
