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
  });

  final String baseDocType;
  final CustomsRequestFile? original;
  final CustomsRequestFile? signed;
  final bool needsSignature;
  final bool highlightSignature;
}

/// Группы файлов заявки для карточки (см. project-concept §13).
final class RequestFilesGrouped {
  const RequestFilesGrouped({
    this.creation = const [],
    this.signingPairs = const [],
    this.payment = const [],
    this.other = const [],
  });

  final List<CustomsRequestFile> creation;
  final List<SigningDocumentPair> signingPairs;
  final List<CustomsRequestFile> payment;
  final List<CustomsRequestFile> other;
}

RequestFilesGrouped groupRequestFiles({
  required List<CustomsRequestFile> files,
  String? statusSubType,
}) {
  final revision = (statusSubType ?? '').trim() == kStatusSubTypeSignatureRevision;
  final byType = <String, List<CustomsRequestFile>>{};
  for (final f in files) {
    final t = normalizeDocType(f.docType);
    if (t.isEmpty) continue;
    byType.putIfAbsent(t, () => []).add(f);
  }

  CustomsRequestFile? pick(String type) {
    final list = byType[type];
    if (list == null || list.isEmpty) return null;
    return list.first;
  }

  final hasSigningPackage = kSigningBaseDocTypes.any((t) => byType.containsKey(t)) ||
      byType.keys.any(isSignedDocType);

  final creation = <CustomsRequestFile>[];
  for (final type in kCreationDocTypes) {
    final list = byType[type];
    if (list == null) continue;
    for (final f in list) {
      if (type == 'contract' && hasSigningPackage && byType.containsKey('contract_sign')) {
        continue;
      }
      creation.add(f);
    }
  }

  final signingPairs = <SigningDocumentPair>[];
  final signingBases = <String>{
    ...kSigningBaseDocTypes,
    ...byType.keys.where(isSignedDocType).map(baseDocTypeFromSigned),
  };

  for (final base in signingBases) {
    if (!kSigningBaseDocTypes.contains(base) && !isClientSignOnlyDocType(base)) {
      continue;
    }
    final original = pick(base);
    final signed = pick(signedDocType(base));
    final clientOnly = isClientSignOnlyDocType(base);

    final needsSignature = clientOnly
        ? signed == null
        : (original != null && signed == null) || (revision && signed == null);

    final highlight = needsSignature || (revision && base.isNotEmpty);

    if (original != null || signed != null || clientOnly) {
      signingPairs.add(
        SigningDocumentPair(
          baseDocType: base,
          original: clientOnly ? null : original,
          signed: signed,
          needsSignature: needsSignature,
          highlightSignature: highlight && (needsSignature || revision),
        ),
      );
    }
  }

  final payment = <CustomsRequestFile>[];
  for (final type in kPaymentDocTypes) {
    final list = byType[type];
    if (list != null) payment.addAll(list);
  }

  final used = <String>{
    ...creation.map((e) => normalizeDocType(e.docType)),
    ...signingPairs.expand((p) => [
      if (p.original != null) normalizeDocType(p.original!.docType),
      if (p.signed != null) normalizeDocType(p.signed!.docType),
    ]),
    ...payment.map((e) => normalizeDocType(e.docType)),
  };

  final other = <CustomsRequestFile>[];
  for (final f in files) {
    final t = normalizeDocType(f.docType);
    if (t.isEmpty || used.contains(t)) continue;
    if (kFinalDocTypes.contains(t)) continue;
    other.add(f);
  }

  return RequestFilesGrouped(
    creation: creation,
    signingPairs: signingPairs,
    payment: payment,
    other: other,
  );
}
