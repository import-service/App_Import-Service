class AuthLoginResponseModel {
  AuthLoginResponseModel({required this.accessToken, required this.role});

  final String accessToken;
  final String role;

  factory AuthLoginResponseModel.fromJson(Map<String, dynamic> json) {
    final token = json['accessToken'];
    if (token is! String || token.trim().isEmpty) {
      throw const FormatException('Missing accessToken');
    }
    return AuthLoginResponseModel(
      accessToken: token,
      role: json['role'] as String? ?? 'admin',
    );
  }
}
