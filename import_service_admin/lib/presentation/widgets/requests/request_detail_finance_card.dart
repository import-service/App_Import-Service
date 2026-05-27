import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:import_service_admin/core/catalog/customs_request_labels.dart';
import 'package:import_service_admin/core/theme/app_theme.dart';
import 'package:import_service_admin/domain/entities/customs_request_finance_item.dart';
import 'package:url_launcher/url_launcher.dart';

class RequestDetailFinanceCard extends StatelessWidget {
  const RequestDetailFinanceCard({
    super.key,
    required this.line,
  });

  final CustomsRequestFinanceItem line;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = financeLineLabel(
      lineType: line.lineType,
      title: line.title,
    );
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
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
          if (line.amountText != null && line.amountText!.trim().isNotEmpty) ...[
            const Gap(4),
            Text(
              line.amountText!.trim(),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (line.paymentQrUrl != null && line.paymentQrUrl!.trim().isNotEmpty)
            _LinkButton(
              label: 'Открыть квитанцию / QR',
              url: line.paymentQrUrl!,
            ),
          if (line.receiptUrl != null && line.receiptUrl!.trim().isNotEmpty)
            _LinkButton(label: 'Открыть чек', url: line.receiptUrl!),
        ],
      ),
    );
  }
}

class _LinkButton extends StatelessWidget {
  const _LinkButton({required this.label, required this.url});

  final String label;
  final String url;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Material(
        color: AppTheme.requestCardStatusPillBg,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () async {
            final uri = Uri.tryParse(url);
            if (uri == null) return;
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.link, size: 20, color: AppTheme.accentRed),
                const Gap(6),
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
