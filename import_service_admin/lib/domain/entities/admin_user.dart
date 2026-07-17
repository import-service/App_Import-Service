import 'package:equatable/equatable.dart';

class AdminUser extends Equatable {
  const AdminUser({
    required this.id,
    required this.login,
    this.createdAt,
  });

  final int id;
  final String login;
  final String? createdAt;

  @override
  List<Object?> get props => [id, login, createdAt];
}
