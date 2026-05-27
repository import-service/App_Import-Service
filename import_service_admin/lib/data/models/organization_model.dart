import 'package:import_service_admin/domain/entities/organization.dart';

class OrganizationModel {
  OrganizationModel({
    required this.id,
    required this.id1c,
    required this.login,
    required this.role,
    required this.orgType,
    required this.companyName,
    required this.inn,
    required this.phone,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
  });

  final int id;
  final String id1c;
  final String login;
  final String role;
  final String orgType;
  final String companyName;
  final String inn;
  final String phone;
  final String? createdAt;
  final String? updatedAt;
  final String? deletedAt;

  factory OrganizationModel.fromJson(Map<String, dynamic> json) {
    return OrganizationModel(
      id: json['id'] is int ? json['id'] as int : int.tryParse('${json['id']}') ?? 0,
      id1c: (json['id_1c'] ?? json['id1c'] ?? '') as String? ?? '',
      login: json['login'] as String? ?? '',
      role: json['role'] as String? ?? '',
      orgType: (json['orgType'] ?? json['org_type'] ?? '') as String? ?? '',
      companyName: (json['companyName'] ?? json['company_name'] ?? '') as String? ?? '',
      inn: json['inn'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      createdAt: json['createdAt'] as String? ?? json['created_at'] as String?,
      updatedAt: json['updatedAt'] as String? ?? json['updated_at'] as String?,
      deletedAt: json['deletedAt'] as String? ?? json['deleted_at'] as String?,
    );
  }

  Organization toEntity() => Organization(
        id: id,
        id1c: id1c,
        login: login,
        role: role,
        orgType: orgType,
        companyName: companyName,
        inn: inn,
        phone: phone,
        createdAt: createdAt,
        updatedAt: updatedAt,
        deletedAt: deletedAt,
      );
}
