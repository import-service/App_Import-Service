import 'dart:collection';

import 'package:import_service_app/core/logging/app_log.dart';

/// Диагностика пушей для TestFlight / Console (особенно iOS).
/// Строки видны в логах устройства и в профиле МП.
final class PushIosDiagnostics {
  PushIosDiagnostics._();

  static const int _maxLines = 40;
  static final ListQueue<String> _lines = ListQueue<String>();

  static List<String> get lines => List<String>.unmodifiable(_lines);

  static String get text =>
      _lines.isEmpty ? 'Пока нет записей push-диагностики' : _lines.join('\n');

  static void log(String message, {String tag = 'PushIOS'}) {
    final ts = DateTime.now().toIso8601String().substring(11, 19);
    final line = '[$ts] $message';
    while (_lines.length >= _maxLines) {
      _lines.removeFirst();
    }
    _lines.addLast(line);
    // print — видно в Console.app / Xcode без фильтров AppLog.
    // ignore: avoid_print
    print('[$tag] $line');
    AppLog.trace(message, tag: tag);
  }

  static void clear() => _lines.clear();
}
