import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:import_service_app/core/constants/customs_catalog.dart';
import 'package:import_service_app/core/i18n/json_strings_service.dart';
import 'package:import_service_app/core/themes/app_theme.dart';
import 'package:import_service_app/data/local/request_detail_section_prefs.dart';
import 'package:import_service_app/domain/entities/car_list_item.dart';
import 'package:import_service_app/presentation/helpers/request_detail_line_labels.dart';
import 'package:import_service_app/presentation/widgets/requests/request_detail_collapsible_section.dart';
import 'package:import_service_app/presentation/widgets/requests/request_detail_finance_card.dart';

/// Финансы: аванс / факт / к возврату + строки оплат (свернуто по умолчанию).
class RequestDetailFinancesBlock extends StatelessWidget {
  const RequestDetailFinancesBlock({
    super.key,
    required this.requestId,
    required this.item,
    required this.strings,
    required this.onUploadReceipt,
  });

  final String requestId;
  final CarListItem item;
  final JsonStringsService strings;
  final void Function(String docType) onUploadReceipt;

  static bool shouldShow(CarListItem item) {
    return RequestDetailFinancesBlock._hasAmounts(item) || item.financeItems.isNotEmpty;
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final children = <Widget>[];

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
            uploadLabel: (line.receiptUrl != null && line.receiptUrl!.trim().isNotEmpty)
                ? strings.requestDetailUploadReceiptAgain
                : strings.requestDetailUploadReceipt,
            openReceiptLabel: strings.requestDetailOpenReceipt,
            onUploadTap: () {
              final docType = receiptDocTypeForFinanceLineType(line.lineType);
              if (docType == null) return;
              onUploadReceipt(docType);
            },
          ),
        );
        if (i < item.financeItems.length - 1) {
          children.add(const Gap(10));
        }
      }
    }

    final hasRefund = _nonEmpty(item.refundAmount);
    final hasExpandedContent = children.isNotEmpty;
    final refundPreview = hasRefund
        ? _RefundPreview(
            label: strings.text('requestDetailRefundAmount'),
            value: _formatRub(item.refundAmount),
            theme: theme,
          )
        : null;

    if (!hasRefund && !hasExpandedContent) return const SizedBox.shrink();

    if (!hasExpandedContent) {
      return _FinancesRefundOnlyShell(
        title: strings.requestDetailFinances,
        refundPreview: refundPreview!,
        theme: theme,
      );
    }

    return RequestDetailCollapsibleSection(
      requestId: requestId,
      sectionKey: RequestDetailSectionKeys.finances,
      title: strings.requestDetailFinances,
      needsAction: false,
      subtitle: refundPreview,
      children: children,
    );
  }
}

class _FinancesRefundOnlyShell extends StatelessWidget {
  const _FinancesRefundOnlyShell({
    required this.title,
    required this.refundPreview,
    required this.theme,
  });

  final String title;
  final _RefundPreview refundPreview;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    const radius = 14.0;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF2F7FD),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppTheme.primaryBlue.withValues(alpha: 0.6)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            refundPreview,
          ],
        ),
      ),
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
        color: AppTheme.white,
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
