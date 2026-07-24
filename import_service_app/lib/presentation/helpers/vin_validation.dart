import 'package:import_service_app/core/i18n/json_strings_service.dart';

/// ISO VIN: 17 символов, без I/O/Q (путаются с 1/0).
final RegExp vinAllowedChar = RegExp(r'[A-HJ-NPR-Z0-9]');
final RegExp vinFullPattern = RegExp(r'^[A-HJ-NPR-Z0-9]{17}$');
final RegExp vinForbiddenLetter = RegExp(r'[IOQ]');

bool isValidVin(String vin) => vinFullPattern.hasMatch(vin.trim().toUpperCase());

/// Текст ошибки VIN или `null`, если номер корректен / пуст.
String? vinValidationMessage(String vin, JsonStringsService strings) {
  final v = vin.trim().toUpperCase();
  if (v.isEmpty) return null;
  if (v.length != 17) {
    return strings.text('vinLengthError');
  }
  if (vinForbiddenLetter.hasMatch(v) || !vinFullPattern.hasMatch(v)) {
    return strings.text('vinCharsError');
  }
  return null;
}
