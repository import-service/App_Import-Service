import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:import_service_app/core/constants/customs_catalog.dart';
import 'package:import_service_app/core/di/injection_container.dart';
import 'package:import_service_app/core/i18n/json_strings_service.dart';
import 'package:import_service_app/core/themes/app_theme.dart';
import 'package:import_service_app/data/local/request_detail_section_prefs.dart';
import 'package:import_service_app/domain/entities/car_list_item.dart';
import 'package:import_service_app/domain/entities/customs_request_file.dart';
import 'package:import_service_app/domain/entities/delivered_vehicle_document.dart';
import 'package:import_service_app/domain/services/request_files_grouper.dart';
import 'package:import_service_app/presentation/helpers/doc_type_labels.dart';
import 'package:import_service_app/presentation/helpers/request_detail_pending_actions.dart';
import 'package:import_service_app/presentation/helpers/signing_upload_action_label.dart';
import 'package:import_service_app/presentation/widgets/requests/request_detail_collapsible_section.dart';
import 'package:import_service_app/presentation/widgets/requests/request_detail_doc_upload_group.dart';
import 'package:import_service_app/presentation/widgets/requests/request_detail_file_upload_chip.dart';

typedef RequestFileRowBuilder = Widget Function(
  CustomsRequestFile file, {
  required bool highlight,
  String? badge,
  bool embedded,
});

typedef RequestDeliverableRowBuilder = Widget Function(DeliveredVehicleDocument doc);

/// Пять секций документов заявки (концепция §13), сворачиваемые.
class RequestDetailFilesSections extends StatelessWidget {
  const RequestDetailFilesSections({
    super.key,
    required this.requestId,
    required this.item,
    required this.buildFileRow,
    required this.buildDeliverableRow,
    this.onUploadDocType,
    this.uploadingDocType,
    this.uploadSignedLabel,
    this.uploadReceiptLabel,
    this.onTransitPhotoTap,
    this.highlightedDocTypes = const {},
  });

  final String requestId;
  final CarListItem item;
  final RequestFileRowBuilder buildFileRow;
  final RequestDeliverableRowBuilder buildDeliverableRow;
  final void Function(String docType)? onUploadDocType;
  final String? uploadingDocType;
  final String? uploadSignedLabel;
  final String? uploadReceiptLabel;
  final void Function(String url)? onTransitPhotoTap;
  final Set<String> highlightedDocTypes;

  bool _isHighlighted(CustomsRequestFile file) {
    final code = normalizeDocType(file.docType ?? '');
    if (code.isEmpty) return false;
    return highlightedDocTypes.contains(code);
  }

  @override
  Widget build(BuildContext context) {
    final grouped = groupedFilesForItem(item);
    final s = sl<JsonStringsService>();
    final theme = Theme.of(context);
    final children = <Widget>[];

    void addSection({
      required String sectionKey,
      required String title,
      required bool needsAction,
      required List<Widget> rows,
    }) {
      if (rows.isEmpty) return;
      if (children.isNotEmpty) children.add(const Gap(16));
      children.add(
        RequestDetailCollapsibleSection(
          requestId: requestId,
          sectionKey: sectionKey,
          title: title,
          needsAction: needsAction,
          children: rows,
        ),
      );
    }

    addSection(
      sectionKey: RequestDetailSectionKeys.filesCreation,
      title: s.requestFilesSectionCreation,
      needsAction: false,
      rows: grouped.creation
          .map((f) => buildFileRow(f, highlight: _isHighlighted(f), embedded: false))
          .toList(),
    );

    final signingRows = <Widget>[];
    for (final pair in grouped.signingPairs) {
      final targetType = pair.baseDocType.signedApiCode;
      final canUpload = pair.canUploadSigned && onUploadDocType != null;
      final hasSigned = pair.signed != null;
      final hasOriginal = pair.original != null;
      final uploadLabel = signingUploadActionLabel(
        baseDocType: pair.baseDocType,
        strings: s,
        hasSignedFile: hasSigned,
      );
      void onUpload() => onUploadDocType!(targetType);
      final uploadBusy = uploadingDocType == targetType;

      if (hasOriginal && hasSigned && canUpload) {
        signingRows.add(
          RequestDetailDocUploadGroup(
            highlight: pair.highlightSignature ||
                _isHighlighted(pair.original!) ||
                _isHighlighted(pair.signed!),
            uploadLabel: uploadLabel,
            uploadBusy: uploadBusy,
            onUpload: onUpload,
            children: [
              buildFileRow(
                pair.original!,
                highlight: false,
                embedded: true,
                badge: pair.needsSignature ? s.requestFileNeedsSignature : null,
              ),
              buildFileRow(
                pair.signed!,
                highlight: false,
                embedded: true,
              ),
            ],
          ),
        );
        continue;
      }

      if (hasOriginal && hasSigned) {
        signingRows.add(
          RequestDetailDocUploadGroup(
            highlight: pair.highlightSignature ||
                _isHighlighted(pair.original!) ||
                _isHighlighted(pair.signed!),
            children: [
              buildFileRow(
                pair.original!,
                highlight: false,
                embedded: true,
                badge: pair.needsSignature ? s.requestFileNeedsSignature : null,
              ),
              buildFileRow(
                pair.signed!,
                highlight: false,
                embedded: true,
              ),
            ],
          ),
        );
        continue;
      }

      if (hasOriginal && !hasSigned && canUpload) {
        signingRows.add(
          RequestDetailDocUploadGroup(
            highlight: pair.highlightSignature || _isHighlighted(pair.original!),
            uploadLabel: uploadLabel,
            uploadBusy: uploadBusy,
            onUpload: onUpload,
            children: [
              buildFileRow(
                pair.original!,
                highlight: false,
                embedded: true,
                badge: pair.needsSignature ? s.requestFileNeedsSignature : null,
              ),
            ],
          ),
        );
        continue;
      }

      if (!hasOriginal && hasSigned && canUpload) {
        signingRows.add(
          RequestDetailDocUploadGroup(
            highlight: pair.highlightSignature || _isHighlighted(pair.signed!),
            uploadLabel: uploadLabel,
            uploadBusy: uploadBusy,
            onUpload: onUpload,
            children: [
              buildFileRow(
                pair.signed!,
                highlight: false,
                embedded: true,
              ),
            ],
          ),
        );
        continue;
      }

      if (!hasOriginal && !hasSigned && pair.needsSignature && canUpload) {
        signingRows.add(
          RequestDetailDocUploadGroup(
            highlight: true,
            uploadLabel: uploadLabel,
            uploadBusy: uploadBusy,
            onUpload: onUpload,
            children: [
              _missingSignPlaceholder(
                theme: theme,
                label: docTypeLabelForType(pair.baseDocType, s),
                hint: s.requestFileNeedsSignature,
                embedded: true,
              ),
            ],
          ),
        );
        continue;
      }

      if (hasOriginal) {
        signingRows.add(
          buildFileRow(
            pair.original!,
            highlight: pair.highlightSignature || _isHighlighted(pair.original!),
            embedded: false,
            badge: pair.needsSignature ? s.requestFileNeedsSignature : null,
          ),
        );
      }
      if (hasSigned) {
        signingRows.add(
          buildFileRow(
            pair.signed!,
            highlight: _isHighlighted(pair.signed!),
            embedded: false,
          ),
        );
      } else if (pair.needsSignature && !hasOriginal) {
        signingRows.add(
          _missingSignPlaceholder(
            theme: theme,
            label: docTypeLabelForType(pair.baseDocType, s),
            hint: s.requestFileNeedsSignature,
          ),
        );
      }
    }

    addSection(
      sectionKey: RequestDetailSectionKeys.filesSigning,
      title: s.requestFilesSectionSigning,
      needsAction: signingSectionNeedsAction(item, grouped),
      rows: signingRows,
    );

    final paymentRows = <Widget>[];
    for (final f in grouped.payment) {
      final highlight =
          paymentFileNeedsReceiptHighlight(f, item.files) || _isHighlighted(f);
      paymentRows.add(
        buildFileRow(
          f,
          highlight: highlight,
          embedded: false,
          badge: highlight ? s.requestHintUploadReceiptShort : null,
        ),
      );
      final receiptType = receiptDocTypeForPaymentFee(f.docType);
      if (receiptType == null || onUploadDocType == null) continue;
      final feeType = CustomsDocType.tryParse(f.docType);
      if (feeType != CustomsDocType.paymentRecyclingFee &&
          feeType != CustomsDocType.paymentCustomsDuty) {
        continue;
      }
      final receiptEnum = CustomsDocType.tryParse(receiptType);
      final hasReceipt = receiptEnum != null &&
          item.files.any((x) => CustomsDocType.tryParse(x.docType) == receiptEnum);
      paymentRows.add(
        RequestDetailFileUploadChip(
          label: hasReceipt
              ? s.requestDetailUploadReceiptAgain
              : (uploadReceiptLabel ?? s.requestDetailUploadReceipt),
          busy: uploadingDocType == receiptType,
          onTap: () => onUploadDocType!(receiptType),
        ),
      );
    }

    addSection(
      sectionKey: RequestDetailSectionKeys.filesPayment,
      title: s.requestFilesSectionPayment,
      needsAction: paymentSectionNeedsAction(item, grouped),
      rows: paymentRows,
    );

    addSection(
      sectionKey: RequestDetailSectionKeys.filesTransit,
      title: s.requestFilesSectionTransitArchive,
      needsAction: false,
      rows: grouped.transitArchive
          .map((f) => buildFileRow(f, highlight: _isHighlighted(f), embedded: false))
          .toList(),
    );

    addSection(
      sectionKey: RequestDetailSectionKeys.filesFinal,
      title: s.requestFilesSectionFinal,
      needsAction: false,
      rows: grouped.finalDocs
          .map((f) => buildFileRow(f, highlight: _isHighlighted(f), embedded: false))
          .toList(),
    );

    if (grouped.other.isNotEmpty) {
      addSection(
        sectionKey: RequestDetailSectionKeys.filesOther,
        title: s.requestFilesSectionOther,
        needsAction: false,
        rows: grouped.other
            .map((f) => buildFileRow(f, highlight: _isHighlighted(f), embedded: false))
            .toList(),
      );
    }

    if (children.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}

Widget _missingSignPlaceholder({
  required ThemeData theme,
  required String label,
  required String hint,
  bool embedded = false,
}) {
  final inner = Row(
    children: [
      Icon(Icons.draw_outlined, color: AppTheme.accentRed, size: 22),
      const Gap(10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              hint,
              style: theme.textTheme.labelSmall?.copyWith(
                color: AppTheme.accentRed,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    ],
  );

  if (embedded) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: inner,
    );
  }

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: AppTheme.accentRed.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppTheme.accentRed.withValues(alpha: 0.45)),
    ),
    child: inner,
  );
}
