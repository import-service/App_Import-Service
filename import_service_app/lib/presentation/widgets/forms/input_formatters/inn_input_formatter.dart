import 'package:flutter/services.dart';

/// Форматирует ИНН для чтения: `1234 567 890` или `1234 567 890 12`.
class InnInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final trimmed = digits.length > 12 ? digits.substring(0, 12) : digits;
    final formatted = _format(trimmed);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  String _format(String digits) {
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
