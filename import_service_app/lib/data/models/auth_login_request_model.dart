class AuthLoginRequestModel {
  AuthLoginRequestModel({
    required this.login,
    required this.password,
  });

  final String login;
  final String password;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'login': login,
        'password': password,
      };
}
