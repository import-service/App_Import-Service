/// Извлекает VIN (17 символов) из текста QR или произвольной строки.
/// Алфавит VIN: A–Z и 0–9 без I, O, Q.
String? extractVinFromScanPayload(String raw) {
  final compact = raw.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
  if (compact.length == 17 && _looksLikeVin(compact)) {
    return compact;
  }
  // Скользящее окно на случай мусора вокруг VIN.
  for (var i = 0; i + 17 <= compact.length; i++) {
    final candidate = compact.substring(i, i + 17);
    if (_looksLikeVin(candidate)) return candidate;
  }
  final spaced = raw.toUpperCase();
  final spacedMatch = RegExp(
    r'[A-Z0-9](?:[\s\-]*[A-Z0-9]){16}',
  ).firstMatch(spaced);
  if (spacedMatch != null) {
    final v = spacedMatch.group(0)!.replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (v.length == 17 && _looksLikeVin(v)) return v;
  }
  return null;
}

bool _looksLikeVin(String v) {
  if (v.length != 17) return false;
  if (v.contains(RegExp(r'[IOQ]'))) return false;
  return true;
}
