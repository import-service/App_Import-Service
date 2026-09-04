import 'package:equatable/equatable.dart';

class SvhManager extends Equatable {
  const SvhManager({
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

  @override
  List<Object?> get props =>
      [id, login, fullName, phone, active, createdAt, updatedAt];
}
