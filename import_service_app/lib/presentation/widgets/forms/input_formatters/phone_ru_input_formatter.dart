import 'package:flutter/services.dart';

/// Формат: +7 (999) 000-00-00.
class PhoneRuInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');

    var normalized = digits;
    if (normalized.startsWith('8')) {
      normalized = '7${normalized.substring(1)}';
    }
    if (!normalized.startsWith('7')) {
      normalized = '7$normalized';
    }
    if (normalized.length > 11) {
      normalized = normalized.substring(0, 11);
    }

    if (normalized.isEmpty) {
      normalized = '7';
    }

    final result = _applyMask(normalized);
    return TextEditingValue(
      text: result,
      selection: TextSelection.collapsed(offset: result.length),
    );
  }

  String _applyMask(String digits) {
    final b = StringBuffer('+7');
    final rest = digits.length > 1 ? digits.substring(1) : '';
    if (rest.isEmpty) return b.toString();

    b.write(' (');
    final areaLen = rest.length >= 3 ? 3 : rest.length;
    b.write(rest.substring(0, areaLen));
    if (areaLen < 3) return b.toString();

    b.write(')');
    final part2Start = areaLen;
    if (rest.length <= part2Start) return b.toString();

    b.write(' ');
    final part2Len = (rest.length - part2Start) >= 3
        ? 3
        : (rest.length - part2Start);
    b.write(rest.substring(part2Start, part2Start + part2Len));
    if (part2Len < 3) return b.toString();

    final part3Start = part2Start + part2Len;
    if (rest.length <= part3Start) return b.toString();

    b.write('-');
    final part3Len = (rest.length - part3Start) >= 2
        ? 2
        : (rest.length - part3Start);
    b.write(rest.substring(part3Start, part3Start + part3Len));
    if (part3Len < 2) return b.toString();

    final part4Start = part3Start + part3Len;
    if (rest.length <= part4Start) return b.toString();

    b.write('-');
    final part4Len = (rest.length - part4Start) >= 2
        ? 2
        : (rest.length - part4Start);
    b.write(rest.substring(part4Start, part4Start + part4Len));
    return b.toString();
  }
}
