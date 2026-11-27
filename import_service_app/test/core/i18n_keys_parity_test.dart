import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('zh.json has all keys of ru.json', () {
    final ru = jsonDecode(
      File('assets/i18n/ru.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final zh = jsonDecode(
      File('assets/i18n/zh.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final missing = ru.keys.where((k) => !zh.containsKey(k)).toList();
    expect(
      missing,
      isEmpty,
      reason: 'Missing zh keys: ${missing.join(', ')}',
    );
  });
}
