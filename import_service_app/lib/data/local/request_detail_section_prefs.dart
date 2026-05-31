import 'package:shared_preferences/shared_preferences.dart';

/// Свёрнутость секций детализации заявки (по requestId + sectionKey).
final class RequestDetailSectionPrefs {
  RequestDetailSectionPrefs(this._prefs);

  final SharedPreferences _prefs;

  static String _key(String requestId, String sectionKey) =>
      'request_detail_exp_${requestId.trim()}_$sectionKey';

  /// `null` — пользователь ещё не менял; иначе сохранённое expanded.
  bool? readExpanded(String requestId, String sectionKey) {
    final id = requestId.trim();
    if (id.isEmpty) return null;
    if (!_prefs.containsKey(_key(id, sectionKey))) return null;
    return _prefs.getBool(_key(id, sectionKey));
  }

  Future<void> saveExpanded(
    String requestId,
    String sectionKey,
    bool expanded,
  ) async {
    final id = requestId.trim();
    if (id.isEmpty) return;
    await _prefs.setBool(_key(id, sectionKey), expanded);
  }
}

/// Ключи секций детализации (persist + логика раскрытия).
abstract final class RequestDetailSectionKeys {
  static const owner = 'owner';
  static const finances = 'finances';
  static const filesCreation = 'files_creation';
  static const filesSigning = 'files_signing';
  static const filesPayment = 'files_payment';
  static const filesTransit = 'files_transit';
  static const filesFinal = 'files_final';
  static const filesOther = 'files_other';
}
