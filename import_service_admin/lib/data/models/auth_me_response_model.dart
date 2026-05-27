class AuthMeResponseModel {
  AuthMeResponseModel({
    required this.id,
    required this.login,
    this.createdAt,
  });

  final String id;
  final String login;
  final String? createdAt;

  factory AuthMeResponseModel.fromJson(Map<String, dynamic> json) {
    final idRaw = json['id'];
    return AuthMeResponseModel(
      id: idRaw?.toString() ?? '',
      login: (json['login'] as String?)?.trim() ?? '',
      createdAt: json['createdAt'] as String? ?? json['created_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'login': login,
        if (createdAt != null) 'createdAt': createdAt,
      };
}
