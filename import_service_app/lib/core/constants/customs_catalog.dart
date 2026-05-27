/// Справочники заявки (синхрон с `import_service_server/src/constants/customsCatalog.js`).
library;

/// Верхний статус `statusSubType` — переподпись.
const String kStatusSubTypeSignatureRevision = 'signature_revision_required';

/// Типы сделки (`dealType`), задаёт 1С при `in_progress`.
const List<String> kDealTypes = [
  'bilateral',
  'cash',
  'tripartite',
  'quadripartite',
];

/// Обязательные `docType` при создании заявки.
const List<String> kRequiredDocTypesOnCreate = [
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
];

const List<String> kOptionalDocTypesOnCreate = ['add_doc1', 'add_doc2'];

/// Все типы этапа «создание».
List<String> get kCreationDocTypes => [
      ...kRequiredDocTypesOnCreate,
      ...kOptionalDocTypesOnCreate,
    ];

/// Базовые типы пакета на подпись (оригинал из 1С или только `*_sign` от клиента).
const List<String> kSigningBaseDocTypes = [
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

/// Только подпись клиента, оригинал из 1С не приходит.
const Set<String> kClientSignOnlyDocTypes = {
  'funds_transfer_application',
  'passport_notarized_copy',
};

const List<String> kPaymentDocTypes = [
  'payment_recycling_fee',
  'payment_recycling_fee_receipt',
  'payment_customs_duty',
  'payment_customs_duty_receipt',
];

const List<String> kFinalDocTypes = ['epts', 'sbkts'];

enum CustomsDocCategory {
  creation,
  signing,
  payment,
  finalDoc,
  other,
}

CustomsDocCategory docCategoryFor(String? rawDocType) {
  final code = normalizeDocType(rawDocType);
  if (code.isEmpty) return CustomsDocCategory.other;
  if (code.endsWith('_sign')) return CustomsDocCategory.signing;
  if (kCreationDocTypes.contains(code)) return CustomsDocCategory.creation;
  if (kSigningBaseDocTypes.contains(code)) return CustomsDocCategory.signing;
  if (kPaymentDocTypes.contains(code)) return CustomsDocCategory.payment;
  if (kFinalDocTypes.contains(code)) return CustomsDocCategory.finalDoc;
  return CustomsDocCategory.other;
}

String normalizeDocType(String? raw) {
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

String signedDocType(String baseDocType) {
  final base = normalizeDocType(baseDocType);
  if (base.isEmpty || base.endsWith('_sign')) return base;
  return '${base}_sign';
}

bool isSignedDocType(String? docType) {
  return normalizeDocType(docType).endsWith('_sign');
}

String baseDocTypeFromSigned(String? signedType) {
  final s = normalizeDocType(signedType);
  if (!s.endsWith('_sign')) return s;
  return s.substring(0, s.length - 5);
}

bool isCreationDocType(String? docType) {
  return kCreationDocTypes.contains(normalizeDocType(docType));
}

bool isSigningBaseDocType(String? docType) {
  final n = normalizeDocType(docType);
  return kSigningBaseDocTypes.contains(n);
}

bool isClientSignOnlyDocType(String? docType) {
  return kClientSignOnlyDocTypes.contains(normalizeDocType(docType));
}
