import 'package:import_service_app/data/models/registration_request_model.dart';
import 'package:import_service_app/core/util/single_file_path_list.dart';

final class OwnedVehicleItem {
  const OwnedVehicleItem({required this.name, this.year});

  final String name;
  final int? year;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'name': name,
        if (year != null) 'year': year,
      };

  factory OwnedVehicleItem.fromJson(Map<String, dynamic> json) {
    final yearRaw = json['year'];
    final year = yearRaw is int
        ? yearRaw
        : int.tryParse(yearRaw?.toString().replaceAll(RegExp(r'\D'), '') ?? '');
    return OwnedVehicleItem(
      name: (json['name'] as String?)?.trim() ?? '',
      year: year,
    );
  }
}

final class RequestFormModel {
  static const int trackedFieldCount = 22;

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
    this.previousImportDates = const [],
    this.ownedVehicles = const [],
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
  final List<String> previousImportDates;
  final List<OwnedVehicleItem> ownedVehicles;
  final String comment;

  bool get wasInRussiaLast12Months => previousImportDates.isNotEmpty;
  bool get hasOtherCars =>
      ownedVehicles.any((e) => e.name.trim().isNotEmpty && e.year != null);

  List<OwnedVehicleItem> get ownedVehiclesForApi => ownedVehicles
      .where((e) => e.name.trim().isNotEmpty && e.year != null)
      .toList(growable: false);

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

  static int countFilledFields(RequestFormModel m) {
    var n = 0;
    // Прогресс черновика считаем только по обязательным полям (max = trackedFieldCount).
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
    n += 2;
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
    final datesRaw = json['previousImportDates'] as List<dynamic>? ?? const [];
    final carsRaw = json['ownedVehicles'] as List<dynamic>? ?? const [];
    return RequestFormModel(
      organizationType: OrganizationTypeInn.tryParse(
            json['organizationType'] as String?,
          ) ??
          OrganizationType.ooo,
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
      previousImportDates: datesRaw.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList(),
      ownedVehicles: carsRaw
          .whereType<Map>()
          .map((e) => OwnedVehicleItem.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
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
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'organizationType': switch (organizationType) {
          OrganizationType.ooo => 'ooo',
          OrganizationType.ip => 'ip',
          OrganizationType.person => 'person',
        },
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
        'previousImportDates': previousImportDates,
        'ownedVehicles': ownedVehicles.map((e) => e.toJson()).toList(),
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
