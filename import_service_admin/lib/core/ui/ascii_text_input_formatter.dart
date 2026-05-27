import 'package:flutter/services.dart';

/// Только ASCII (латиница, цифры, знаки) — для Bearer-токенов и HTTP-заголовков.
class AsciiTextInputFormatter extends TextInputFormatter {
  const AsciiTextInputFormatter();

  static final RegExp _nonAscii = RegExp(r'[^\x00-\x7F]');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (!_nonAscii.hasMatch(newValue.text)) return newValue;
    final filtered = newValue.text.replaceAll(_nonAscii, '');
    return TextEditingValue(
      text: filtered,
      selection: TextSelection.collapsed(
        offset: filtered.length.clamp(0, filtered.length),
      ),
    );
  }

  static bool isValidAscii(String value) => !_nonAscii.hasMatch(value);
}
