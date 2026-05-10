import 'package:flutter/widgets.dart';

/// Единое поведение форм в приложении.
///
/// **Кнопка отправки**: активна только если нет ошибок валидации и все
/// обязательные поля заполнены (см. геттер `canSubmit` / аналог в каждой форме).
///
/// **Ошибки под полями**: не показываем на пустой только что открытой форме
/// (иначе сразу сплошные «обязательно»). После того как пользователь начал ввод
/// (`userHasStartedInput`), включается [AutovalidateMode.always] — проверка и
/// текст ошибок обновляются после **каждого** изменения полей.
abstract final class AppFormBehavior {
  AppFormBehavior._();

  static AutovalidateMode autovalidateMode(bool userHasStartedInput) {
    return userHasStartedInput
        ? AutovalidateMode.always
        : AutovalidateMode.disabled;
  }
}
