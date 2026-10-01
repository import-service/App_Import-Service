/// Сохранённый вход на устройстве (email + пароль + роль на момент входа).
class RecentAccount {
  const RecentAccount({
    required this.email,
    required this.password,
    required this.role,
    required this.lastLoginAt,
  });

  final String email;
  final String password;
  final String role;
  final DateTime lastLoginAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'email': email,
        'password': password,
        'role': role,
        'lastLoginAt': lastLoginAt.toUtc().toIso8601String(),
      };

  factory RecentAccount.fromJson(Map<String, dynamic> json) {
    final rawAt = json['lastLoginAt']?.toString() ?? '';
    return RecentAccount(
      email: (json['email']?.toString() ?? '').trim().toLowerCase(),
      password: json['password']?.toString() ?? '',
      role: (json['role']?.toString() ?? 'user').trim(),
      lastLoginAt: DateTime.tryParse(rawAt)?.toUtc() ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }
}
