import 'package:flutter/services.dart';

String formatSvhLoginCredentials({
  required String login,
  required String password,
}) {
  return 'Логин: ${login.trim()}\nПароль: $password';
}

Future<void> copySvhLoginCredentials({
  required String login,
  required String password,
}) {
  return Clipboard.setData(
    ClipboardData(
      text: formatSvhLoginCredentials(login: login, password: password),
    ),
  );
}
