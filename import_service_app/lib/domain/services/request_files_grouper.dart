import 'package:import_service_app/domain/entities/customs_doc_type.dart';
import 'package:import_service_app/domain/entities/customs_request_file.dart';
import 'package:import_service_app/domain/entities/request_status_sub_type.dart';

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
}) {
  final revision =
      RequestStatusSubType.tryParse(statusSubType) ==
      RequestStatusSubType.signatureRevisionRequired;

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

  final hasSigningPackage = CustomsDocType.signingBaseTypes.any(
        (t) => byCode.containsKey(t.apiCode) || byCode.containsKey(t.signedApiCode),
      ) ||
      byCode.keys.any((k) => k.endsWith('_sign'));

  final creation = <CustomsRequestFile>[];
  for (final type in CustomsDocType.creationTypes) {
    final list = byCode[type.apiCode];
    if (list == null) continue;
    for (final f in list) {
      if (type == CustomsDocType.contract &&
          hasSigningPackage &&
          byCode.containsKey(CustomsDocType.contract.signedApiCode)) {
        continue;
      }
      creation.add(f);
    }
  }

  final signingPairs = <SigningDocumentPair>[];
  final signingBases = <CustomsDocType>{
    ...CustomsDocType.signingBaseTypes,
    ...byCode.keys
        .where((k) => k.endsWith('_sign'))
        .map((k) => CustomsDocType.tryParse(k.substring(0, k.length - 5)))
        .whereType<CustomsDocType>(),
  };

  for (final base in signingBases) {
    if (!base.isSigningBase && !base.isClientSignOnly) continue;
    final original = base.isClientSignOnly ? null : pick(base.apiCode);
    final signed = pick(base.signedApiCode);
    final clientOnly = base.isClientSignOnly;

    final needsSignature = clientOnly
        ? signed == null
        : (original != null && signed == null) || (revision && signed == null);

    final highlight = needsSignature || revision;
    final canUpload =
        clientOnly || original != null || signed != null || needsSignature || revision;

    if (original != null || signed != null || clientOnly) {
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
