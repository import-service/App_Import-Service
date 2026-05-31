import 'package:import_service_app/core/i18n/json_strings_service.dart';
import 'package:import_service_app/domain/entities/car_list_item.dart';
import 'package:import_service_app/domain/entities/customs_doc_type.dart';
import 'package:import_service_app/domain/entities/request_status.dart';
import 'package:import_service_app/domain/entities/request_status_sub_type.dart';

/// Подсказка-действие по [CarListItem.statusSubType] (дополняет подпись подстатуса).
String? requestStatusActionHint(CarListItem item, JsonStringsService s) {
  final sub = RequestStatusSubType.tryParse(item.statusSubType);
  if (sub == null) return null;

  switch (sub) {
    case RequestStatusSubType.signatureRevisionRequired:
      return s.requestHintSignatureRevision;
    case RequestStatusSubType.primaryDocumentsSent:
      return s.requestHintSignDocuments;
    case RequestStatusSubType.originalsPartialNoTransit:
    case RequestStatusSubType.originalsCompleteNoTransit:
    case RequestStatusSubType.originalsMissingTransit:
    case RequestStatusSubType.originalsPartialTransit:
    case RequestStatusSubType.originalsCompleteTransit:
      return s.requestHintOriginalsToOffice;
    case RequestStatusSubType.svhNoOriginalsNoRecycling:
    case RequestStatusSubType.svhPartialDocsNoRecycling:
    case RequestStatusSubType.svhNoOriginalsRecycling:
    case RequestStatusSubType.svhPartialDocsRecycling:
    case RequestStatusSubType.svhAllDocsNoRecycling:
    case RequestStatusSubType.svhAllDocsRecycling:
    case RequestStatusSubType.ptdSubmitted:
    case RequestStatusSubType.ptdSubmittedPaid:
    case RequestStatusSubType.ptdRelease:
    case RequestStatusSubType.sentToLab:
      return s.requestHintProcessingAtCustoms;
    case RequestStatusSubType.issuedToClient:
      return s.requestHintIssuedToClient;
    case RequestStatusSubType.requestClosed:
      return s.requestHintRequestClosed;
    case RequestStatusSubType.draft:
    case RequestStatusSubType.managerExecution:
      return null;
  }
}

bool requestNeedsPaymentReceiptAction(CarListItem item) {
  final hasRecyclingFee = item.files.any(
    (f) => CustomsDocType.tryParse(f.docType) == CustomsDocType.paymentRecyclingFee,
  );
  final hasRecyclingReceipt = item.files.any(
    (f) =>
        CustomsDocType.tryParse(f.docType) == CustomsDocType.paymentRecyclingFeeReceipt,
  );
  final hasDutyFee = item.files.any(
    (f) => CustomsDocType.tryParse(f.docType) == CustomsDocType.paymentCustomsDuty,
  );
  final hasDutyReceipt = item.files.any(
    (f) => CustomsDocType.tryParse(f.docType) == CustomsDocType.paymentCustomsDutyReceipt,
  );
  if (hasRecyclingFee && !hasRecyclingReceipt) return true;
  if (hasDutyFee && !hasDutyReceipt) return true;
  return false;
}

bool requestDetailShouldShowDocumentsBlock(CarListItem item, JsonStringsService s) {
  if (item.files.isNotEmpty) return true;
  if (requestStatusActionHint(item, s) != null) return true;
  if (requestNeedsPaymentReceiptAction(item)) return true;
  return item.status == RequestStatus.inProgress ||
      item.status == RequestStatus.inTransit;
}
