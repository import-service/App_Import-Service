import 'package:flutter/services.dart';

/// VIN: только A-Z и 0-9, верхний регистр, максимум 17 символов.
class VinInputFormatter extends TextInputFormatter {
  static final RegExp _allowed = RegExp(r'[A-Z0-9]');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final upper = newValue.text.toUpperCase();
    final buffer = StringBuffer();
    for (final rune in upper.runes) {
      final char = String.fromCharCode(rune);
      if (_allowed.hasMatch(char)) {
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
