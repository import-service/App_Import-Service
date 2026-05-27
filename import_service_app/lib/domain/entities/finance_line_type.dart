import 'package:import_service_app/domain/entities/customs_doc_type.dart';

/// Строка «Финансы» ([VehicleFinanceItem.lineType]).
enum FinanceLineType {
  recyclingFee('recycling_fee'),
  customsDuty('customs_duty');

  const FinanceLineType(this.apiCode);

  final String apiCode;

  static final Map<String, FinanceLineType> _byCode = {
    for (final v in FinanceLineType.values) v.apiCode: v,
  };

  static FinanceLineType? tryParse(String? raw) {
    final code = (raw ?? '').trim();
    if (code.isEmpty) return null;
    return _byCode[code];
  }

  CustomsDocType? get receiptDocType => switch (this) {
        FinanceLineType.recyclingFee => CustomsDocType.paymentRecyclingFeeReceipt,
        FinanceLineType.customsDuty => CustomsDocType.paymentCustomsDutyReceipt,
      };
}
