import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:import_service_app/core/i18n/json_strings_service.dart';
import 'package:import_service_app/core/themes/app_theme.dart';
import 'package:import_service_app/domain/entities/car_list_item.dart';

/// Аванс / факт / к возврату (API v2, строки в рублях).
class RequestDetailCustomsAmountsSection extends StatelessWidget {
  const RequestDetailCustomsAmountsSection({
    super.key,
    required this.item,
    required this.strings,
  });

  final CarListItem item;
  final JsonStringsService strings;

  static bool hasAnyAmount(CarListItem item) {
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          strings.requestDetailFinances,
          style: theme.textTheme.titleMedium?.copyWith(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Gap(10),
        if (_nonEmpty(item.advancePayment))
          _AmountTile(
            label: strings.text('requestDetailAdvancePayment'),
            value: _formatRub(item.advancePayment),
          ),
        if (_nonEmpty(item.advancePayment) &&
            (_nonEmpty(item.actualPayment) || _nonEmpty(item.refundAmount)))
          const Gap(8),
        if (_nonEmpty(item.actualPayment))
          _AmountTile(
            label: strings.text('requestDetailActualPayment'),
            value: _formatRub(item.actualPayment),
          ),
        if (_nonEmpty(item.actualPayment) && _nonEmpty(item.refundAmount))
          const Gap(8),
        if (_nonEmpty(item.refundAmount))
          _AmountTile(
            label: strings.text('requestDetailRefundAmount'),
            value: _formatRub(item.refundAmount),
          ),
      ],
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
