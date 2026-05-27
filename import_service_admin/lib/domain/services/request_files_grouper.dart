import 'package:import_service_admin/core/catalog/customs_request_labels.dart';
import 'package:import_service_admin/domain/entities/customs_request_file.dart';

String normalizeDocTypeCode(String? raw) {
  final code = (raw ?? '').trim();
  if (code.isEmpty) return '';
  switch (code) {
    case 'title_doc':
      return 'invoice';
    case 'transport_application':
      return 'funds_transfer_application';
    default:
      return code;
  }
}

const kCreationDocTypes = [
  'passport_front',
  'passport_registration',
  'inn',
  'snils',
  'invoice',
  'contract',
  'payment_check',
  'car_nameplate_photo',
  'car_mileage_photo',
  'car_front_photo',
  'car_back_photo',
  'add_doc1',
  'add_doc2',
];

const kSigningBaseDocTypes = [
  'recycling_fee_calc',
  'kuts',
  'explanatory_note',
  'customs_rep_agreement',
  'funds_transfer_application',
  'passport_notarized_copy',
  'receipt',
  'additional_agreement',
  'tripartite_agreement',
  'quadripartite_agreement',
  'contract',
];

const kClientSignOnlyDocTypes = {
  'funds_transfer_application',
  'passport_notarized_copy',
};

const kPaymentDocTypes = [
  'payment_recycling_fee',
  'payment_recycling_fee_receipt',
  'payment_customs_duty',
  'payment_customs_duty_receipt',
];

const kTransitArchiveDocTypes = {
  'transit_archive',
  'transit_archive_photo',
  'transit_archive_video',
};

const kFinalDocTypes = ['epts', 'sbkts', 'tpo', 'ptd'];

String signedDocTypeCode(String base) {
  if (base.isEmpty || base.endsWith('_sign')) return base;
  return '${base}_sign';
}

final class SigningDocumentPair {
  const SigningDocumentPair({
    required this.baseDocType,
    this.original,
    this.signed,
  });

  final String baseDocType;
  final CustomsRequestFile? original;
  final CustomsRequestFile? signed;
}

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

RequestFilesGrouped groupRequestFiles(List<CustomsRequestFile> files) {
  final byCode = <String, List<CustomsRequestFile>>{};
  for (final f in files) {
    final code = normalizeDocTypeCode(f.docType);
    if (code.isEmpty) continue;
    byCode.putIfAbsent(code, () => []).add(f);
  }

  CustomsRequestFile? pick(String apiCode) {
    final list = byCode[apiCode];
    if (list == null || list.isEmpty) return null;
    return list.first;
  }

  final hasSigningPackage = kSigningBaseDocTypes.any(
        (t) => byCode.containsKey(t) || byCode.containsKey(signedDocTypeCode(t)),
      ) ||
      byCode.keys.any((k) => k.endsWith('_sign'));

  final creation = <CustomsRequestFile>[];
  for (final type in kCreationDocTypes) {
    final list = byCode[type];
    if (list == null) continue;
    for (final f in list) {
      if (type == 'contract' &&
          hasSigningPackage &&
          byCode.containsKey(signedDocTypeCode('contract'))) {
        continue;
      }
      creation.add(f);
    }
  }

  final signingBases = <String>{
    ...kSigningBaseDocTypes,
    ...byCode.keys
        .where((k) => k.endsWith('_sign'))
        .map((k) => normalizeDocTypeCode(k.substring(0, k.length - 5))),
  };

  final signingPairs = <SigningDocumentPair>[];
  for (final base in signingBases) {
    if (!kSigningBaseDocTypes.contains(base) &&
        !kClientSignOnlyDocTypes.contains(base)) {
      continue;
    }
    final clientOnly = kClientSignOnlyDocTypes.contains(base);
    final original = clientOnly ? null : pick(base);
    final signed = pick(signedDocTypeCode(base));
    if (original != null || signed != null || clientOnly) {
      signingPairs.add(
        SigningDocumentPair(
          baseDocType: base,
          original: original,
          signed: signed,
        ),
      );
    }
  }

  final payment = <CustomsRequestFile>[];
  for (final type in kPaymentDocTypes) {
    payment.addAll(byCode[type] ?? const []);
  }

  final transitArchive = <CustomsRequestFile>[];
  for (final f in files) {
    if (kTransitArchiveDocTypes.contains(normalizeDocTypeCode(f.docType))) {
      transitArchive.add(f);
    }
  }

  final finalDocs = <CustomsRequestFile>[];
  for (final type in kFinalDocTypes) {
    finalDocs.addAll(byCode[type] ?? const []);
  }

  final used = <String>{
    ...creation.map((e) => normalizeDocTypeCode(e.docType)),
    ...signingPairs.expand((p) => [p.baseDocType, signedDocTypeCode(p.baseDocType)]),
    ...payment.map((e) => normalizeDocTypeCode(e.docType)),
    ...transitArchive.map((e) => normalizeDocTypeCode(e.docType)),
    ...finalDocs.map((e) => normalizeDocTypeCode(e.docType)),
  };

  final other = <CustomsRequestFile>[];
  for (final f in files) {
    final code = normalizeDocTypeCode(f.docType);
    if (code.isEmpty || used.contains(code) || code.endsWith('_sign')) continue;
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

String docTypeLabelForCode(String code) =>
    docTypeLabel(code);
