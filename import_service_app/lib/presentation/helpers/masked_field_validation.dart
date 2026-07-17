import 'package:flutter/material.dart';
import 'package:import_service_app/core/i18n/json_strings_service.dart';
import 'package:import_service_app/data/models/registration_request_model.dart';
import 'package:import_service_app/presentation/widgets/forms/input_formatters/inn_input_formatter.dart';
import 'package:import_service_app/presentation/widgets/forms/input_formatters/snils_input_formatter.dart';

/// Цифры российского телефона (11, с ведущей 7).
String ruPhoneDigitsOnly(String value) {
  var digits = value.replaceAll(RegExp(r'\D'), '');
  if (digits.startsWith('8')) {
    digits = '7${digits.substring(1)}';
  } else if (digits.length == 10) {
    digits = '7$digits';
  }
  if (digits.length > 11) {
    digits = digits.substring(0, 11);
  }
  return digits;
}

/// Нормализация для API: `+79990000000`.
String normalizeRuPhoneForApi(String value) {
  final digits = ruPhoneDigitsOnly(value);
  if (isValidRuPhoneDigits(digits)) {
    return '+$digits';
  }
  return value.trim();
}

bool isValidRuPhoneDigits(String digits) =>
    digits.length == 11 && digits.startsWith('7');

bool isValidRuPhoneApi(String normalized) =>
    RegExp(r'^\+7\d{10}$').hasMatch(normalized);

bool isValidInnDigits(String digits, OrganizationType orgType) =>
    digits.length == orgType.innMaxDigits;

bool isValidSnilsDigits(String digits) {
  if (digits.length != snilsDigitCount) {
    return false;
  }
  if (RegExp(r'^(\d)\1{10}$').hasMatch(digits)) {
    return false;
  }
  final body = digits.substring(0, 9);
  final control = int.tryParse(digits.substring(9));
  if (control == null) {
    return false;
  }
  final bodyInt = int.tryParse(body);
  if (bodyInt == null) {
    return false;
  }
  if (bodyInt <= 1001998) {
    return control == 0;
  }
  var sum = 0;
  for (var i = 0; i < 9; i++) {
    sum += int.parse(body[i]) * (9 - i);
  }
  var expected = 0;
  if (sum < 100) {
    expected = sum;
  } else if (sum == 100 || sum == 101) {
    expected = 0;
  } else {
    expected = sum % 101;
    if (expected == 100) {
      expected = 0;
    }
  }
  return expected == control;
}

void clampInnController(TextEditingController controller, OrganizationType orgType) {
  final maxDigits = orgType.innMaxDigits;
  final digits = innDigitsOnly(controller.text);
  final trimmed =
      digits.length > maxDigits ? digits.substring(0, maxDigits) : digits;
  controller.text =
      InnInputFormatter.formatDigits(trimmed, maxDigits: maxDigits);
}

String? validateInnValue(
  String? value,
  OrganizationType orgType,
  JsonStringsService strings, {
  bool required = true,
}) {
  final inn = innDigitsOnly(value);
  if (inn.isEmpty) {
    return required ? strings.fieldRequiredError : null;
  }
  if (!isValidInnDigits(inn, orgType)) {
    return strings.innFormatErrorFor(orgType);
  }
  return null;
}

String? validateRuPhoneValue(
  String? value,
  JsonStringsService strings, {
  bool required = true,
}) {
  final phone = value?.trim() ?? '';
  if (phone.isEmpty) {
    return required ? strings.fieldRequiredError : null;
  }
  final normalized = normalizeRuPhoneForApi(phone);
  if (!isValidRuPhoneApi(normalized)) {
    return strings.phoneFormatError;
  }
  return null;
}

String? validateSnilsValue(
  String? value,
  JsonStringsService strings, {
  bool required = true,
}) {
  final digits = snilsDigitsOnly(value);
  if (digits.isEmpty) {
    return required ? strings.fieldRequiredError : null;
  }
  if (digits.length != snilsDigitCount) {
    return strings.text('snilsLengthError');
  }
  if (!isValidSnilsDigits(digits)) {
    return strings.text('snilsChecksumError');
  }
  return null;
}
