import 'package:equatable/equatable.dart';
import 'package:import_service_app/domain/entities/customs_request_file.dart';
import 'package:import_service_app/domain/entities/delivered_vehicle_document.dart';
import 'package:import_service_app/domain/entities/request_status.dart';
import 'package:import_service_app/domain/entities/request_status_sub_type.dart';
import 'package:import_service_app/domain/entities/vehicle_finance_item.dart';

/// Контракт заявки v2: [contract-files-v2.md], [api-app.md] (camelCase).
final class CarListItem extends Equatable {
  const CarListItem({
    required this.id,
    required this.ownerFullName,
    required this.carMake,
    required this.carModel,
    required this.vin,
    required this.status,
    this.legalEntityName,
    this.legalInn,
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
    this.statusSubTypeDateTime,
    this.statusSubType,
    this.external1cId,
    this.managerExternal1cId,
    this.managerFullName,
    this.dealType,
    this.advancePayment,
    this.actualPayment,
    this.refundAmount,
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
  final String? legalInn;
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
  /// ISO 8601 — дата подстатуса для UI.
  final String? statusSubTypeDateTime;
  final String? statusSubType;
  final String? external1cId;
  final String? managerExternal1cId;
  final String? managerFullName;
  final String? dealType;

  /// Аванс / факт / к возврату — строки в рублях (API v2).
  final String? advancePayment;
  final String? actualPayment;
  final String? refundAmount;

  final String? createdAt;
  final String? updatedAt;

  /// Только демо-seed до полной миграции UI; с API не приходит.
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

  CustomsRequestFile? fileByDocType(String docType) {
    final code = docType.trim().toLowerCase();
    if (code.isEmpty) return null;
    for (final f in files) {
      final dt = (f.docType ?? '').trim().toLowerCase();
      if (dt == code) return f;
    }
    return null;
  }

  factory CarListItem.fromJson(Map<String, dynamic> json) {
    final rawFiles = json['files'] as List<dynamic>?;
    final fileList = rawFiles is List<dynamic>
        ? rawFiles.whereType<Map<String, dynamic>>().map(CustomsRequestFile.fromJson).toList()
        : const <CustomsRequestFile>[];

    final idRaw = json['id'];
    final (mk, mo) = _readMakeModel(json);
    final statusSubType = _readStatusSubType(json);
    return CarListItem(
      id: idRaw == null ? '' : idRaw.toString(),
      ownerFullName: (json['ownerFullName'] as String?)?.trim() ?? '',
      carMake: mk,
      carModel: mo,
      vin: _readVinField(json),
      status: _readStatus(json, statusSubType),
      legalEntityName: json['legalEntityName'] as String? ?? json['legal_entity_name'] as String?,
      legalInn: _readTrimmedString(json, 'legalInn', 'legal_inn') ??
          _readTrimmedString(json, 'inn', 'inn'),
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
      statusSubTypeDateTime: _readTrimmedString(
        json,
        'statusSubTypeDateTime',
        'status_sub_type_date_time',
      ),
      statusSubType: statusSubType,
      external1cId: _readId(json, 'external1cId', 'external_1c_id'),
      managerExternal1cId: _readId(json, 'managerExternal1cId', 'manager_external_1c_id'),
      managerFullName: _readTrimmedString(json, 'managerFullName', 'manager_full_name'),
      dealType: _readTrimmedString(json, 'dealType', 'deal_type'),
      advancePayment: _readAmountString(json, 'advancePayment', 'advance_payment'),
      actualPayment: _readAmountString(json, 'actualPayment', 'actual_payment'),
      refundAmount: _readAmountString(json, 'refundAmount', 'refund_amount'),
      createdAt: json['createdAt'] as String? ?? json['created_at'] as String?,
      updatedAt: json['updatedAt'] as String? ?? json['updated_at'] as String?,
      files: fileList,
    );
  }

  static String? _readAmountString(Map<String, dynamic> j, String camel, String snake) {
    final raw = j[camel] ?? j[snake];
    if (raw == null) return null;
    final s = raw.toString().trim();
    return s.isEmpty ? null : s;
  }

  static String? _readId(Map<String, dynamic> j, String a, String b) {
    return (j[a] ?? j[b])?.toString();
  }

  static String? _readTrimmedString(Map<String, dynamic> j, String a, String b) {
    final raw = (j[a] ?? j[b])?.toString().trim() ?? '';
    return raw.isEmpty ? null : raw;
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

  static RequestStatus _readStatus(Map<String, dynamic> json, String? statusSubType) {
    final raw = (json['status'] as String?)?.trim();
    if (raw != null && raw.isNotEmpty) {
      return RequestStatus.fromApiValue(raw);
    }
    final sub = RequestStatusSubType.tryParse(statusSubType);
    if (sub != null) {
      return sub.typicalStatus;
    }
    return RequestStatus.newRequest;
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

  CarListItem copyWith({
    String? id,
    String? ownerFullName,
    String? carMake,
    String? carModel,
    String? vin,
    RequestStatus? status,
    String? legalEntityName,
    String? legalInn,
    String? legalEmail,
    String? legalPhone,
    String? individualFullName,
    String? individualPhone,
    String? individualSnils,
    bool? hasSunroof,
    bool? hasAllWheelDrive,
    bool? importedLast12Months,
    bool? ownsOtherCars,
    String? commentText,
    String? engineSpec,
    String? engineVolume,
    String? statusSubTypeDateTime,
    String? statusSubType,
    String? external1cId,
    String? managerExternal1cId,
    String? managerFullName,
    String? dealType,
    String? advancePayment,
    String? actualPayment,
    String? refundAmount,
    String? createdAt,
    String? updatedAt,
    List<VehicleFinanceItem>? financeItems,
    List<String>? vehiclePhotoUrls,
    List<DeliveredVehicleDocument>? deliveredDocuments,
    List<CustomsRequestFile>? files,
  }) {
    return CarListItem(
      id: id ?? this.id,
      ownerFullName: ownerFullName ?? this.ownerFullName,
      carMake: carMake ?? this.carMake,
      carModel: carModel ?? this.carModel,
      vin: vin ?? this.vin,
      status: status ?? this.status,
      legalEntityName: legalEntityName ?? this.legalEntityName,
      legalInn: legalInn ?? this.legalInn,
      legalEmail: legalEmail ?? this.legalEmail,
      legalPhone: legalPhone ?? this.legalPhone,
      individualFullName: individualFullName ?? this.individualFullName,
      individualPhone: individualPhone ?? this.individualPhone,
      individualSnils: individualSnils ?? this.individualSnils,
      hasSunroof: hasSunroof ?? this.hasSunroof,
      hasAllWheelDrive: hasAllWheelDrive ?? this.hasAllWheelDrive,
      importedLast12Months: importedLast12Months ?? this.importedLast12Months,
      ownsOtherCars: ownsOtherCars ?? this.ownsOtherCars,
      commentText: commentText ?? this.commentText,
      engineSpec: engineSpec ?? this.engineSpec,
      engineVolume: engineVolume ?? this.engineVolume,
      statusSubTypeDateTime: statusSubTypeDateTime ?? this.statusSubTypeDateTime,
      statusSubType: statusSubType ?? this.statusSubType,
      external1cId: external1cId ?? this.external1cId,
      managerExternal1cId: managerExternal1cId ?? this.managerExternal1cId,
      managerFullName: managerFullName ?? this.managerFullName,
      dealType: dealType ?? this.dealType,
      advancePayment: advancePayment ?? this.advancePayment,
      actualPayment: actualPayment ?? this.actualPayment,
      refundAmount: refundAmount ?? this.refundAmount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      financeItems: financeItems ?? this.financeItems,
      vehiclePhotoUrls: vehiclePhotoUrls ?? this.vehiclePhotoUrls,
      deliveredDocuments: deliveredDocuments ?? this.deliveredDocuments,
      files: files ?? this.files,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'ownerFullName': ownerFullName,
        'carMake': carMake,
        'carModel': carModel,
        'vin': vin,
        'status': status.apiValue,
        if (legalEntityName != null) 'legalEntityName': legalEntityName,
        if (legalInn != null) 'legalInn': legalInn,
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
        if (statusSubTypeDateTime != null) 'statusSubTypeDateTime': statusSubTypeDateTime,
        'statusSubType': statusSubType,
        if (external1cId != null) 'external1cId': external1cId,
        if (managerExternal1cId != null) 'managerExternal1cId': managerExternal1cId,
        if (managerFullName != null) 'managerFullName': managerFullName,
        if (dealType != null) 'dealType': dealType,
        if (advancePayment != null) 'advancePayment': advancePayment,
        if (actualPayment != null) 'actualPayment': actualPayment,
        if (refundAmount != null) 'refundAmount': refundAmount,
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
        legalInn,
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
        statusSubTypeDateTime,
        statusSubType,
        external1cId,
        managerExternal1cId,
        managerFullName,
        dealType,
        advancePayment,
        actualPayment,
        refundAmount,
        createdAt,
        updatedAt,
        financeItems,
        vehiclePhotoUrls,
        deliveredDocuments,
        files,
      ];
}
