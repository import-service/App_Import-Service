import 'package:import_service_app/core/i18n/json_strings_service.dart';
import 'package:import_service_app/data/local/request_detail_section_prefs.dart';
import 'package:import_service_app/domain/entities/car_list_item.dart';
import 'package:import_service_app/domain/entities/request_status_sub_type.dart';
import 'package:import_service_app/domain/services/request_files_grouper.dart';
import 'package:import_service_app/presentation/helpers/request_status_action_hint.dart';

RequestFilesGrouped groupedFilesForItem(CarListItem item) {
  return groupRequestFiles(
    files: item.files,
    statusSubType: item.statusSubType,
    dealType: item.dealType,
  );
}

bool signingSectionNeedsAction(CarListItem item, RequestFilesGrouped grouped) {
  if (grouped.signingPairs.isEmpty) return false;
  final sub = RequestStatusSubType.tryParse(item.statusSubType);
  final signingStage = sub == RequestStatusSubType.primaryDocumentsSent ||
      sub == RequestStatusSubType.signatureRevisionRequired;
  if (!signingStage) return false;
  return grouped.signingPairs.any(
    (pair) => pair.canUploadSigned && (pair.needsSignature || pair.signed == null),
  );
}

bool paymentSectionNeedsAction(CarListItem item, RequestFilesGrouped grouped) {
  if (grouped.payment.isEmpty) return false;
  return requestNeedsPaymentReceiptAction(item);
}

bool hasPendingClientUploadActions(CarListItem item) {
  final grouped = groupedFilesForItem(item);
  return signingSectionNeedsAction(item, grouped) ||
      paymentSectionNeedsAction(item, grouped);
}

/// Подсказки-действия для красного баннера сверху (только загрузки/подписи).
List<String> requestDetailUrgentActionHints(
  CarListItem item,
  JsonStringsService strings,
) {
  final grouped = groupedFilesForItem(item);
  final hints = <String>[];

  if (signingSectionNeedsAction(item, grouped)) {
    final sub = RequestStatusSubType.tryParse(item.statusSubType);
    if (sub == RequestStatusSubType.signatureRevisionRequired) {
      hints.add(strings.requestHintSignatureRevision);
    } else {
      hints.add(strings.requestHintSignDocuments);
    }
  }

  if (paymentSectionNeedsAction(item, grouped)) {
    hints.add(strings.requestHintUploadReceipt);
  }

  return hints.toSet().toList();
}

String? sectionKeyForUploadedDocType(String docType) {
  final code = docType.trim().toLowerCase();
  if (code.endsWith('_sign')) return RequestDetailSectionKeys.filesSigning;
  if (code.contains('receipt') || code.startsWith('payment_')) {
    return RequestDetailSectionKeys.filesPayment;
  }
  if (code == 'add_doc1' || code == 'add_doc2') {
    return RequestDetailSectionKeys.filesOther;
  }
  if (code.startsWith('car_') ||
      code.startsWith('transit_archive') ||
      code.startsWith('svh_car_photo_') ||
      code.startsWith('svh_car_video_') ||
      code == 'epts' ||
      code == 'sbkts' ||
      code == 'tpo' ||
      code == 'ptd') {
    if (code.startsWith('svh_car_photo_') || code.startsWith('svh_car_video_')) {
      return RequestDetailSectionKeys.filesSvhCarGallery;
    }
    if (code.startsWith('car_')) {
      return RequestDetailSectionKeys.filesCreation;
    }
    return RequestDetailSectionKeys.filesIssueHandover;
  }
  return null;
}
