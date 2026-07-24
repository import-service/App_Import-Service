import 'package:flutter/services.dart';

import 'package:import_service_app/presentation/helpers/vin_validation.dart';

/// VIN: A–Z и 0–9 без I/O/Q, верхний регистр, максимум 17 символов.
class VinInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final upper = newValue.text.toUpperCase();
    final buffer = StringBuffer();
    for (final rune in upper.runes) {
      final char = String.fromCharCode(rune);
      if (vinAllowedChar.hasMatch(char)) {
        buffer.write(char);
      }
      if (buffer.length >= 17) break;
    }
    final result = buffer.toString();
    return TextEditingValue(
      text: result,
      selection: TextSelection.collapsed(offset: result.length),
    );
  }
}
