import 'package:import_service_app/data/models/registration_request_model.dart';
import 'package:import_service_app/core/util/single_file_path_list.dart';

final class RequestFormModel {
  static const int trackedFieldCount = 25;

  const RequestFormModel({
    this.organizationType = OrganizationType.ooo,
    required this.companyName,
    required this.companyInn,
    required this.companyEmail,
    required this.companyPhone,
    required this.personFullName,
    required this.personPhone,
    required this.personSnils,
    required this.carBrand,
    required this.carModel,
    required this.vin,
    required this.hasSunroof,
    required this.hasAllWheelDrive,
    required this.wasInRussiaLast12Months,
    required this.hasOtherCars,
    required this.comment,
    this.passportFrontPaths = const [],
    this.passportAddressPaths = const [],
    this.innPaths = const [],
    this.snilsPaths = const [],
    this.invoicePaths = const [],
    this.contractPaths = const [],
    this.paymentReceiptPaths = const [],
    this.vinPlatePhotoPaths = const [],
    this.odometerPhotoPaths = const [],
    this.carFrontPhotoPaths = const [],
    this.carRearPhotoPaths = const [],
    this.additionalFile1Paths = const [],
    this.additionalFile2Paths = const [],
    this.isTest = true,
  });

  final OrganizationType organizationType;
  final String companyName;
  final String companyInn;
  final String companyEmail;
  final String companyPhone;
  final String personFullName;
  final String personPhone;
  final String personSnils;
  final String carBrand;
  final String carModel;
  final String vin;
  final bool hasSunroof;
  final bool hasAllWheelDrive;
  final bool wasInRussiaLast12Months;
  final bool hasOtherCars;
  final String comment;

  final List<String> passportFrontPaths;
  final List<String> passportAddressPaths;
  final List<String> innPaths;
  final List<String> snilsPaths;
  final List<String> invoicePaths;
  final List<String> contractPaths;
  final List<String> paymentReceiptPaths;
  final List<String> vinPlatePhotoPaths;
  final List<String> odometerPhotoPaths;
  final List<String> carFrontPhotoPaths;
  final List<String> carRearPhotoPaths;
  final List<String> additionalFile1Paths;
  final List<String> additionalFile2Paths;
  /// [api-app.md]: тестовая заявка (`POST /api/customs-requests` → `isTest`).
  final bool isTest;

  static int countFilledFields(RequestFormModel m) {
    var n = 0;
    // Прогресс черновика считаем только по обязательным полям (max = trackedFieldCount = 24).
    if (m.companyName.trim().isNotEmpty) n++;
    if (m.companyInn.trim().isNotEmpty) n++;
    if (m.companyEmail.trim().isNotEmpty) n++;
    if (m.companyPhone.trim().isNotEmpty) n++;
    if (m.personFullName.trim().isNotEmpty) n++;
    if (m.personPhone.trim().isNotEmpty) n++;
    if (m.personSnils.trim().isNotEmpty) n++;
    if (m.carBrand.trim().isNotEmpty) n++;
    if (m.carModel.trim().isNotEmpty) n++;
    if (m.vin.trim().isNotEmpty) n++;
    n += 4;
    if (m.passportFrontPaths.isNotEmpty) n++;
    if (m.passportAddressPaths.isNotEmpty) n++;
    if (m.innPaths.isNotEmpty) n++;
    if (m.snilsPaths.isNotEmpty) n++;
    if (m.invoicePaths.isNotEmpty) n++;
    if (m.contractPaths.isNotEmpty) n++;
    if (m.paymentReceiptPaths.isNotEmpty) n++;
    if (m.vinPlatePhotoPaths.isNotEmpty) n++;
    if (m.odometerPhotoPaths.isNotEmpty) n++;
    if (m.carFrontPhotoPaths.isNotEmpty) n++;
    if (m.carRearPhotoPaths.isNotEmpty) n++;
    return n;
  }

  factory RequestFormModel.fromJson(Map<String, dynamic> json) {
    List<String> readList(String key) => singleFilePathList(
          (json[key] as List<dynamic>? ?? []).map((e) => e.toString()),
        );
    return RequestFormModel(
      organizationType: ((json['organizationType'] as String?) == 'ip')
          ? OrganizationType.ip
          : OrganizationType.ooo,
      companyName: (json['companyName'] as String?) ?? '',
      companyInn: _readCompanyInn(json),
      companyEmail: (json['companyEmail'] as String?) ?? '',
      companyPhone: (json['companyPhone'] as String?) ?? '',
      personFullName: (json['personFullName'] as String?) ?? '',
      personPhone: (json['personPhone'] as String?) ?? '',
      personSnils: (json['personSnils'] as String?) ?? '',
      carBrand: (json['carBrand'] as String?) ?? '',
      carModel: (json['carModel'] as String?) ?? '',
      vin: (json['vin'] as String?) ?? '',
      hasSunroof: (json['hasSunroof'] as bool?) ?? false,
      hasAllWheelDrive: (json['hasAllWheelDrive'] as bool?) ?? false,
      wasInRussiaLast12Months:
          (json['wasInRussiaLast12Months'] as bool?) ?? false,
      hasOtherCars: (json['hasOtherCars'] as bool?) ?? false,
      comment: (json['comment'] as String?) ?? '',
      passportFrontPaths: readList('passportFrontPaths'),
      passportAddressPaths: readList('passportAddressPaths'),
      innPaths: readList('innPaths'),
      snilsPaths: readList('snilsPaths'),
      invoicePaths: readList('invoicePaths'),
      contractPaths: readList('contractPaths'),
      paymentReceiptPaths: readList('paymentReceiptPaths'),
      vinPlatePhotoPaths: readList('vinPlatePhotoPaths'),
      odometerPhotoPaths: readList('odometerPhotoPaths'),
      carFrontPhotoPaths: readList('carFrontPhotoPaths'),
      carRearPhotoPaths: readList('carRearPhotoPaths'),
      additionalFile1Paths: readList('additionalFile1Paths'),
      additionalFile2Paths: readList('additionalFile2Paths'),
      isTest: (json['isTest'] as bool?) ?? true,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'organizationType':
            organizationType == OrganizationType.ip ? 'ip' : 'ooo',
        'companyName': companyName,
        'companyInn': companyInn,
        'companyEmail': companyEmail,
        'companyPhone': companyPhone,
        'personFullName': personFullName,
        'personPhone': personPhone,
        'personSnils': personSnils,
        'carBrand': carBrand,
        'carModel': carModel,
        'vin': vin,
        'hasSunroof': hasSunroof,
        'hasAllWheelDrive': hasAllWheelDrive,
        'wasInRussiaLast12Months': wasInRussiaLast12Months,
        'hasOtherCars': hasOtherCars,
        'comment': comment,
        'passportFrontPaths': passportFrontPaths,
        'passportAddressPaths': passportAddressPaths,
        'innPaths': innPaths,
        'snilsPaths': snilsPaths,
        'invoicePaths': invoicePaths,
        'contractPaths': contractPaths,
        'paymentReceiptPaths': paymentReceiptPaths,
        'vinPlatePhotoPaths': vinPlatePhotoPaths,
        'odometerPhotoPaths': odometerPhotoPaths,
        'carFrontPhotoPaths': carFrontPhotoPaths,
        'carRearPhotoPaths': carRearPhotoPaths,
        'additionalFile1Paths': additionalFile1Paths,
        'additionalFile2Paths': additionalFile2Paths,
        'isTest': isTest,
      };

  static String _readCompanyInn(Map<String, dynamic> json) {
    for (final key in ['companyInn', 'inn', 'legalInn', 'legal_inn']) {
      final raw = json[key];
      if (raw == null) continue;
      final text = raw.toString().trim();
      if (text.isNotEmpty) return text.replaceAll(RegExp(r'\D'), '');
    }
    return '';
  }
}
