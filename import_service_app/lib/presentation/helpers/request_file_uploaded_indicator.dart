import 'package:import_service_app/core/constants/customs_catalog.dart';
import 'package:import_service_app/domain/entities/customs_doc_type.dart';
import 'package:import_service_app/domain/entities/customs_request_file.dart';

/// Зелёная галочка: файл загружен клиентом (подпись или чек оплаты).
bool shouldShowUploadedCheck(CustomsRequestFile file) {
  final (type, signed) = CustomsDocType.parseWithSign(file.docType);
  if (type == null) return false;
  if (signed) return true;
  return type == CustomsDocType.paymentRecyclingFeeReceipt ||
      type == CustomsDocType.paymentCustomsDutyReceipt;
}

CustomsRequestFile? findFileByDocType(
  Iterable<CustomsRequestFile> files,
  CustomsDocType type,
) {
  for (final f in files) {
    if (CustomsDocType.tryParse(f.docType) == type) return f;
  }
  return null;
}

/// Пары «квитанция из 1С → чек от клиента» для секции «Оплата».
const List<(CustomsDocType fee, CustomsDocType receipt)> kPaymentFeeReceiptPairs = [
  (CustomsDocType.paymentRecyclingFee, CustomsDocType.paymentRecyclingFeeReceipt),
  (CustomsDocType.paymentCustomsDuty, CustomsDocType.paymentCustomsDutyReceipt),
];

String paymentReceiptUploadLabel({
  required bool hasReceipt,
  required String uploadAgain,
  required String uploadFirst,
}) {
  return hasReceipt ? uploadAgain : uploadFirst;
}
