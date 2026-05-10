import 'package:flutter/material.dart';
import 'package:import_service_app/core/themes/app_theme.dart';

/// Текстовая кнопка с подчёркиванием (акцентный цвет бренда).
class AppAccentUnderlinedTextButton extends StatelessWidget {
  const AppAccentUnderlinedTextButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      style: TextButton.styleFrom(
        foregroundColor: AppTheme.accentRed,
        textStyle: const TextStyle(decoration: TextDecoration.underline),
      ),
      onPressed: onPressed,
      child: Text(label),
    );
  }
}
