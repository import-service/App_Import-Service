import 'package:flutter/services.dart';

String formatAdminLoginCredentials({
  required String login,
  required String password,
}) {
  return 'Логин: ${login.trim()}\nПароль: $password';
}

Future<void> copyAdminLoginCredentials({
  required String login,
  required String password,
}) {
  return Clipboard.setData(
    ClipboardData(
      text: formatAdminLoginCredentials(login: login, password: password),
    ),
  );
}
