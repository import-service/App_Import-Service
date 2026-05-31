import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:import_service_app/core/themes/app_theme.dart';

/// Подсказка по [statusSubType] на карточке заявки (без отображения кода подстатуса).
class RequestDetailActionHintBanner extends StatelessWidget {
  const RequestDetailActionHintBanner({
    super.key,
    required this.message,
    this.urgent = false,
  });

  final String message;

  /// Красный баннер для действий (загрузка, подпись).
  final bool urgent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = urgent ? AppTheme.accentRed : AppTheme.primaryBlue;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.45)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            urgent ? Icons.error_outline_rounded : Icons.info_outline_rounded,
            size: 22,
            color: accent,
          ),
          const Gap(10),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: urgent ? AppTheme.accentRed : AppTheme.textPrimary,
                fontWeight: urgent ? FontWeight.w600 : FontWeight.w400,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
