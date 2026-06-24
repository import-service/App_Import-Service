import 'package:import_service_app/core/constants/customs_catalog.dart';
import 'package:import_service_app/domain/entities/customs_request_file.dart';

/// Пара «оригинал / подпись» для пакета на подпись.
final class SigningDocumentPair {
  const SigningDocumentPair({
    required this.baseDocType,
    this.original,
    this.signed,
    required this.needsSignature,
    required this.highlightSignature,
    required this.canUploadSigned,
  });

  final CustomsDocType baseDocType;
  final CustomsRequestFile? original;
  final CustomsRequestFile? signed;
  final bool needsSignature;
  final bool highlightSignature;
  final bool canUploadSigned;
}

/// Группы файлов заявки для карточки (см. project-concept §13).
final class RequestFilesGrouped {
  const RequestFilesGrouped({
    this.creation = const [],
    this.signingPairs = const [],
    this.payment = const [],
    this.transitArchive = const [],
    this.finalDocs = const [],
    this.other = const [],
  });

  final List<CustomsRequestFile> creation;
  final List<SigningDocumentPair> signingPairs;
  final List<CustomsRequestFile> payment;
  final List<CustomsRequestFile> transitArchive;
  final List<CustomsRequestFile> finalDocs;
  final List<CustomsRequestFile> other;
}

RequestFilesGrouped groupRequestFiles({
  required List<CustomsRequestFile> files,
  String? statusSubType,
  String? dealType,
}) {
  final revision =
      RequestStatusSubType.tryParse(statusSubType) ==
      RequestStatusSubType.signatureRevisionRequired;
  final parsedDealType = DealType.tryParse(dealType);
  final parsedSubType = RequestStatusSubType.tryParse(statusSubType);

  final byCode = <String, List<CustomsRequestFile>>{};
  for (final f in files) {
    final code = CustomsDocType.normalizeCode(f.docType);
    if (code.isEmpty) continue;
    byCode.putIfAbsent(code, () => []).add(f);
  }

  CustomsRequestFile? pick(String apiCode) {
    final list = byCode[apiCode];
    if (list == null || list.isEmpty) return null;
    return list.first;
  }

  final packageStarted = isSigningPackageStarted(
    statusSubType: statusSubType,
    fileDocTypes: files.map((f) => f.docType ?? ''),
  );

  final signingContractActive = packageStarted &&
      parsedDealType != null &&
      signingDocTypesForDealType(parsedDealType).contains(CustomsDocType.contract) &&
      pick(CustomsDocType.contract.apiCode) != null;

  final creation = <CustomsRequestFile>[];
  for (final type in CustomsDocType.creationTypes) {
    final list = byCode[type.apiCode];
    if (list == null) continue;
    creation.addAll(list);
  }
  // Старые заявки: `contract` в первичной пачке до пакета на подпись.
  if (!signingContractActive) {
    final legacyContracts = byCode[CustomsDocType.contract.apiCode];
    if (legacyContracts != null) {
      for (final f in legacyContracts) {
        if (!creation.any(
          (e) =>
              CustomsDocType.normalizeCode(e.docType) ==
                  CustomsDocType.contract.apiCode &&
              e.fileUrl == f.fileUrl,
        )) {
          creation.add(f);
        }
      }
    }
  }

  final signingPairs = <SigningDocumentPair>[];
  if (parsedDealType != null) {
    final applicable = signingDocTypesForDealType(parsedDealType);
    final applicableSet = applicable.toSet();

    for (final base in applicable) {
      final original = base.isClientSignOnly ? null : pick(base.apiCode);
      final signed = pick(base.signedApiCode);
      if (!_shouldShowSigningRow(
        base: base,
        original: original,
        signed: signed,
        packageStarted: packageStarted,
        statusSubType: parsedSubType,
      )) {
        continue;
      }

      final clientOnly = base.isClientSignOnly;
      final needsSignature = clientOnly
          ? signed == null
          : (original != null && signed == null) || (revision && signed == null);
      final highlight = needsSignature || revision;
      final canUpload =
          clientOnly || original != null || signed != null || needsSignature || revision;

      signingPairs.add(
        SigningDocumentPair(
          baseDocType: base,
          original: original,
          signed: signed,
          needsSignature: needsSignature,
          highlightSignature: highlight && (needsSignature || revision),
          canUploadSigned: canUpload,
        ),
      );
    }

    // Подпись без базового типа в матрице dealType — только если есть файл.
    for (final key in byCode.keys) {
      if (!key.endsWith('_sign')) continue;
      final base = CustomsDocType.tryParse(key.substring(0, key.length - 5));
      if (base == null || applicableSet.contains(base)) continue;
      if (!base.isSigningBase) continue;

      final signed = pick(key);
      if (signed == null) continue;

      signingPairs.add(
        SigningDocumentPair(
          baseDocType: base,
          original: null,
          signed: signed,
          needsSignature: revision && pick(base.signedApiCode) == null,
          highlightSignature: revision,
          canUploadSigned: true,
        ),
      );
    }
  }

  final payment = <CustomsRequestFile>[];
  for (final type in CustomsDocType.paymentTypes) {
    final list = byCode[type.apiCode];
    if (list != null) payment.addAll(list);
  }

  final transitArchive = <CustomsRequestFile>[];
  for (final f in files) {
    final (type, _) = CustomsDocType.parseWithSign(f.docType);
    if (type?.isTransitArchive ?? false) transitArchive.add(f);
  }

  final finalDocs = <CustomsRequestFile>[];
  for (final type in CustomsDocType.finalTypes) {
    final list = byCode[type.apiCode];
    if (list != null) finalDocs.addAll(list);
  }

  final used = <String>{
    ...creation.map((e) => CustomsDocType.normalizeCode(e.docType)),
    ...signingPairs.expand((p) => [p.baseDocType.apiCode, p.baseDocType.signedApiCode]),
    ...payment.map((e) => CustomsDocType.normalizeCode(e.docType)),
    ...transitArchive.map((e) => CustomsDocType.normalizeCode(e.docType)),
    ...finalDocs.map((e) => CustomsDocType.normalizeCode(e.docType)),
  };

  final other = <CustomsRequestFile>[];
  for (final f in files) {
    final code = CustomsDocType.normalizeCode(f.docType);
    if (code.isEmpty || used.contains(code)) continue;
    if (code.endsWith('_sign')) continue;
    other.add(f);
  }

  return RequestFilesGrouped(
    creation: creation,
    signingPairs: signingPairs,
    payment: payment,
    transitArchive: transitArchive,
    finalDocs: finalDocs,
    other: other,
  );
}

bool _shouldShowSigningRow({
  required CustomsDocType base,
  required CustomsRequestFile? original,
  required CustomsRequestFile? signed,
  required bool packageStarted,
  required RequestStatusSubType? statusSubType,
}) {
  if (!packageStarted) return false;
  if (original != null || signed != null) return true;
  if (!base.isClientSignOnly) return false;
  return isClientOnlySigningSlotVisible(statusSubType);
}

/// Квитанция оплаты без чека — подсветка в секции «Оплата».
bool paymentFileNeedsReceiptHighlight(CustomsRequestFile file, List<CustomsRequestFile> all) {
  final type = CustomsDocType.tryParse(file.docType);
  return switch (type) {
    CustomsDocType.paymentRecyclingFee =>
      !all.any((x) => CustomsDocType.tryParse(x.docType) == CustomsDocType.paymentRecyclingFeeReceipt),
    CustomsDocType.paymentCustomsDuty =>
      !all.any((x) => CustomsDocType.tryParse(x.docType) == CustomsDocType.paymentCustomsDutyReceipt),
    _ => false,
  };
}
