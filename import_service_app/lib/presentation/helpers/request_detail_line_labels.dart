import 'package:import_service_app/core/i18n/json_strings_service.dart';
import 'package:import_service_app/domain/entities/vehicle_finance_item.dart';

String financeItemLabel(VehicleFinanceItem line, JsonStringsService s) {
  final t = line.title?.trim() ?? '';
  if (t.isNotEmpty) {
    return t;
  }
  if (line.lineType == 'recycling_fee') {
    return s.requestDetailFinanceRecycling;
  }
  return s.requestDetailFinanceDuty;
}
