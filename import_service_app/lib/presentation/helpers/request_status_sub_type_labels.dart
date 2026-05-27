import 'package:import_service_app/core/i18n/json_strings_service.dart';
import 'package:import_service_app/domain/entities/request_status_sub_type.dart';

/// Подпись подстатуса для UI (ключи `statusSubType_*` в i18n).
String? requestStatusSubTypeLabel(String? raw, JsonStringsService s) {
  final sub = RequestStatusSubType.tryParse(raw);
  if (sub == null) return null;
  return s.statusSubTypeLabel(sub);
}
