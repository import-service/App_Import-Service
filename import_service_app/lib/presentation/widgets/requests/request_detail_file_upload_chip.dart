import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:import_service_app/core/themes/app_theme.dart';

/// Кнопка загрузки подписи / чека на карточке заявки.
class RequestDetailFileUploadChip extends StatelessWidget {
  const RequestDetailFileUploadChip({
    super.key,
    required this.label,
    required this.onTap,
    this.busy = false,
    this.embedded = false,
  });

  final String label;
  final VoidCallback? onTap;
  final bool busy;
  /// Внутри [RequestDetailDocUploadGroup] — без отдельной рамки.
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = Row(
      children: [
        if (busy)
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else
          const Icon(
            Icons.upload_file_rounded,
            size: 20,
            color: AppTheme.accentRed,
          ),
        const Gap(8),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );

    if (embedded) {
      return Material(
        color: AppTheme.requestCardStatusPillBg.withValues(alpha: 0.45),
        child: InkWell(
          onTap: busy ? null : onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            child: content,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: busy ? null : onTap,
          borderRadius: BorderRadius.circular(12),
          child: Ink(
            decoration: BoxDecoration(
              color: AppTheme.requestCardStatusPillBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.requestCardBorder),
            ),
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            child: content,
          ),
        ),
      ),
    );
  }
}
