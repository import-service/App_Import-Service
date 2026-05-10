class AuthLoginResponseModel {
  AuthLoginResponseModel({
    required this.accessToken,
  });

  final String accessToken;

  factory AuthLoginResponseModel.fromJson(Map<String, dynamic> json) {
    final token = json['accessToken'];
    if (token is! String || token.trim().isEmpty) {
      throw const FormatException('Missing accessToken in login response');
    }
    return AuthLoginResponseModel(accessToken: token);
  }
}
