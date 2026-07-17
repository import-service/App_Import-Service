import 'package:flutter/services.dart';

/// Только цифры ИНН (10 или 12).
String innDigitsOnly(String? raw) => (raw ?? '').replaceAll(RegExp(r'\D'), '');

/// Ввод ИНН: только цифры, без пробелов.
class InnInputFormatter extends TextInputFormatter {
  const InnInputFormatter({required this.maxDigits});

  /// ООО — 10, ИП — 12.
  final int maxDigits;

  static int formattedCharLimit(int maxDigits) => maxDigits;

  static String formatDigits(String digits, {required int maxDigits}) {
    final trimmed = innDigitsOnly(digits);
    if (trimmed.length <= maxDigits) return trimmed;
    return trimmed.substring(0, maxDigits);
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final formatted = formatDigits(newValue.text, maxDigits: maxDigits);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
