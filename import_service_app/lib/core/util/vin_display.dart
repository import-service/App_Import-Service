/// VIN в UI — всегда полный номер (без маскирования).
String formatVinForList(String? vin) => formatVinForDetail(vin);

/// VIN: полный, верхний регистр.
String formatVinForDetail(String? vin) {
  final v = vin?.trim() ?? '';
  if (v.isEmpty) {
    return '—';
  }
  return v.toUpperCase().replaceAll(RegExp(r'\s+'), '');
}
