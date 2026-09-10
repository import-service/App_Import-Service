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
import 'package:import_service_app/presentation/widgets/requests/request_detail_payment_groups.dart';

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
    this.onUploadSvhCarGallery,
    this.onUploadSvhCarVideos,
    this.onUploadTransitArchiveGallery,
    this.onUploadOtherDocsGallery,
    this.uploadingDocType,
    this.uploadingSvhCarGallery = false,
    this.uploadingSvhCarVideos = false,
    this.uploadingTransitArchiveGallery = false,
    this.uploadingOtherDocsGallery = false,
    this.uploadSignedLabel,
    this.uploadReceiptLabel,
    this.onTransitPhotoTap,
    this.highlightedDocTypes = const {},
    this.svhUploadMode = false,
  });

  final String requestId;
  final CarListItem item;
  final RequestFileRowBuilder buildFileRow;
  final RequestDeliverableRowBuilder buildDeliverableRow;
  final void Function(String docType)? onUploadDocType;
  /// Мультизагрузка фото в галерею «Фото и видео машины» (СВХ).
  final VoidCallback? onUploadSvhCarGallery;
  /// Мультизагрузка видео в ту же галерею (до 3).
  final VoidCallback? onUploadSvhCarVideos;
  /// Галерея архива транзита: загруженные + «Добавить» (лимит 3).
  final VoidCallback? onUploadTransitArchiveGallery;
  /// Галерея прочих файлов: загруженные + «Добавить» (лимит 2).
  final VoidCallback? onUploadOtherDocsGallery;
  final String? uploadingDocType;
  final bool uploadingSvhCarGallery;
  final bool uploadingSvhCarVideos;
  final bool uploadingTransitArchiveGallery;
  final bool uploadingOtherDocsGallery;
  final String? uploadSignedLabel;
  final String? uploadReceiptLabel;
  final void Function(String url)? onTransitPhotoTap;
  final Set<String> highlightedDocTypes;
  /// Менеджер СВХ: галерея / архив, без подписей/оплат.
  final bool svhUploadMode;

  bool _isHighlighted(CustomsRequestFile file) {
    final code = normalizeDocType(file.docType ?? '');
    if (code.isEmpty) return false;
    return highlightedDocTypes.contains(code);
  }

  String? _signingBadge({
    required bool needsSignature,
    required bool highlight,
    required JsonStringsService s,
  }) {
    if (highlight) return s.requestFileUpdated;
    if (needsSignature) return s.requestFileNeedsSignature;
    return null;
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
      rows: _buildCreationRows(
        grouped: grouped,
        s: s,
        theme: theme,
      ),
    );

    final signingRows = <Widget>[];
    for (final pair in grouped.signingPairs) {
      final targetType = pair.baseDocType.signedApiCode;
      final canUpload =
          !svhUploadMode && pair.canUploadSigned && onUploadDocType != null;
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
                badge: _signingBadge(
                  needsSignature: pair.needsSignature,
                  highlight: _isHighlighted(pair.original!),
                  s: s,
                ),
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
                badge: _signingBadge(
                  needsSignature: pair.needsSignature,
                  highlight: _isHighlighted(pair.original!),
                  s: s,
                ),
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
                badge: _signingBadge(
                  needsSignature: pair.needsSignature,
                  highlight: _isHighlighted(pair.original!),
                  s: s,
                ),
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
            badge: _signingBadge(
              needsSignature: pair.needsSignature,
              highlight: pair.highlightSignature || _isHighlighted(pair.original!),
              s: s,
            ),
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
    addPaymentPairGroups(
      out: paymentRows,
      allFiles: item.files,
      buildFileRow: buildFileRow,
      strings: s,
      isHighlighted: _isHighlighted,
      onUploadDocType: svhUploadMode ? null : onUploadDocType,
      uploadingDocType: uploadingDocType,
      uploadReceiptLabelOverride: uploadReceiptLabel,
    );

    addSection(
      sectionKey: RequestDetailSectionKeys.filesPayment,
      title: s.requestFilesSectionPayment,
      needsAction: svhUploadMode ? false : paymentSectionNeedsAction(item, grouped),
      rows: paymentRows,
    );

    if (_shouldShowSvhCarGallery(item, grouped)) {
      addSection(
        sectionKey: RequestDetailSectionKeys.filesSvhCarGallery,
        title: s.requestFilesSectionSvhCarGallery,
        needsAction: false,
        rows: _buildSvhCarGalleryRows(
          grouped: grouped,
          s: s,
          theme: theme,
        ),
      );
    }

    addSection(
      sectionKey: RequestDetailSectionKeys.filesIssueHandover,
      title: s.requestFilesSectionIssueHandover,
      needsAction: false,
      rows: _buildIssueHandoverRows(
        grouped: grouped,
        s: s,
        theme: theme,
      ),
    );

    final otherRows = _buildOtherRows(
      grouped: grouped,
      s: s,
      theme: theme,
    );
    if (otherRows.isNotEmpty) {
      addSection(
        sectionKey: RequestDetailSectionKeys.filesOther,
        title: s.requestFilesSectionOther,
        needsAction: false,
        rows: otherRows,
      );
    }

    if (children.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }

  List<Widget> _buildCreationRows({
    required RequestFilesGrouped grouped,
    required JsonStringsService s,
    required ThemeData theme,
  }) {
    return grouped.creation
        .map((f) => buildFileRow(f, highlight: _isHighlighted(f), embedded: false))
        .toList();
  }

  bool _shouldShowSvhCarGallery(CarListItem item, RequestFilesGrouped grouped) {
    if (grouped.svhCarGallery.isNotEmpty) return true;
    // Менеджер СВХ: галерея на любом этапе заявки.
    return svhUploadMode;
  }

  List<Widget> _buildSvhCarGalleryRows({
    required RequestFilesGrouped grouped,
    required JsonStringsService s,
    required ThemeData theme,
  }) {
    final photos = grouped.svhCarGallery
        .where((f) => isSvhCarGalleryDocType(f.docType))
        .toList();
    final videos = grouped.svhCarGallery
        .where((f) => isSvhCarVideoDocType(f.docType))
        .toList();
    final photoCount = photos.length;
    final videoCount = videos.length;
    final rows = <Widget>[
      Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(
          s
              .text('requestFilesSectionSvhCarGalleryCount')
              .replaceAll('{count}', '$photoCount')
              .replaceAll('{max}', '$kSvhCarGalleryMaxPhotos'),
          style: theme.textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
        ),
      ),
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          s
              .text('requestFilesSectionSvhCarVideoCount')
              .replaceAll('{count}', '$videoCount')
              .replaceAll('{max}', '$kSvhCarGalleryMaxVideos'),
          style: theme.textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
        ),
      ),
    ];

    if (svhUploadMode && onUploadSvhCarGallery != null) {
      final full = photoCount >= kSvhCarGalleryMaxPhotos;
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            full
                ? s.text('requestFilesSectionSvhCarGalleryFull')
                : s.text('requestFilesSectionSvhCarGalleryHint'),
            style: theme.textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
          ),
        ),
      );
      rows.add(
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: full || uploadingSvhCarGallery || uploadingSvhCarVideos
                ? null
                : onUploadSvhCarGallery,
            icon: uploadingSvhCarGallery
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add_a_photo_outlined),
            label: Text(s.text('requestFilesSectionSvhCarGalleryAdd')),
          ),
        ),
      );
      rows.add(const Gap(8));
    }

    if (svhUploadMode && onUploadSvhCarVideos != null) {
      final full = videoCount >= kSvhCarGalleryMaxVideos;
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            full
                ? s.text('requestFilesSectionSvhCarVideoFull')
                : s.text('requestFilesSectionSvhCarVideoHint'),
            style: theme.textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
          ),
        ),
      );
      rows.add(
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: full || uploadingSvhCarGallery || uploadingSvhCarVideos
                ? null
                : onUploadSvhCarVideos,
            icon: uploadingSvhCarVideos
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.videocam_outlined),
            label: Text(s.text('requestFilesSectionSvhCarVideoAdd')),
          ),
        ),
      );
      rows.add(const Gap(8));
    }

    for (final f in grouped.svhCarGallery) {
      rows.add(buildFileRow(f, highlight: _isHighlighted(f), embedded: false));
    }
    return rows;
  }

  List<Widget> _buildIssueHandoverRows({
    required RequestFilesGrouped grouped,
    required JsonStringsService s,
    required ThemeData theme,
  }) {
    final transitFiles = grouped.transitArchive;
    final finalFiles = grouped.finalDocs;
    final canUpload = onUploadTransitArchiveGallery != null;
    final count = occupiedUploadSlotCount(
      slots: kSvhTransitUploadDocTypes,
      existingDocTypes: item.files.map((f) => f.docType),
    );

    if (!canUpload && transitFiles.isEmpty && finalFiles.isEmpty) {
      return const [];
    }

    final rows = <Widget>[];

    if (canUpload || transitFiles.isNotEmpty) {
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            s
                .text('requestFilesSectionTransitGalleryCount')
                .replaceAll('{count}', '$count')
                .replaceAll('{max}', '$kTransitArchiveMaxPhotos'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
        ),
      );
    }

    if (canUpload) {
      final full = count >= kTransitArchiveMaxPhotos;
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            full
                ? s.text('requestFilesSectionTransitGalleryFull')
                : s.text('requestFilesSectionTransitGalleryHint'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
        ),
      );
      rows.add(
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: full || uploadingTransitArchiveGallery
                ? null
                : onUploadTransitArchiveGallery,
            icon: uploadingTransitArchiveGallery
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add_a_photo_outlined),
            label: Text(s.text('requestFilesSectionTransitGalleryAdd')),
          ),
        ),
      );
      rows.add(const Gap(8));
    }

    for (final f in transitFiles) {
      rows.add(buildFileRow(f, highlight: _isHighlighted(f), embedded: false));
    }
    for (final f in finalFiles) {
      rows.add(buildFileRow(f, highlight: _isHighlighted(f), embedded: false));
    }
    return rows;
  }

  List<Widget> _buildOtherRows({
    required RequestFilesGrouped grouped,
    required JsonStringsService s,
    required ThemeData theme,
  }) {
    final otherFiles = grouped.other;
    final slotFiles = otherFiles
        .where((f) => isOtherUploadDocType(f.docType))
        .toList();
    final restFiles = otherFiles
        .where((f) => !isOtherUploadDocType(f.docType))
        .toList();
    final canUpload = onUploadOtherDocsGallery != null;
    final count = occupiedUploadSlotCount(
      slots: kSvhOtherUploadDocTypes,
      existingDocTypes: item.files.map((f) => f.docType),
    );

    if (!canUpload && otherFiles.isEmpty) return const [];

    final rows = <Widget>[];

    if (canUpload || slotFiles.isNotEmpty) {
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            s
                .text('requestFilesSectionOtherGalleryCount')
                .replaceAll('{count}', '$count')
                .replaceAll('{max}', '$kOtherDocsMaxFiles'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
        ),
      );
    }

    if (canUpload) {
      final full = count >= kOtherDocsMaxFiles;
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            full
                ? s.text('requestFilesSectionOtherGalleryFull')
                : s.text('requestFilesSectionOtherGalleryHint'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
        ),
      );
      rows.add(
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: full || uploadingOtherDocsGallery
                ? null
                : onUploadOtherDocsGallery,
            icon: uploadingOtherDocsGallery
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.attach_file),
            label: Text(s.text('requestFilesSectionOtherGalleryAdd')),
          ),
        ),
      );
      rows.add(const Gap(8));
    }

    for (final f in slotFiles) {
      rows.add(buildFileRow(f, highlight: _isHighlighted(f), embedded: false));
    }
    for (final f in restFiles) {
      rows.add(buildFileRow(f, highlight: _isHighlighted(f), embedded: false));
    }
    return rows;
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
