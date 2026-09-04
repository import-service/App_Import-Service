/// Извлекает VIN (17 символов) из текста QR или произвольной строки.
String? extractVinFromScanPayload(String raw) {
  final compact = raw.toUpperCase().replaceAll(RegExp(r'[^A-HJ-NPR-Z0-9]'), '');
  if (compact.length == 17 && _looksLikeVin(compact)) {
    return compact;
  }
  final match = RegExp(r'[A-HJ-NPR-Z0-9]{17}').firstMatch(compact);
  if (match != null && _looksLikeVin(match.group(0)!)) {
    return match.group(0);
  }
  // Иногда QR = VIN с разделителями
  final spaced = raw.toUpperCase();
  final spacedMatch = RegExp(
    r'[A-HJ-NPR-Z0-9](?:[\s\-]*[A-HJ-NPR-Z0-9]){16}',
  ).firstMatch(spaced);
  if (spacedMatch != null) {
    final v = spacedMatch.group(0)!.replaceAll(RegExp(r'[^A-HJ-NPR-Z0-9]'), '');
    if (v.length == 17 && _looksLikeVin(v)) return v;
  }
  return null;
}

bool _looksLikeVin(String v) {
  if (v.length != 17) return false;
  if (v.contains(RegExp(r'[IOQ]'))) return false;
  return true;
}
