import 'package:equatable/equatable.dart';
import 'package:import_service_app/domain/entities/customs_request_file.dart';
import 'package:import_service_app/domain/entities/delivered_vehicle_document.dart';
import 'package:import_service_app/domain/entities/request_status.dart';
import 'package:import_service_app/domain/entities/vehicle_finance_item.dart';

/// Контракт заявки: [api-app.md] (camelCase). Список/деталка; `files` только в деталке.
final class CarListItem extends Equatable {
  const CarListItem({
    required this.id,
    required this.ownerFullName,
    required this.carMake,
    required this.carModel,
    required this.vin,
    required this.status,
    this.legalEntityName,
    this.legalEmail,
    this.legalPhone,
    this.individualFullName,
    this.individualPhone,
    this.individualSnils,
    this.hasSunroof,
    this.hasAllWheelDrive,
    this.importedLast12Months,
    this.ownsOtherCars,
    this.commentText,
    this.engineSpec,
    this.engineVolume,
    this.statusSinceDateLabel,
    this.statusSubType,
    this.external1cId,
    this.managerExternal1cId,
    this.createdAt,
    this.updatedAt,
    this.financeItems = const [],
    this.vehiclePhotoUrls = const [],
    this.deliveredDocuments = const [],
    this.files = const [],
  });

  final String id;
  final String ownerFullName;
  final String carMake;
  final String carModel;
  final String vin;
  final RequestStatus status;

  final String? legalEntityName;
  final String? legalEmail;
  final String? legalPhone;
  final String? individualFullName;
  final String? individualPhone;
  final String? individualSnils;
  final bool? hasSunroof;
  final bool? hasAllWheelDrive;
  final bool? importedLast12Months;
  final bool? ownsOtherCars;
  final String? commentText;

  final String? engineSpec;
  final String? engineVolume;
  final String? statusSinceDateLabel;
  final String? statusSubType;
  final String? external1cId;
  final String? managerExternal1cId;
  final String? createdAt;
  final String? updatedAt;

  final List<VehicleFinanceItem> financeItems;
  final List<String> vehiclePhotoUrls;
  final List<DeliveredVehicleDocument> deliveredDocuments;
  final List<CustomsRequestFile> files;

  String get displayCarLine {
    final a = carMake.trim();
    final b = carModel.trim();
    if (a.isEmpty && b.isEmpty) {
      return '—';
    }
    if (a.isEmpty) {
      return b;
    }
    if (b.isEmpty) {
      return a;
    }
    return '$a $b';
  }

  factory CarListItem.fromJson(Map<String, dynamic> json) {
    final rawNewFin = json['financeItems'] as List<dynamic>?;
    final rawOldFin = json['detailFinanceLines'] as List<dynamic>?;
    final fin = (rawNewFin ?? rawOldFin) != null
        ? (rawNewFin ?? rawOldFin)!
            .whereType<Map<String, dynamic>>()
            .map(VehicleFinanceItem.fromJson)
            .toList()
        : const <VehicleFinanceItem>[];

    final vUrls = json['vehiclePhotoUrls'] as List<dynamic>?;
    final dUrls = json['detailPhotoUrls'] as List<dynamic>?;
    final rawUrls = vUrls ?? dUrls;
    final detailUrls = rawUrls is List<dynamic>
        ? rawUrls.map((e) => e.toString()).where((e) => e.isNotEmpty).toList()
        : const <String>[];

    final rawDel = json['deliveredDocuments'] as List<dynamic>?;
    final delivered = rawDel is List<dynamic>
        ? rawDel.whereType<Map<String, dynamic>>().map(DeliveredVehicleDocument.fromJson).toList()
        : const <DeliveredVehicleDocument>[];

    final rawFiles = json['files'] as List<dynamic>?;
    final fileList = rawFiles is List<dynamic>
        ? rawFiles.whereType<Map<String, dynamic>>().map(CustomsRequestFile.fromJson).toList()
        : const <CustomsRequestFile>[];

    final idRaw = json['id'];
    final (mk, mo) = _readMakeModel(json);
    return CarListItem(
      id: idRaw == null ? '' : idRaw.toString(),
      ownerFullName: (json['ownerFullName'] as String?)?.trim() ?? '',
      carMake: mk,
      carModel: mo,
      vin: _readVinField(json),
      status: RequestStatus.fromApiValue(json['status'] as String?),
      legalEntityName: json['legalEntityName'] as String? ?? json['legal_entity_name'] as String?,
      legalEmail: json['legalEmail'] as String? ?? json['legal_email'] as String?,
      legalPhone: json['legalPhone'] as String? ?? json['legal_phone'] as String?,
      individualFullName: json['individualFullName'] as String? ?? json['individual_full_name'] as String?,
      individualPhone: json['individualPhone'] as String? ?? json['individual_phone'] as String?,
      individualSnils: json['individualSnils'] as String? ?? json['individual_snils'] as String?,
      hasSunroof: _readBool(json, 'hasSunroof', 'has_sunroof'),
      hasAllWheelDrive: _readBool(json, 'hasAllWheelDrive', 'has_all_wheel_drive'),
      importedLast12Months: _readBool(json, 'importedLast12Months', 'imported_last_12_months'),
      ownsOtherCars: _readBool(json, 'ownsOtherCars', 'owns_other_cars'),
      commentText: json['commentText'] as String? ?? json['comment_text'] as String?,
      engineSpec: json['engineSpec'] as String? ?? json['engine_spec'] as String?,
      engineVolume: json['engineVolume'] as String? ?? json['engine_volume'] as String?,
      statusSinceDateLabel: json['statusSinceDateLabel'] as String? ?? json['status_since_date_label'] as String?,
      statusSubType: _readStatusSubType(json),
      external1cId: _readId(json, 'external1cId', 'external_1c_id'),
      managerExternal1cId: _readId(json, 'managerExternal1cId', 'manager_external_1c_id'),
      createdAt: json['createdAt'] as String? ?? json['created_at'] as String?,
      updatedAt: json['updatedAt'] as String? ?? json['updated_at'] as String?,
      financeItems: fin,
      vehiclePhotoUrls: detailUrls,
      deliveredDocuments: delivered,
      files: fileList,
    );
  }

  static String? _readId(Map<String, dynamic> j, String a, String b) {
    return (j[a] ?? j[b])?.toString();
  }

  static bool? _readBool(Map<String, dynamic> j, String camel, String snake) {
    if (j.containsKey(camel)) {
      return j[camel] as bool?;
    }
    if (j.containsKey(snake)) {
      return j[snake] as bool?;
    }
    return null;
  }

  static String? _readStatusSubType(Map<String, dynamic> json) {
    final s = (json['statusSubType'] as String? ?? json['status_sub_type'] as String?)?.trim() ?? '';
    if (s.isNotEmpty) {
      return s;
    }
    final old = (json['statusDetailChipI18nKey'] as String?)?.trim() ?? '';
    if (old == 'requestDetailTransitSubStatusLoading') {
      return 'in_transit_loading';
    }
    if (old == 'requestDetailDeliveredSubStatusSw') {
      return 'delivered_temporary_storage';
    }
    if (old.isNotEmpty) {
      return old;
    }
    return null;
  }

  static (String, String) _readMakeModel(Map<String, dynamic> json) {
    var m = (json['carMake'] as String? ?? json['car_make'] as String?)?.trim() ?? '';
    var o = (json['carModel'] as String? ?? json['car_model'] as String?)?.trim() ?? '';
    final legacy = (json['model'] as String?)?.trim() ?? '';
    if (m.isEmpty && o.isEmpty && legacy.isNotEmpty) {
      o = legacy;
    }
    return (m, o);
  }

  static String _readVinField(Map<String, dynamic> json) {
    final a = (json['vin'] as String?)?.trim() ?? '';
    if (a.isNotEmpty) {
      return a;
    }
    final b = (json['vinFull'] as String?)?.trim() ?? '';
    if (b.isNotEmpty) {
      return b;
    }
    return '';
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'ownerFullName': ownerFullName,
        'carMake': carMake,
        'carModel': carModel,
        'vin': vin,
        'status': status.apiValue,
        if (legalEntityName != null) 'legalEntityName': legalEntityName,
        if (legalEmail != null) 'legalEmail': legalEmail,
        if (legalPhone != null) 'legalPhone': legalPhone,
        if (individualFullName != null) 'individualFullName': individualFullName,
        if (individualPhone != null) 'individualPhone': individualPhone,
        if (individualSnils != null) 'individualSnils': individualSnils,
        if (hasSunroof != null) 'hasSunroof': hasSunroof,
        if (hasAllWheelDrive != null) 'hasAllWheelDrive': hasAllWheelDrive,
        if (importedLast12Months != null) 'importedLast12Months': importedLast12Months,
        if (ownsOtherCars != null) 'ownsOtherCars': ownsOtherCars,
        if (commentText != null) 'commentText': commentText,
        'engineSpec': engineSpec,
        'engineVolume': engineVolume,
        'statusSinceDateLabel': statusSinceDateLabel,
        'statusSubType': statusSubType,
        if (external1cId != null) 'external1cId': external1cId,
        if (managerExternal1cId != null) 'managerExternal1cId': managerExternal1cId,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
        'financeItems': financeItems.map((e) => e.toJson()).toList(),
        'vehiclePhotoUrls': vehiclePhotoUrls,
        'deliveredDocuments': deliveredDocuments.map((e) => e.toJson()).toList(),
        'files': files.map((e) => e.toJson()).toList(),
      };

  @override
  List<Object?> get props => [
        id,
        ownerFullName,
        carMake,
        carModel,
        vin,
        status,
        legalEntityName,
        legalEmail,
        legalPhone,
        individualFullName,
        individualPhone,
        individualSnils,
        hasSunroof,
        hasAllWheelDrive,
        importedLast12Months,
        ownsOtherCars,
        commentText,
        engineSpec,
        engineVolume,
        statusSinceDateLabel,
        statusSubType,
        external1cId,
        managerExternal1cId,
        createdAt,
        updatedAt,
        financeItems,
        vehiclePhotoUrls,
        deliveredDocuments,
        files,
      ];
}
