import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:import_service_admin/core/error/exceptions.dart';

/// Логи 1С в консоль debug (Chrome DevTools / IDE), фильтр по имени `1C`.
abstract final class OneCLog {
  static const _name = '1C';

  /// Успех `resend-to-1c`: тело ответа 1С и полный ответ API.
  static void resendSuccess(String requestId, Map<String, dynamic> apiBody) {
    if (!kDebugMode) return;
    developer.log('resend-to-1c #$requestId: успех', name: _name);
    final oneC = apiBody['oneC'];
    if (oneC is Map<String, dynamic>) {
      final response = oneC['response'];
      if (response != null) {
        _logJson('1С ответила (создание заявки)', _wrapJson(response));
      }
      final link = oneC['link'];
      if (link != null) {
        _logJson('привязка у нас', _wrapJson(link));
      }
    } else {
      developer.log('(блок oneC в ответе API отсутствует)', name: _name);
    }
    _logJson('полный ответ API', apiBody);
  }

  static void failure(OneCCreateFailedException e, {String? action}) {
    if (!kDebugMode) return;
    final prefix = action != null ? '$action: ' : '';
    developer.log('$prefixошибка — ${e.message}', name: _name);
    final oneC = e.oneC;
    if (oneC != null && oneC.isNotEmpty) {
      _logJson('детали 1С / HTTP', oneC);
    }
  }

  static Map<String, dynamic> _wrapJson(Object value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return <String, dynamic>{'value': value};
  }

  static void _logJson(String label, Map<String, dynamic> data) {
    try {
      final text = const JsonEncoder.withIndent('  ').convert(data);
      developer.log('$label:\n$text', name: _name);
    } catch (_) {
      developer.log('$label: $data', name: _name);
    }
  }
}
