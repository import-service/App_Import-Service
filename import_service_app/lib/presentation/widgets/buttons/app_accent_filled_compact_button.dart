import 'package:flutter/material.dart';
import 'package:import_service_app/core/themes/app_theme.dart';

/// Компактная красная [FilledButton] (не на всю ширину).
class AppAccentFilledCompactButton extends StatelessWidget {
  const AppAccentFilledCompactButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: AppTheme.accentRed,
        foregroundColor: AppTheme.white,
      ),
      onPressed: onPressed,
      child: Text(label),
    );
  }
}
