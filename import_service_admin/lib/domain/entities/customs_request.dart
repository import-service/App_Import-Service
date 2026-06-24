import 'package:equatable/equatable.dart';
import 'package:import_service_admin/domain/entities/customs_request_delivered_document.dart';
import 'package:import_service_admin/domain/entities/customs_request_file.dart';
import 'package:import_service_admin/domain/entities/customs_request_finance_item.dart';

class CustomsRequest extends Equatable {
  const CustomsRequest({
    required this.id,
    required this.ownerFullName,
    required this.carMake,
    required this.carModel,
    required this.vin,
    required this.status,
    required this.legalEntityName,
    required this.legalEmail,
    required this.legalPhone,
    required this.individualFullName,
    required this.individualPhone,
    required this.individualSnils,
    required this.hasSunroof,
    required this.hasAllWheelDrive,
    required this.importedLast12Months,
    required this.ownsOtherCars,
    required this.isTest,
    this.statusSinceDateLabel,
    this.statusSubType,
    this.statusSubTypeDateTime,
    this.engineSpec,
    this.engineVolume,
    this.dealType,
    this.commentText,
    this.managerFullName,
    this.managerExternal1cId,
    this.external1cId,
    this.oneCUpdatePending = false,
    this.oneCUpdateLastAttemptAt,
    this.oneCUpdateLastError,
    this.oneCUpdateHoursPending,
    this.oneCCreatePending = false,
    this.oneCCreateLastAttemptAt,
    this.oneCCreateLastError,
    this.oneCCreateHoursPending,
    this.oneCOutboundStaleOver24h = false,
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
  final String status;
  final String? statusSinceDateLabel;
  final String? statusSubType;
  final String? statusSubTypeDateTime;
  final String? engineSpec;
  final String? engineVolume;
  final String? dealType;
  final String legalEntityName;
  final String legalEmail;
  final String legalPhone;
  final String individualFullName;
  final String individualPhone;
  final String individualSnils;
  final bool hasSunroof;
  final bool hasAllWheelDrive;
  final bool importedLast12Months;
  final bool ownsOtherCars;
  final String? commentText;
  final bool isTest;
  final String? managerFullName;
  final String? managerExternal1cId;
  final String? external1cId;
  final bool oneCUpdatePending;
  final String? oneCUpdateLastAttemptAt;
  final Map<String, dynamic>? oneCUpdateLastError;
  final int? oneCUpdateHoursPending;
  final bool oneCCreatePending;
  final String? oneCCreateLastAttemptAt;
  final Map<String, dynamic>? oneCCreateLastError;
  final int? oneCCreateHoursPending;
  final bool oneCOutboundStaleOver24h;
  final String? createdAt;
  final String? updatedAt;
  final List<CustomsRequestFinanceItem> financeItems;
  final List<String> vehiclePhotoUrls;
  final List<CustomsRequestDeliveredDocument> deliveredDocuments;
  final List<CustomsRequestFile> files;

  String get carTitle => displayCarLine;

  String get displayCarLine {
    final a = carMake.trim();
    final b = carModel.trim();
    if (a.isEmpty && b.isEmpty) return '—';
    if (a.isEmpty) return b;
    if (b.isEmpty) return a;
    return '$a $b';
  }

  String get organizationLine {
    final o = legalEntityName.trim();
    return o.isNotEmpty ? o : '—';
  }

  /// Превью в списке: первое фото авто или car_front из files (если есть).
  String? get listThumbnailUrl {
    if (vehiclePhotoUrls.isNotEmpty) {
      return vehiclePhotoUrls.first;
    }
    for (final f in files) {
      final t = f.docType.trim();
      if (t == 'car_front_photo' || t == 'car_back_photo') {
        return f.displayUrl;
      }
    }
    return null;
  }

  bool get canSendTo1C =>
      status == 'new' &&
      (external1cId == null || external1cId!.trim().isEmpty);

  bool get canResendUpdateTo1C =>
      oneCUpdatePending &&
      external1cId != null &&
      external1cId!.trim().isNotEmpty;

  bool get hasOutboundPending => oneCCreatePending || oneCUpdatePending;

  int? get outboundHoursPending {
    final c = oneCCreateHoursPending;
    final u = oneCUpdateHoursPending;
    if (c == null && u == null) return null;
    if (c == null) return u;
    if (u == null) return c;
    return c > u ? c : u;
  }

  @override
  List<Object?> get props =>
      [id, status, oneCUpdatePending, oneCCreatePending, updatedAt];
}
