import 'package:import_service_app/core/constants/customs_catalog.dart';
import 'package:import_service_app/core/i18n/json_strings_service.dart';
import 'package:import_service_app/domain/entities/customs_request_file.dart';

String docTypeLabel(CustomsRequestFile file, JsonStringsService s) {
  final code = normalizeDocType(file.docType);
  if (isSignedDocType(code)) {
    final base = baseDocTypeFromSigned(code);
    return '${docTypeLabelForCode(base, s)} (${s.requestDocSignedSuffix})';
  }
  return docTypeLabelForCode(code, s, fileName: file.fileName);
}

String docTypeLabelForCode(String code, JsonStringsService s, {String? fileName}) {
  switch (code) {
    case 'passport_front':
      return s.text('reqPassportFrontLabel');
    case 'passport_registration':
      return s.text('reqPassportAddressLabel');
    case 'inn':
      return s.text('reqInnFileLabel');
    case 'snils':
      return s.text('reqSnilsFileLabel');
    case 'invoice':
      return s.text('reqInvoiceFileLabel');
    case 'contract':
      return s.text('reqContractFileLabel');
    case 'payment_check':
      return s.text('reqPaymentReceiptFileLabel');
    case 'car_nameplate_photo':
      return s.text('reqVinPlateFileLabel');
    case 'car_mileage_photo':
      return s.text('reqOdometerFileLabel');
    case 'car_front_photo':
      return s.text('reqCarFrontFileLabel');
    case 'car_back_photo':
      return s.text('reqCarRearFileLabel');
    case 'add_doc1':
      return s.text('reqAdditionalFile1Label');
    case 'add_doc2':
      return s.text('reqAdditionalFile2Label');
    case 'recycling_fee_calc':
      return s.text('docRecyclingFeeCalc');
    case 'kuts':
      return s.text('docKuts');
    case 'explanatory_note':
      return s.text('docExplanatoryNote');
    case 'customs_rep_agreement':
      return s.text('docCustomsRepAgreement');
    case 'funds_transfer_application':
      return s.text('docFundsTransferApplication');
    case 'passport_notarized_copy':
      return s.text('docPassportNotarizedCopy');
    case 'receipt':
      return s.text('docReceipt');
    case 'additional_agreement':
      return s.text('docAdditionalAgreement');
    case 'tripartite_agreement':
      return s.text('docTripartiteAgreement');
    case 'quadripartite_agreement':
      return s.text('docQuadripartiteAgreement');
    case 'payment_recycling_fee':
      return s.text('docPaymentRecyclingFee');
    case 'payment_recycling_fee_receipt':
      return s.text('docPaymentRecyclingFeeReceipt');
    case 'payment_customs_duty':
      return s.text('docPaymentCustomsDuty');
    case 'payment_customs_duty_receipt':
      return s.text('docPaymentCustomsDutyReceipt');
    case 'epts':
      return s.text('docEpts');
    case 'sbkts':
      return s.text('docSbcts');
    default:
      final name = fileName?.trim() ?? '';
      return name.isNotEmpty ? name : s.text('requestFileGeneric');
  }
}
