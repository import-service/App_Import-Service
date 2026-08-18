// Краткие и полные тексты ошибок исходящего обмена с 1С (create / update).

const String oneCDeveloperContactHint =
    'Обратитесь к разработчику 1С — проблема на стороне 1С или доступа к её HTTP-сервису.';

String formatOneCErrorDetail(Map<String, dynamic> err) {
  final parts = <String>[];
  final code = err['code'];
  if (code != null) parts.add('$code');
  final msg = err['oneCMessage'] ?? err['message'];
  if (msg != null && '$msg'.trim().isNotEmpty) {
    parts.add(_clipHtmlNoise('$msg'));
  }
  final http = err['httpStatus'];
  if (http != null) parts.add('HTTP $http');
  return parts.isEmpty ? err.toString() : parts.join(' · ');
}

/// Показывать подсказку «к разработчику 1С» (не для наших настроек URL).
bool shouldShowOneCDeveloperHint(Map<String, dynamic>? err) {
  if (err == null || err.isEmpty) return false;
  final code = '${err['code'] ?? ''}'.trim().toUpperCase();
  final reason = '${err['reason'] ?? ''}'.trim().toUpperCase();
  if (reason == 'URL_NOT_CONFIGURED' || code.contains('URL_NOT')) {
    return false;
  }
  return true;
}

/// Одна строка для списка заявок: почему create/update не ушёл в 1С.
String formatOneCOutboundHint({
  required bool isCreate,
  Map<String, dynamic>? lastError,
  int? hoursPending,
}) {
  final kind = isCreate ? 'Create' : 'Update';
  final hours = hoursPending != null ? ' · $hoursPending ч' : '';
  final reason = summarizeOneCOutboundFailure(lastError);
  if (reason != null && reason.isNotEmpty) {
    return '$kind: $reason$hours';
  }
  return isCreate
      ? 'Create в 1С не отправлен$hours'
      : 'Update в 1С не доставлен$hours';
}

/// Понятная причина без HTML-мусора.
String? summarizeOneCOutboundFailure(Map<String, dynamic>? err) {
  if (err == null || err.isEmpty) return null;

  final http = _asInt(err['httpStatus']) ?? _httpFromCode(err['code']);
  final code = '${err['code'] ?? ''}'.trim().toUpperCase();
  final reason = '${err['reason'] ?? ''}'.trim().toUpperCase();
  final msg = _clipHtmlNoise('${err['oneCMessage'] ?? err['message'] ?? ''}');

  if (reason == 'URL_NOT_CONFIGURED' || code.contains('URL_NOT')) {
    return 'URL 1С не настроен в админке';
  }

  if (http == 401) {
    return '1С отклонила запрос (401 Unauthorized)';
  }
  if (http == 403) {
    return '1С отклонила запрос (403 Forbidden)';
  }
  if (http == 404) {
    return '1С: адрес метода не найден (404)';
  }
  if (http != null && http >= 500) {
    return 'Сервер 1С вернул ошибку ($http)';
  }
  if (http != null && http >= 400) {
    return '1С не приняла запрос (HTTP $http)';
  }

  if (_looksLikeUnreachable(code, msg)) {
    return 'Сервер 1С не отвечает';
  }

  if (code.isNotEmpty && code != 'ONE_C_CREATE_FAILED' && code != 'ONE_C_UPDATE_FAILED') {
    return code;
  }
  if (msg.isNotEmpty) {
    return msg.length > 80 ? '${msg.substring(0, 77)}…' : msg;
  }
  return null;
}

bool _looksLikeUnreachable(String code, String msg) {
  final blob = '$code $msg'.toLowerCase();
  return blob.contains('timeout') ||
      blob.contains('etimedout') ||
      blob.contains('econnrefused') ||
      blob.contains('econnreset') ||
      blob.contains('enotfound') ||
      blob.contains('fetch failed') ||
      blob.contains('network') ||
      blob.contains('abort') ||
      blob.contains('недоступ') ||
      blob.contains('не ответ');
}

int? _asInt(Object? v) {
  if (v is int) return v;
  return int.tryParse('$v');
}

int? _httpFromCode(Object? code) {
  final m = RegExp(r'HTTP_(\d{3})', caseSensitive: false).firstMatch('$code');
  if (m == null) return null;
  return int.tryParse(m.group(1)!);
}

String _clipHtmlNoise(String raw) {
  var s = raw.trim();
  if (s.isEmpty) return '';
  if (s.toLowerCase().contains('<html') || s.toLowerCase().contains('<!doctype')) {
    final title = RegExp(
      r'<title[^>]*>([^<]+)</title>',
      caseSensitive: false,
    ).firstMatch(s);
    if (title != null) return title.group(1)!.trim();
    final h1 = RegExp(r'<h1[^>]*>([^<]+)</h1>', caseSensitive: false).firstMatch(s);
    if (h1 != null) return h1.group(1)!.trim();
    return 'HTML-ответ веб-сервера';
  }
  s = s.replaceAll(RegExp(r'\s+'), ' ');
  return s;
}
