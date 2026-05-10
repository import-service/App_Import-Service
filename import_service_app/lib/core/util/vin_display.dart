/// VIN в данных — всегда полный номер. Звёздочки только для **отображения** в списке/карточке.
String formatVinForList(String? vin) {
  final v = vin
          ?.trim()
          .toUpperCase()
          .replaceAll(RegExp(r'\s+'), '') ??
      '';
  if (v.isEmpty) {
    return '—';
  }
  const visible = 4;
  if (v.length <= visible) {
    return v;
  }
  return '${'*' * (v.length - visible)}${v.substring(v.length - visible)}';
}

/// VIN на экране детализации: полный, верхний регистр.
String formatVinForDetail(String? vin) {
  final v = vin?.trim() ?? '';
  if (v.isEmpty) {
    return '—';
  }
  return v.toUpperCase();
}
