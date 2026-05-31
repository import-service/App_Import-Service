/// Типы документов заявки (`docType`). Синхрон с бэкендом `customsCatalog.js`.
enum CustomsDocType {
  passportFront('passport_front'),
  passportRegistration('passport_registration'),
  inn('inn'),
  snils('snils'),
  invoice('invoice'),
  contract('contract'),
  paymentCheck('payment_check'),
  carNameplatePhoto('car_nameplate_photo'),
  carMileagePhoto('car_mileage_photo'),
  carFrontPhoto('car_front_photo'),
  carBackPhoto('car_back_photo'),
  addDoc1('add_doc1'),
  addDoc2('add_doc2'),
  recyclingFeeCalc('recycling_fee_calc'),
  kuts('kuts'),
  explanatoryNote('explanatory_note'),
  customsRepAgreement('customs_rep_agreement'),
  fundsTransferApplication('funds_transfer_application'),
  passportNotarizedCopy('passport_notarized_copy'),
  receipt('receipt'),
  additionalAgreement('additional_agreement'),
  tripartiteAgreement('tripartite_agreement'),
  quadripartiteAgreement('quadripartite_agreement'),
  paymentRecyclingFee('payment_recycling_fee'),
  paymentRecyclingFeeReceipt('payment_recycling_fee_receipt'),
  paymentCustomsDuty('payment_customs_duty'),
  paymentCustomsDutyReceipt('payment_customs_duty_receipt'),
  transitArchive('transit_archive'),
  transitArchivePhoto('transit_archive_photo'),
  transitArchiveVideo('transit_archive_video'),
  epts('epts'),
  sbkts('sbkts'),
  tpo('tpo'),
  ptd('ptd'),
  uploadedFile('uploaded_file');

  const CustomsDocType(this.apiCode);

  final String apiCode;

  static final Map<String, CustomsDocType> _byCode = {
    for (final v in CustomsDocType.values) v.apiCode: v,
  };

  static const List<CustomsDocType> requiredOnCreate = [
    passportFront,
    passportRegistration,
    inn,
    snils,
    invoice,
    contract,
    paymentCheck,
    carNameplatePhoto,
    carMileagePhoto,
    carFrontPhoto,
    carBackPhoto,
  ];

  static const List<CustomsDocType> optionalOnCreate = [addDoc1, addDoc2];

  static List<CustomsDocType> get creationTypes => [
        ...requiredOnCreate,
        ...optionalOnCreate,
      ];

  static const List<CustomsDocType> signingBaseTypes = [
    recyclingFeeCalc,
    kuts,
    explanatoryNote,
    customsRepAgreement,
    fundsTransferApplication,
    passportNotarizedCopy,
    receipt,
    additionalAgreement,
    tripartiteAgreement,
    quadripartiteAgreement,
    contract,
  ];

  static const Set<CustomsDocType> clientSignOnlyTypes = {
    fundsTransferApplication,
    passportNotarizedCopy,
  };

  static const List<CustomsDocType> paymentTypes = [
    paymentRecyclingFee,
    paymentRecyclingFeeReceipt,
    paymentCustomsDuty,
    paymentCustomsDutyReceipt,
  ];

  static const List<CustomsDocType> transitArchiveTypes = [
    transitArchive,
    transitArchivePhoto,
    transitArchiveVideo,
  ];

  static const List<CustomsDocType> finalTypes = [epts, sbkts, tpo, ptd];

  static String normalizeCode(String? raw) => (raw ?? '').trim();

  /// Базовый тип без суффикса `_sign`.
  static CustomsDocType? tryParse(String? raw) {
    final parsed = parseWithSign(raw);
    return parsed.$1;
  }

  /// `(тип, подписанная версия)`.
  static (CustomsDocType? type, bool isSigned) parseWithSign(String? raw) {
    var code = normalizeCode(raw);
    if (code.isEmpty) return (null, false);
    var signed = false;
    if (code.endsWith('_sign')) {
      signed = true;
      code = code.substring(0, code.length - 5);
    }
    return (_byCode[code], signed);
  }

  String get signedApiCode => '${apiCode}_sign';

  bool get isClientSignOnly => clientSignOnlyTypes.contains(this);

  bool get isTransitArchive =>
      transitArchiveTypes.contains(this) || apiCode.startsWith('transit_archive_');

  bool get isFinal => finalTypes.contains(this);

  bool get isPayment => paymentTypes.contains(this);

  bool get isCreation => creationTypes.contains(this);

  bool get isSigningBase => signingBaseTypes.contains(this);
}
