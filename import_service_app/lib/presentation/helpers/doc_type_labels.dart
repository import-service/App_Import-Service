import 'package:import_service_app/core/i18n/json_strings_service.dart';
import 'package:import_service_app/domain/entities/customs_doc_type.dart';
import 'package:import_service_app/domain/entities/customs_request_file.dart';

String docTypeLabel(CustomsRequestFile file, JsonStringsService s) {
  final (type, signed) = CustomsDocType.parseWithSign(file.docType);
  if (type == null) {
    final name = file.fileName?.trim() ?? '';
    return name.isNotEmpty ? name : s.requestFileGeneric;
  }
  if (signed) {
    return '${docTypeLabelForType(type, s)} (${s.requestDocSignedSuffix})';
  }
  return docTypeLabelForType(type, s, fileName: file.fileName);
}

String docTypeLabelForCode(String code, JsonStringsService s, {String? fileName}) {
  final (type, signed) = CustomsDocType.parseWithSign(code);
  if (type == null) {
    final name = fileName?.trim() ?? '';
    return name.isNotEmpty ? name : s.requestFileGeneric;
  }
  if (signed) {
    return '${docTypeLabelForType(type, s)} (${s.requestDocSignedSuffix})';
  }
  return docTypeLabelForType(type, s, fileName: fileName);
}

String docTypeLabelForType(CustomsDocType type, JsonStringsService s, {String? fileName}) {
  switch (type) {
    case CustomsDocType.passportFront:
      return s.text('reqPassportFrontLabel');
    case CustomsDocType.passportRegistration:
      return s.text('reqPassportAddressLabel');
    case CustomsDocType.inn:
      return s.text('reqInnFileLabel');
    case CustomsDocType.snils:
      return s.text('reqSnilsFileLabel');
    case CustomsDocType.invoice:
      return s.text('reqInvoiceFileLabel');
    case CustomsDocType.contract:
      return s.text('reqContractFileLabel');
    case CustomsDocType.paymentCheck:
      return s.text('reqPaymentReceiptFileLabel');
    case CustomsDocType.carNameplatePhoto:
      return s.text('reqVinPlateFileLabel');
    case CustomsDocType.carMileagePhoto:
      return s.text('reqOdometerFileLabel');
    case CustomsDocType.carFrontPhoto:
      return s.text('reqCarFrontFileLabel');
    case CustomsDocType.carBackPhoto:
      return s.text('reqCarRearFileLabel');
    case CustomsDocType.addDoc1:
      return s.text('reqAdditionalFile1Label');
    case CustomsDocType.addDoc2:
      return s.text('reqAdditionalFile2Label');
    case CustomsDocType.recyclingFeeCalc:
      return s.text('docRecyclingFeeCalc');
    case CustomsDocType.kuts:
      return s.text('docKuts');
    case CustomsDocType.explanatoryNote:
      return s.text('docExplanatoryNote');
    case CustomsDocType.customsRepAgreement:
      return s.text('docCustomsRepAgreement');
    case CustomsDocType.fundsTransferApplication:
      return s.text('docFundsTransferApplication');
    case CustomsDocType.passportNotarizedCopy:
      return s.text('docPassportNotarizedCopy');
    case CustomsDocType.receipt:
      return s.text('docReceipt');
    case CustomsDocType.additionalAgreement:
      return s.text('docAdditionalAgreement');
    case CustomsDocType.tripartiteAgreement:
      return s.text('docTripartiteAgreement');
    case CustomsDocType.quadripartiteAgreement:
      return s.text('docQuadripartiteAgreement');
    case CustomsDocType.paymentRecyclingFee:
      return s.text('docPaymentRecyclingFee');
    case CustomsDocType.paymentRecyclingFeeReceipt:
      return s.text('docPaymentRecyclingFeeReceipt');
    case CustomsDocType.paymentCustomsDuty:
      return s.text('docPaymentCustomsDuty');
    case CustomsDocType.paymentCustomsDutyReceipt:
      return s.text('docPaymentCustomsDutyReceipt');
    case CustomsDocType.epts:
      return s.text('docEpts');
    case CustomsDocType.sbkts:
      return s.text('docSbcts');
    case CustomsDocType.tpo:
      return s.text('docTpo');
    case CustomsDocType.ptd:
      return s.text('docPtd');
    case CustomsDocType.transitArchive:
      return s.text('docTransitArchive');
    case CustomsDocType.transitArchivePhoto:
      return s.text('docTransitArchivePhoto');
    case CustomsDocType.transitArchiveVideo:
      return s.text('docTransitArchiveVideo');
    case CustomsDocType.uploadedFile:
      return s.text('docUploadedFile');
  }
}
