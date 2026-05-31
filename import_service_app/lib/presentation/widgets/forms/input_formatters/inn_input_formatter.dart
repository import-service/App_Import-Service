import 'package:flutter/services.dart';

/// Только цифры ИНН (10 или 12).
String innDigitsOnly(String? raw) => (raw ?? '').replaceAll(RegExp(r'\D'), '');

/// Форматирует ИНН для чтения: `1234 567 890` или `1234 567 890 12`.
class InnInputFormatter extends TextInputFormatter {
  static String formatDigits(String digits) {
    final trimmed = innDigitsOnly(digits);
    final limited = trimmed.length > 12 ? trimmed.substring(0, 12) : trimmed;
    return _formatDigits(limited);
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final formatted = formatDigits(newValue.text);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  static String _formatDigits(String digits) {
    if (digits.isEmpty) return '';
    final b = StringBuffer();
    final g1 = digits.length >= 4 ? 4 : digits.length;
    b.write(digits.substring(0, g1));
    if (digits.length <= 4) return b.toString();

    b.write(' ');
    final g2Len = (digits.length - 4) >= 3 ? 3 : (digits.length - 4);
    b.write(digits.substring(4, 4 + g2Len));
    if (digits.length <= 7) return b.toString();

    b.write(' ');
    final g3Len = (digits.length - 7) >= 3 ? 3 : (digits.length - 7);
    b.write(digits.substring(7, 7 + g3Len));
    if (digits.length <= 10) return b.toString();

    b.write(' ');
    b.write(digits.substring(10));
    return b.toString();
  }
}
