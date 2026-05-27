import 'dart:convert';

import 'package:flutter/services.dart';

class MockJsonLoader {
  Future<Map<String, dynamic>> loadMap(String assetPath) async {
    final raw = await rootBundle.loadString(assetPath);
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw FormatException('Expected JSON object in $assetPath');
    }
    return decoded;
  }
}
