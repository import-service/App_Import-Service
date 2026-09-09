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

/// DocType, которые менеджер СВХ может загружать (галерея / архив), без анкеты/подписей/оплат.
bool isSvhManagerAllowedDocType(String? docType) {
  final c = normalizeDocType(docType);
  if (c.isEmpty) return false;
  if (isSvhCarGalleryDocType(c)) return true;
  if (c == 'add_doc1' || c == 'add_doc2') return true;
  if (c == 'transit_archive_photo' || c == 'transit_archive_video') return true;
  if (RegExp(r'^transit_archive_photo_\d+$').hasMatch(c)) return true;
  return false;
}

/// Галерея «Фото машины» от СВХ: `svh_car_photo_1` … `svh_car_photo_80`.
const int kSvhCarGalleryMaxPhotos = 80;

bool isSvhCarGalleryDocType(String? docType) {
  final c = normalizeDocType(docType);
  return RegExp(r'^svh_car_photo_\d+$').hasMatch(c);
}

String svhCarGalleryDocType(int index) => 'svh_car_photo_$index';

/// Свободные индексы 1…[kSvhCarGalleryMaxPhotos] под новые фото.
List<int> nextSvhCarGalleryIndices({
  required Iterable<String?> existingDocTypes,
  required int count,
}) {
  final used = <int>{};
  final re = RegExp(r'^svh_car_photo_(\d+)$');
  for (final raw in existingDocTypes) {
    final m = re.firstMatch(normalizeDocType(raw));
    if (m == null) continue;
    final n = int.tryParse(m.group(1)!);
    if (n != null) used.add(n);
  }
  final out = <int>[];
  for (var i = 1;
      i <= kSvhCarGalleryMaxPhotos && out.length < count;
      i++) {
    if (!used.contains(i)) out.add(i);
  }
  return out;
}

/// Слоты архива перед транзитом (опционально для СВХ в «к выдаче»).
const List<String> kSvhTransitUploadDocTypes = [
  'transit_archive_photo_1',
  'transit_archive_photo_2',
  'transit_archive_photo_3',
];

const List<String> kSvhOtherUploadDocTypes = [
  'add_doc1',
  'add_doc2',
];

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


/// Пакет на подпись выдан: `primary_documents_sent+` или есть оригинал из 1С (не creation `contract_original`).
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

/// Client-only типы (`passport_notarized_copy`):
/// оригинал из 1С не приходит — слот upload `*_sign` с начала пакета на подпись.
/// `funds_transfer_application` в секции «На подпись» МП не показывается.
bool isClientOnlySigningSlotVisible(RequestStatusSubType? statusSubType) {
  if (statusSubType == null) return false;
  return kSigningPackageStartedSubTypes.contains(statusSubType);
}
