import 'dart:async';
import 'dart:io' show Platform;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:import_service_app/core/logging/app_log.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Отправка клиентских ошибок на `POST /api/client-errors` (без блокировки UI).
final class ClientErrorReporter {
  ClientErrorReporter(this._dio);

  final Dio _dio;
  static ClientErrorReporter? instance;

  static const int _maxPerHour = 40;
  static const Duration _dedupeWindow = Duration(seconds: 90);

  final List<DateTime> _sentAt = [];
  final Map<String, DateTime> _recentFingerprints = {};
  PackageInfo? _packageInfo;
  bool _sending = false;

  static void install(Dio dio) {
    final reporter = ClientErrorReporter(dio);
    instance = reporter;
    AppLog.remoteErrorSink = reporter.reportFromAppLog;
  }

  void reportFromAppLog({
    required String message,
    String? tag,
    Object? error,
    StackTrace? stackTrace,
  }) {
    final buf = StringBuffer(message);
    if (error != null) buf.write(' | $error');
    unawaited(
      report(
        message: buf.toString(),
        tag: tag ?? 'AppLog',
        stack: stackTrace?.toString(),
        fatal: false,
      ),
    );
  }

  Future<void> report({
    required String message,
    String? tag,
    String? stack,
    bool fatal = false,
  }) async {
    if (kIsWeb) return;
    final cleaned = _sanitize(message);
    if (cleaned.isEmpty) return;

    final fp = '${tag ?? ''}|${cleaned.take(200)}|${(stack ?? '').take(300)}';
    final now = DateTime.now();
    final last = _recentFingerprints[fp];
    if (last != null && now.difference(last) < _dedupeWindow) return;
    _recentFingerprints[fp] = now;
    _recentFingerprints.removeWhere(
      (_, t) => now.difference(t) > const Duration(minutes: 10),
    );

    _sentAt.removeWhere((t) => now.difference(t) > const Duration(hours: 1));
    if (_sentAt.length >= _maxPerHour) return;
    if (_sending) {
      // Не копим очередь при шторме — один in-flight достаточно.
    }

    _sentAt.add(now);
    _sending = true;
    try {
      _packageInfo ??= await PackageInfo.fromPlatform();
      final info = _packageInfo!;
      final platform = Platform.isAndroid
          ? 'android'
          : Platform.isIOS
              ? 'ios'
              : Platform.operatingSystem;

      await _dio.post<dynamic>(
        'client-errors',
        data: <String, dynamic>{
          'message': cleaned.take(1024),
          if (stack != null && stack.trim().isNotEmpty)
            'stack': stack.trim().take(16000),
          if (tag != null && tag.trim().isNotEmpty) 'tag': tag.trim().take(64),
          'platform': platform,
          'appVersion': info.version,
          'buildNumber': info.buildNumber,
          'fatal': fatal,
          'deviceInfo':
              '${Platform.operatingSystem} ${Platform.operatingSystemVersion}'
                  .take(256),
        },
        options: Options(
          sendTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 8),
          // Ошибки репорта не должны триггерить session-lost.
          validateStatus: (code) => code != null && code < 500,
        ),
      );
    } catch (_) {
      // Молча: репорт не должен ронять приложение и не логировать в цикл.
    } finally {
      _sending = false;
    }
  }
}

extension on String {
  String take(int max) => length <= max ? this : substring(0, max);
}

String _sanitize(String raw) {
  var s = raw.trim();
  // Не тащим токены/пароли из редких логов.
  s = s.replaceAll(
    RegExp(r'(Bearer\s+)[A-Za-z0-9\-._~+/]+=*', caseSensitive: false),
    r'$1***',
  );
  s = s.replaceAll(
    RegExp(r'(password["\s:=]+)[^\s,;"]+', caseSensitive: false),
    r'$1***',
  );
  return s;
}
