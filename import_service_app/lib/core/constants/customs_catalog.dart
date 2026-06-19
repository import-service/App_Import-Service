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

/// Состав пакета на подпись по `dealType` (catalog-reference.md §2).
List<CustomsDocType> signingDocTypesForDealType(DealType dealType) {
  final types = <CustomsDocType>[
    CustomsDocType.recyclingFeeCalc,
    CustomsDocType.kuts,
    CustomsDocType.explanatoryNote,
    CustomsDocType.customsRepAgreement,
    CustomsDocType.contract,
  ];
  if (dealType != DealType.cash) {
    types.add(CustomsDocType.fundsTransferApplication);
  }
  types.add(CustomsDocType.passportNotarizedCopy);
  switch (dealType) {
    case DealType.cash:
      types.addAll([
        CustomsDocType.receipt,
        CustomsDocType.additionalAgreement,
      ]);
    case DealType.tripartite:
      types.add(CustomsDocType.tripartiteAgreement);
    case DealType.quadripartite:
      types.add(CustomsDocType.quadripartiteAgreement);
    case DealType.bilateral:
      break;
  }
  return types;
}

/// Подстатусы, с которых начинается пакет на подпись (`primary_documents_sent+`).
const Set<RequestStatusSubType> kSigningPackageStartedSubTypes = {
  RequestStatusSubType.primaryDocumentsSent,
  RequestStatusSubType.originalsPartialNoTransit,
  RequestStatusSubType.originalsCompleteNoTransit,
  RequestStatusSubType.signatureRevisionRequired,
  RequestStatusSubType.originalsMissingTransit,
  RequestStatusSubType.originalsPartialTransit,
  RequestStatusSubType.originalsCompleteTransit,
};


/// Пакет на подпись выдан: `primary_documents_sent+` или есть оригинал из 1С (не creation `contract`).
bool isSigningPackageStarted({
  required String? statusSubType,
  required Iterable<String> fileDocTypes,
}) {
  final codes = fileDocTypes.map(CustomsDocType.normalizeCode).where((c) => c.isNotEmpty).toSet();
  final sub = RequestStatusSubType.tryParse(statusSubType);
  if (sub != null && kSigningPackageStartedSubTypes.contains(sub)) {
    return true;
  }
  for (final type in CustomsDocType.signingBaseTypes) {
    if (type.isClientSignOnly || type == CustomsDocType.contract) continue;
    if (codes.contains(type.apiCode)) return true;
  }
  for (final key in codes) {
    if (!key.endsWith('_sign')) continue;
    final base = CustomsDocType.tryParse(key.substring(0, key.length - 5));
    if (base == null || base.isClientSignOnly) continue;
    if (base == CustomsDocType.contract) continue;
    return true;
  }
  return false;
}

/// Client-only типы (`funds_transfer_application`, `passport_notarized_copy`):
/// оригинал из 1С не приходит — слот upload `*_sign` с начала пакета на подпись.
bool isClientOnlySigningSlotVisible(RequestStatusSubType? statusSubType) {
  if (statusSubType == null) return false;
  return kSigningPackageStartedSubTypes.contains(statusSubType);
}
