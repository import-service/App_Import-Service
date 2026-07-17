import 'package:flutter/services.dart';

const int snilsDigitCount = 11;

/// Лимит символов в поле с дефисами: `XXX-XXX-XXX-XX` → 14.
const int snilsFormattedCharLimit = 14;

/// Только цифры СНИЛС (11).
String snilsDigitsOnly(String? raw) => (raw ?? '').replaceAll(RegExp(r'\D'), '');

/// Ввод СНИЛС: `XXX-XXX-XXX-XX` (11 цифр).
class SnilsInputFormatter extends TextInputFormatter {
  const SnilsInputFormatter();

  static String formatDigits(String digits) {
    final trimmed = snilsDigitsOnly(digits);
    final limited = trimmed.length > snilsDigitCount
        ? trimmed.substring(0, snilsDigitCount)
        : trimmed;
    return applyMask(limited);
  }

  /// Отображение из сырой строки/API.
  static String formatDisplay(String? raw) => formatDigits(raw ?? '');

  static String applyMask(String digits) {
    if (digits.isEmpty) return '';

    final b = StringBuffer();
    final p1Len = digits.length >= 3 ? 3 : digits.length;
    b.write(digits.substring(0, p1Len));
    if (digits.length <= 3) return b.toString();

    b.write('-');
    const p2Start = 3;
    final p2Len =
        (digits.length - p2Start) >= 3 ? 3 : (digits.length - p2Start);
    b.write(digits.substring(p2Start, p2Start + p2Len));
    if (digits.length <= 6) return b.toString();

    b.write('-');
    const p3Start = 6;
    final p3Len =
        (digits.length - p3Start) >= 3 ? 3 : (digits.length - p3Start);
    b.write(digits.substring(p3Start, p3Start + p3Len));
    if (digits.length <= 9) return b.toString();

    b.write('-');
    const p4Start = 9;
    final p4Len =
        (digits.length - p4Start) >= 2 ? 2 : (digits.length - p4Start);
    b.write(digits.substring(p4Start, p4Start + p4Len));
    return b.toString();
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final oldDigits = snilsDigitsOnly(oldValue.text);
    var digits = snilsDigitsOnly(newValue.text);

    // Backspace по дефису не убирает цифру — снимаем последнюю цифру сами.
    final isDeletion = newValue.text.length < oldValue.text.length;
    if (isDeletion && digits.length >= oldDigits.length && oldDigits.isNotEmpty) {
      digits = oldDigits.substring(0, oldDigits.length - 1);
    }

    if (digits.length > snilsDigitCount) {
      digits = digits.substring(0, snilsDigitCount);
    }

    final formatted = applyMask(digits);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
