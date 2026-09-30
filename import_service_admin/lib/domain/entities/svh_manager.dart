import 'package:equatable/equatable.dart';

class SvhManager extends Equatable {
  const SvhManager({
    required this.id,
    required this.login,
    required this.fullName,
    required this.phone,
    required this.role,
    required this.active,
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final String login;
  final String fullName;
  final String phone;

  /// `svh_manager` | `declarant_manager`
  final String role;
  final bool active;
  final String? createdAt;
  final String? updatedAt;

  bool get isDeclarant => role == 'declarant_manager';

  String get roleLabel =>
      isDeclarant ? 'Менеджер-декларант' : 'Менеджер СВХ';

  @override
  List<Object?> get props =>
      [id, login, fullName, phone, role, active, createdAt, updatedAt];
}
