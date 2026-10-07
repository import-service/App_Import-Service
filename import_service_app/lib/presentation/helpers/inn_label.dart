import 'package:import_service_app/data/models/registration_request_model.dart';

/// Если orgType пуст — эвристика по длине ИНН (10 → ООО, 12 → ИП).
OrganizationType resolveOrganizationTypeForInnLabel({
  required String? orgType,
  required String? inn,
}) {
  final parsed = OrganizationTypeInn.tryParse(orgType);
  if (parsed != null) return parsed;
  final digits = (inn ?? '').replaceAll(RegExp(r'\D'), '');
  if (digits.length == 12) return OrganizationType.ip;
  return OrganizationType.ooo;
}
