import 'package:import_service_admin/domain/entities/svh_manager.dart';

class SvhManagerModel {
  const SvhManagerModel({
    required this.id,
    required this.login,
    required this.fullName,
    required this.phone,
    required this.active,
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final String login;
  final String fullName;
  final String phone;
  final bool active;
  final String? createdAt;
  final String? updatedAt;

  factory SvhManagerModel.fromJson(Map<String, dynamic> json) {
    return SvhManagerModel(
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse('${json['id']}') ?? 0,
      login: json['login'] as String? ?? '',
      fullName: json['fullName'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      active: json['active'] == true,
      createdAt: json['createdAt'] as String?,
      updatedAt: json['updatedAt'] as String?,
    );
  }

  SvhManager toEntity() => SvhManager(
        id: id,
        login: login,
        fullName: fullName,
        phone: phone,
        active: active,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}
