import 'dart:convert';

import 'package:import_service_app/domain/entities/customs_request_file.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Снимок файлов заявки: что клиент уже «видел» (для new vs changed).
final class RequestFileSeenStore {
  RequestFileSeenStore(this._prefs);

  final SharedPreferences _prefs;

  static String _key(String requestId) =>
      'request_file_seen_v1_${requestId.trim()}';

  static String fingerprint(CustomsRequestFile file) {
    final id = (file.id ?? '').trim();
    final updated = (file.updatedAt ?? file.createdAt ?? '').trim();
    final url = (file.fileUrl ?? '').trim();
    return '$id|$updated|$url';
  }

  static String? normalizeDocType(CustomsRequestFile file) {
    final code = (file.docType ?? '').trim().toLowerCase();
    return code.isEmpty ? null : code;
  }

  /// `null` — baseline ещё не задан.
  Map<String, String>? readBaseline(String requestId) {
    final id = requestId.trim();
    if (id.isEmpty) return null;
    final raw = _prefs.getString(_key(id));
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final out = <String, String>{};
      for (final e in decoded.entries) {
        final k = e.key.toString().trim().toLowerCase();
        final v = e.value?.toString() ?? '';
        if (k.isEmpty || v.isEmpty) continue;
        out[k] = v;
      }
      return out;
    } catch (_) {
      return null;
    }
  }

  Future<void> writeBaseline(
    String requestId,
    Map<String, String> fingerprintsByDocType,
  ) async {
    final id = requestId.trim();
    if (id.isEmpty) return;
    await _prefs.setString(_key(id), jsonEncode(fingerprintsByDocType));
  }

  Map<String, String> fingerprintsFromFiles(Iterable<CustomsRequestFile> files) {
    final out = <String, String>{};
    for (final f in files) {
      final code = normalizeDocType(f);
      if (code == null) continue;
      out[code] = fingerprint(f);
    }
    return out;
  }
}

/// Результат сравнения текущего списка с baseline.
final class RequestFileAttentionDiff {
  const RequestFileAttentionDiff({
    this.newDocTypes = const {},
    this.changedDocTypes = const {},
    this.seeded = false,
  });

  final Set<String> newDocTypes;
  final Set<String> changedDocTypes;
  final bool seeded;
}
