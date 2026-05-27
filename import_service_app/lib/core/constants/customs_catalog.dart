/// Справочники заявки (фасад над enum в `domain/entities/`).
library;

import 'package:import_service_app/domain/entities/customs_doc_type.dart';
import 'package:import_service_app/domain/entities/deal_type.dart';
import 'package:import_service_app/domain/entities/finance_line_type.dart';
import 'package:import_service_app/domain/entities/request_status_sub_type.dart';

export 'package:import_service_app/domain/entities/customs_doc_type.dart';
export 'package:import_service_app/domain/entities/deal_type.dart';
export 'package:import_service_app/domain/entities/finance_line_type.dart';
export 'package:import_service_app/domain/entities/request_status_sub_type.dart';

/// @deprecated Используйте [RequestStatusSubType.signatureRevisionRequired].
String get kStatusSubTypeSignatureRevision =>
    RequestStatusSubType.signatureRevisionRequired.apiCode;

List<String> get kDealTypes => DealType.values.map((e) => e.apiCode).toList();

List<String> get kRequiredDocTypesOnCreate =>
    CustomsDocType.requiredOnCreate.map((e) => e.apiCode).toList();

List<String> get kOptionalDocTypesOnCreate =>
    CustomsDocType.optionalOnCreate.map((e) => e.apiCode).toList();

List<String> get kCreationDocTypes =>
    CustomsDocType.creationTypes.map((e) => e.apiCode).toList();

List<String> get kSigningBaseDocTypes =>
    CustomsDocType.signingBaseTypes.map((e) => e.apiCode).toList();

Set<String> get kClientSignOnlyDocTypes =>
    CustomsDocType.clientSignOnlyTypes.map((e) => e.apiCode).toSet();

List<String> get kPaymentDocTypes =>
    CustomsDocType.paymentTypes.map((e) => e.apiCode).toList();

List<String> get kTransitArchiveDocTypes =>
    CustomsDocType.transitArchiveTypes.map((e) => e.apiCode).toList();

List<String> get kFinalDocTypes =>
    CustomsDocType.finalTypes.map((e) => e.apiCode).toList();

enum CustomsDocCategory {
  creation,
  signing,
  payment,
  finalDoc,
  other,
}

CustomsDocCategory docCategoryFor(String? rawDocType) {
  final (type, signed) = CustomsDocType.parseWithSign(rawDocType);
  if (type == null) return CustomsDocCategory.other;
  if (signed) return CustomsDocCategory.signing;
  if (type.isCreation) return CustomsDocCategory.creation;
  if (type.isSigningBase) return CustomsDocCategory.signing;
  if (type.isPayment) return CustomsDocCategory.payment;
  if (type.isTransitArchive) return CustomsDocCategory.other;
  if (type.isFinal) return CustomsDocCategory.finalDoc;
  return CustomsDocCategory.other;
}

bool isTransitArchiveDocType(String? docType) {
  final (type, _) = CustomsDocType.parseWithSign(docType);
  return type?.isTransitArchive ?? false;
}

bool isFinalDocType(String? docType) {
  final (type, _) = CustomsDocType.parseWithSign(docType);
  return type?.isFinal ?? false;
}

String normalizeDocType(String? raw) => CustomsDocType.normalizeCode(raw);

String signedDocType(String baseDocType) {
  final type = CustomsDocType.tryParse(baseDocType);
  if (type == null) return normalizeDocType(baseDocType);
  return type.signedApiCode;
}

bool isSignedDocType(String? docType) {
  return CustomsDocType.parseWithSign(docType).$2;
}

String baseDocTypeFromSigned(String? signedType) {
  final (type, signed) = CustomsDocType.parseWithSign(signedType);
  if (!signed || type == null) return normalizeDocType(signedType);
  return type.apiCode;
}

bool isCreationDocType(String? docType) {
  final (type, signed) = CustomsDocType.parseWithSign(docType);
  return !signed && (type?.isCreation ?? false);
}

bool isSigningBaseDocType(String? docType) {
  final (type, signed) = CustomsDocType.parseWithSign(docType);
  return !signed && (type?.isSigningBase ?? false);
}

bool isClientSignOnlyDocType(String? docType) {
  final (type, signed) = CustomsDocType.parseWithSign(docType);
  return !signed && (type?.isClientSignOnly ?? false);
}

String? receiptDocTypeForFinanceLineType(String? lineType) {
  return FinanceLineType.tryParse(lineType)?.receiptDocType?.apiCode;
}

String? receiptDocTypeForPaymentFee(String? feeDocType) {
  final type = CustomsDocType.tryParse(feeDocType);
  return switch (type) {
    CustomsDocType.paymentRecyclingFee => CustomsDocType.paymentRecyclingFeeReceipt.apiCode,
    CustomsDocType.paymentCustomsDuty => CustomsDocType.paymentCustomsDutyReceipt.apiCode,
    _ => null,
  };
}
