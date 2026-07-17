import 'package:import_service_admin/domain/entities/admin_user.dart';

class AdminUserModel {
  const AdminUserModel({
    required this.id,
    required this.login,
    this.createdAt,
  });

  final int id;
  final String login;
  final String? createdAt;

  factory AdminUserModel.fromJson(Map<String, dynamic> json) {
    return AdminUserModel(
      id: json['id'] is int ? json['id'] as int : int.tryParse('${json['id']}') ?? 0,
      login: json['login'] as String? ?? '',
      createdAt: json['createdAt'] as String?,
    );
  }

  AdminUser toEntity() => AdminUser(id: id, login: login, createdAt: createdAt);
}
