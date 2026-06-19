import 'package:flutter/material.dart';
import 'package:import_service_app/core/i18n/json_strings_service.dart';
import 'package:import_service_app/domain/entities/customs_doc_type.dart';
import 'package:import_service_app/domain/entities/customs_request_file.dart';
import 'package:import_service_app/domain/services/request_files_grouper.dart';
import 'package:import_service_app/presentation/helpers/request_file_uploaded_indicator.dart';
import 'package:import_service_app/presentation/widgets/requests/request_detail_doc_upload_group.dart';

typedef RequestDetailFileRowBuilder = Widget Function(
  CustomsRequestFile file, {
  required bool highlight,
  String? badge,
  bool embedded,
});

/// Один блок «квитанция + чек + загрузить» — тот же паттерн, что «На подпись».
void addPaymentPairGroups({
  required List<Widget> out,
  required List<CustomsRequestFile> allFiles,
  required RequestDetailFileRowBuilder buildFileRow,
  required JsonStringsService strings,
  required bool Function(CustomsRequestFile) isHighlighted,
  required void Function(String docType)? onUploadDocType,
  required String? uploadingDocType,
  required String? uploadReceiptLabelOverride,
}) {
  if (onUploadDocType == null) {
    for (final pair in kPaymentFeeReceiptPairs) {
      _appendStandalonePaymentFiles(
        out: out,
        allFiles: allFiles,
        fee: pair.$1,
        receipt: pair.$2,
        buildFileRow: buildFileRow,
        isHighlighted: isHighlighted,
        strings: strings,
      );
    }
    return;
  }

  for (final pair in kPaymentFeeReceiptPairs) {
    final feeType = pair.$1;
    final receiptType = pair.$2;
    final fee = findFileByDocType(allFiles, feeType);
    final receipt = findFileByDocType(allFiles, receiptType);
    if (fee == null && receipt == null) continue;

    final receiptCode = receiptType.apiCode;
    final hasReceipt = receipt != null;
    final needsReceipt = fee != null && !hasReceipt;
    final highlight = (fee != null && paymentFileNeedsReceiptHighlight(fee, allFiles)) ||
        (fee != null && isHighlighted(fee)) ||
        (receipt != null && isHighlighted(receipt));

    final uploadLabel = paymentReceiptUploadLabel(
      hasReceipt: hasReceipt,
      uploadAgain: strings.requestDetailUploadReceiptAgain,
      uploadFirst: uploadReceiptLabelOverride ?? strings.requestDetailUploadReceipt,
    );

    final groupChildren = <Widget>[];
    if (fee != null) {
      groupChildren.add(
        buildFileRow(
          fee,
          highlight: false,
          embedded: true,
          badge: needsReceipt ? strings.requestHintUploadReceiptShort : null,
        ),
      );
    }
    if (receipt != null) {
      groupChildren.add(
        buildFileRow(
          receipt,
          highlight: false,
          embedded: true,
        ),
      );
    }

    if (groupChildren.isEmpty) continue;

    final canUpload = fee != null;
    out.add(
      RequestDetailDocUploadGroup(
        highlight: highlight,
        uploadLabel: canUpload ? uploadLabel : null,
        uploadBusy: uploadingDocType == receiptCode,
        onUpload: canUpload ? () => onUploadDocType(receiptCode) : null,
        children: groupChildren,
      ),
    );
  }
}

void _appendStandalonePaymentFiles({
  required List<Widget> out,
  required List<CustomsRequestFile> allFiles,
  required CustomsDocType fee,
  required CustomsDocType receipt,
  required RequestDetailFileRowBuilder buildFileRow,
  required bool Function(CustomsRequestFile) isHighlighted,
  required JsonStringsService strings,
}) {
  final feeFile = findFileByDocType(allFiles, fee);
  final receiptFile = findFileByDocType(allFiles, receipt);
  if (feeFile != null) {
    out.add(
      buildFileRow(
        feeFile,
        highlight: paymentFileNeedsReceiptHighlight(feeFile, allFiles) ||
            isHighlighted(feeFile),
        embedded: false,
        badge: paymentFileNeedsReceiptHighlight(feeFile, allFiles)
            ? strings.requestHintUploadReceiptShort
            : null,
      ),
    );
  }
  if (receiptFile != null) {
    out.add(
      buildFileRow(
        receiptFile,
        highlight: isHighlighted(receiptFile),
        embedded: false,
      ),
    );
  }
}
