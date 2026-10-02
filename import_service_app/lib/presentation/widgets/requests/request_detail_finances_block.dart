import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:import_service_app/core/constants/customs_catalog.dart';
import 'package:import_service_app/core/i18n/json_strings_service.dart';
import 'package:import_service_app/core/themes/app_theme.dart';
import 'package:import_service_app/data/local/request_detail_section_prefs.dart';
import 'package:import_service_app/domain/entities/car_list_item.dart';
import 'package:import_service_app/domain/entities/customs_request_file.dart';
import 'package:import_service_app/presentation/helpers/request_detail_line_labels.dart';
import 'package:import_service_app/presentation/helpers/request_detail_pending_actions.dart';
import 'package:import_service_app/presentation/widgets/requests/request_detail_collapsible_section.dart';
import 'package:import_service_app/presentation/widgets/requests/request_detail_finance_card.dart';
import 'package:import_service_app/presentation/widgets/requests/request_detail_files_sections.dart';
import 'package:import_service_app/presentation/widgets/requests/request_detail_payment_groups.dart';

/// Финансы и оплата: суммы + файлы/квитанции оплаты в одном блоке.
class RequestDetailFinancesBlock extends StatelessWidget {
  const RequestDetailFinancesBlock({
    super.key,
    required this.requestId,
    required this.item,
    required this.strings,
    this.onUploadReceipt,
    this.buildFileRow,
    this.onUploadDocType,
    this.uploadingDocType,
    this.uploadReceiptLabel,
    this.highlightedDocTypes = const {},
    this.newDocTypes = const {},
    this.changedDocTypes = const {},
    this.svhUploadMode = false,
  });

  final String requestId;
  final CarListItem item;
  final JsonStringsService strings;
  final void Function(String docType)? onUploadReceipt;
  final RequestFileRowBuilder? buildFileRow;
  final void Function(String docType)? onUploadDocType;
  final String? uploadingDocType;
  final String? uploadReceiptLabel;
  final Set<String> highlightedDocTypes;
  final Set<String> newDocTypes;
  final Set<String> changedDocTypes;
  final bool svhUploadMode;

  static bool shouldShow(CarListItem item) {
    return RequestDetailFinancesBlock._hasAmounts(item) ||
        item.financeItems.isNotEmpty ||
        groupedFilesForItem(item).payment.isNotEmpty;
  }

  static bool _hasAmounts(CarListItem item) {
    return _nonEmpty(item.advancePayment) ||
        _nonEmpty(item.actualPayment) ||
        _nonEmpty(item.refundAmount);
  }

  static bool _nonEmpty(String? v) => v != null && v.trim().isNotEmpty;

  static String _formatRub(String? raw) {
    final t = raw?.trim() ?? '';
    if (t.isEmpty) return '—';
    if (t.contains('₽')) return t;
    return '$t ₽';
  }

  bool _isHighlighted(CustomsRequestFile file) {
    final code = normalizeDocType(file.docType ?? '');
    if (code.isEmpty) return false;
    return highlightedDocTypes.contains(code);
  }

  bool _isNew(CustomsRequestFile file) {
    final code = normalizeDocType(file.docType ?? '');
    if (code.isEmpty) return false;
    return newDocTypes.contains(code);
  }

  bool _isChanged(CustomsRequestFile file) {
    final code = normalizeDocType(file.docType ?? '');
    if (code.isEmpty) return false;
    return changedDocTypes.contains(code);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final children = <Widget>[];
    final grouped = groupedFilesForItem(item);

    if (_hasAmounts(item)) {
      if (_nonEmpty(item.advancePayment)) {
        children.add(
          _AmountTile(
            label: strings.text('requestDetailAdvancePayment'),
            value: _formatRub(item.advancePayment),
          ),
        );
      }
      if (_nonEmpty(item.actualPayment)) {
        if (children.isNotEmpty) children.add(const Gap(8));
        children.add(
          _AmountTile(
            label: strings.text('requestDetailActualPayment'),
            value: _formatRub(item.actualPayment),
          ),
        );
      }
    }

    if (item.financeItems.isNotEmpty) {
      if (children.isNotEmpty) children.add(const Gap(12));
      for (var i = 0; i < item.financeItems.length; i++) {
        final line = item.financeItems[i];
        children.add(
          RequestDetailFinanceCard(
            line: line,
            label: financeItemLabel(line, strings),
            receiptCaption: strings.requestDetailReceiptCaption,
            uploadLabel: onUploadReceipt == null
                ? null
                : ((line.receiptUrl != null && line.receiptUrl!.trim().isNotEmpty)
                    ? strings.requestDetailUploadReceiptAgain
                    : strings.requestDetailUploadReceipt),
            openReceiptLabel: strings.requestDetailOpenReceipt,
            onUploadTap: onUploadReceipt == null
                ? null
                : () {
                    final docType = receiptDocTypeForFinanceLineType(line.lineType);
                    if (docType == null) return;
                    onUploadReceipt!(docType);
                  },
          ),
        );
        if (i < item.financeItems.length - 1) {
          children.add(const Gap(10));
        }
      }
    }

    if (buildFileRow != null) {
      final paymentRows = <Widget>[];
      addPaymentPairGroups(
        out: paymentRows,
        allFiles: item.files,
        buildFileRow: (f, {required highlight, badge, embedded = false, isNew = false, isChanged = false}) =>
            buildFileRow!(
              f,
              highlight: highlight,
              badge: badge,
              embedded: embedded,
              isNew: isNew,
              isChanged: isChanged,
            ),
        strings: strings,
        isHighlighted: _isHighlighted,
        isNewFile: _isNew,
        isChangedFile: _isChanged,
        onUploadDocType: svhUploadMode ? null : onUploadDocType,
        uploadingDocType: uploadingDocType,
        uploadReceiptLabelOverride: uploadReceiptLabel,
      );
      if (children.isNotEmpty) children.add(const Gap(12));
      if (paymentRows.isEmpty) {
        children.add(
          Text(
            strings.text('requestFilesSectionEmpty'),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
        );
      } else {
        for (var i = 0; i < paymentRows.length; i++) {
          children.add(paymentRows[i]);
          if (i < paymentRows.length - 1) children.add(const Gap(8));
        }
      }
    }

    final hasRefund = _nonEmpty(item.refundAmount);
    final refundPreview = hasRefund
        ? _RefundPreview(
            label: strings.text('requestDetailRefundAmount'),
            value: _formatRub(item.refundAmount),
            theme: theme,
          )
        : null;

    final needsAction =
        !svhUploadMode && paymentSectionNeedsAction(item, grouped);

    return RequestDetailCollapsibleSection(
      requestId: requestId,
      sectionKey: RequestDetailSectionKeys.finances,
      title: strings.requestDetailFinances,
      needsAction: needsAction,
      subtitle: refundPreview,
      children: children.isEmpty
          ? [
              Text(
                strings.text('requestFilesSectionEmpty'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
            ]
          : children,
    );
  }
}

class _RefundPreview extends StatelessWidget {
  const _RefundPreview({
    required this.label,
    required this.value,
    required this.theme,
  });

  final String label;
  final String value;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
          const Gap(2),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _AmountTile extends StatelessWidget {
  const _AmountTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.requestCardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
          ),
          const Gap(4),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
