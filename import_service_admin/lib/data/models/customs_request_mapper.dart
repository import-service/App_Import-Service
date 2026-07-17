import 'package:import_service_admin/domain/entities/customs_request.dart';
import 'package:import_service_admin/domain/entities/customs_request_delivered_document.dart';
import 'package:import_service_admin/domain/entities/customs_request_file.dart';
import 'package:import_service_admin/domain/entities/customs_request_finance_item.dart';

abstract final class CustomsRequestMapper {
  static CustomsRequest fromJson(Map<String, dynamic> json) {
    return CustomsRequest(
      id: json['id']?.toString() ?? '',
      ownerFullName: json['ownerFullName'] as String? ?? '',
      carMake: json['carMake'] as String? ?? '',
      carModel: json['carModel'] as String? ?? '',
      vin: json['vin'] as String? ?? '',
      status: json['status'] as String? ?? 'new',
      statusSinceDateLabel: json['statusSinceDateLabel'] as String?,
      statusSubType: json['statusSubType'] as String?,
      statusSubTypeDateTime: json['statusSubTypeDateTime'] as String?,
      engineSpec: json['engineSpec'] as String?,
      engineVolume: json['engineVolume'] as String?,
      dealType: json['dealType'] as String?,
      legalEntityName: json['legalEntityName'] as String? ?? '',
      legalEmail: json['legalEmail'] as String? ?? '',
      legalPhone: json['legalPhone'] as String? ?? '',
      individualFullName: json['individualFullName'] as String? ?? '',
      individualPhone: json['individualPhone'] as String? ?? '',
      individualSnils: json['individualSnils'] as String? ?? '',
      hasSunroof: json['hasSunroof'] == true,
      hasAllWheelDrive: json['hasAllWheelDrive'] == true,
      importedLast12Months: json['importedLast12Months'] == true,
      ownsOtherCars: json['ownsOtherCars'] == true,
      commentText: json['commentText'] as String?,
      managerFullName: json['managerFullName'] as String?,
      managerExternal1cId: json['managerExternal1cId'] as String?,
      external1cId: json['external1cId'] as String?,
      oneCUpdatePending: json['oneCUpdatePending'] == true,
      oneCUpdateLastAttemptAt: json['oneCUpdateLastAttemptAt'] as String?,
      oneCUpdateLastError: json['oneCUpdateLastError'] is Map<String, dynamic>
          ? json['oneCUpdateLastError'] as Map<String, dynamic>
          : null,
      oneCUpdateHoursPending: json['oneCUpdateHoursPending'] is int
          ? json['oneCUpdateHoursPending'] as int
          : int.tryParse('${json['oneCUpdateHoursPending']}'),
      oneCCreatePending: json['oneCCreatePending'] == true,
      oneCCreateLastAttemptAt: json['oneCCreateLastAttemptAt'] as String?,
      oneCCreateLastError: json['oneCCreateLastError'] is Map<String, dynamic>
          ? json['oneCCreateLastError'] as Map<String, dynamic>
          : null,
      oneCCreateHoursPending: json['oneCCreateHoursPending'] is int
          ? json['oneCCreateHoursPending'] as int
          : int.tryParse('${json['oneCCreateHoursPending']}'),
      oneCOutboundStaleOver24h: json['oneCOutboundStaleOver24h'] == true,
      createdAt: json['createdAt'] as String?,
      updatedAt: json['updatedAt'] as String?,
      financeItems: _financeItems(json['financeItems']),
      vehiclePhotoUrls: _stringList(json['vehiclePhotoUrls']),
      deliveredDocuments: _deliveredDocs(json['deliveredDocuments']),
      files: _files(json['files']),
    );
  }

  static List<CustomsRequestFinanceItem> _financeItems(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(
          (e) => CustomsRequestFinanceItem(
            lineType: e['lineType'] as String? ?? '',
            title: e['title'] as String?,
            amountText: e['amountText'] as String?,
            paymentQrUrl: e['paymentQrUrl'] as String?,
            receiptUrl: e['receiptUrl'] as String?,
          ),
        )
        .where((e) => e.lineType.isNotEmpty)
        .toList(growable: false);
  }

  static List<String> _stringList(dynamic raw) {
    if (raw is! List) return const [];
    return raw.map((e) => e.toString()).where((s) => s.isNotEmpty).toList();
  }

  static List<CustomsRequestDeliveredDocument> _deliveredDocs(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(
          (e) => CustomsRequestDeliveredDocument(
            title: e['title'] as String? ?? '',
            downloadUrl: e['downloadUrl'] as String? ?? '',
          ),
        )
        .where((e) => e.title.isNotEmpty || e.downloadUrl.isNotEmpty)
        .toList(growable: false);
  }

  static List<CustomsRequestFile> _files(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(
          (e) => CustomsRequestFile(
            id: e['id']?.toString() ?? '',
            docType: e['docType'] as String? ?? '',
            fileName: e['fileName'] as String? ?? '',
            fileUrl: e['fileUrl'] as String? ?? '',
            previewUrl: e['previewUrl'] as String?,
            mimeType: e['mimeType'] as String?,
            fileSizeBytes: e['fileSizeBytes'] is int
                ? e['fileSizeBytes'] as int
                : int.tryParse('${e['fileSizeBytes']}'),
          ),
        )
        .where((e) => e.fileUrl.isNotEmpty)
        .toList(growable: false);
  }
}
