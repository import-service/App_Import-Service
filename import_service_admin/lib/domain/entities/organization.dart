import 'package:equatable/equatable.dart';

class Organization extends Equatable {
  const Organization({
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

  bool get isDeleted => deletedAt != null && deletedAt!.isNotEmpty;

  @override
  List<Object?> get props => [id];
}
