import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:import_service_app/core/themes/app_theme.dart';
import 'package:import_service_app/domain/entities/vehicle_finance_item.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

/// Пошлина/утиль: сумма, QR по [paymentQrUrl], чек по [receiptUrl] или кнопка загрузки.
class RequestDetailFinanceCard extends StatelessWidget {
  const RequestDetailFinanceCard({
    super.key,
    required this.line,
    required this.label,
    required this.receiptCaption,
    required this.uploadLabel,
    this.openReceiptLabel = 'Чек',
    required this.onUploadTap,
  });

  final VehicleFinanceItem line;
  final String label;
  final String receiptCaption;
  final String uploadLabel;
  final String openReceiptLabel;
  final VoidCallback onUploadTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.requestCardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: t.textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const Gap(4),
                    Text(
                      line.amountText,
                      style: t.textTheme.titleMedium?.copyWith(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.receipt_long_rounded,
                        size: 28,
                        color: AppTheme.primaryBlue,
                      ),
                      const Gap(2),
                      Text(
                        receiptCaption,
                        textAlign: TextAlign.center,
                        style: t.textTheme.labelSmall?.copyWith(
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w600,
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 10),
                  if (line.paymentQrUrl != null && line.paymentQrUrl!.isNotEmpty)
                    InkWell(
                      onTap: () => _open(context, line.paymentQrUrl!),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        width: 48,
                        height: 48,
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: AppTheme.pageBackground,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppTheme.requestCardBorder),
                        ),
                        child: QrImageView(
                          data: line.paymentQrUrl!,
                          size: 44,
                          version: QrVersions.auto,
                          backgroundColor: Colors.white,
                        ),
                      ),
                    )
                  else
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppTheme.pageBackground,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppTheme.requestCardBorder),
                      ),
                      child: const Icon(
                        Icons.qr_code_2_rounded,
                        size: 28,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                ],
              ),
            ],
          ),
          if (line.receiptUrl != null && line.receiptUrl!.isNotEmpty) ...[
            const Gap(10),
            Material(
              color: AppTheme.requestCardStatusPillBg,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: () => _open(context, line.receiptUrl!),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.link,
                        size: 20,
                        color: AppTheme.accentRed,
                      ),
                      const Gap(6),
                      Text(
                        openReceiptLabel,
                        style: t.textTheme.labelLarge?.copyWith(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ] else
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Material(
                color: AppTheme.requestCardStatusPillBg,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: onUploadTap,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.upload_file_rounded,
                          size: 20,
                          color: AppTheme.accentRed,
                        ),
                        const Gap(6),
                        Text(
                          uploadLabel,
                          style: t.textTheme.labelLarge?.copyWith(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _open(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      return;
    }
    if (!context.mounted) {
      return;
    }
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
