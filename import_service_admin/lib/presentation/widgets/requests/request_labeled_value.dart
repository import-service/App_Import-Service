import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:import_service_admin/core/theme/app_theme.dart';

class RequestLabeledValue extends StatelessWidget {
  const RequestLabeledValue({
    super.key,
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppTheme.textSecondary,
          ),
        ),
        const Gap(4),
        SelectableText(
          value,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
