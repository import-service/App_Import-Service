import 'package:import_service_app/core/i18n/json_strings_service.dart';
import 'package:import_service_app/domain/entities/deal_type.dart';

/// Подпись вида сделки для UI.
String? dealTypeLabelForCode(String? raw, JsonStringsService s) {
  final type = DealType.tryParse(raw);
  if (type == null) return null;
  return s.dealTypeLabel(type);
}
