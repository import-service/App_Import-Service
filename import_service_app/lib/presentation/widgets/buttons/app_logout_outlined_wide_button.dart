import 'package:flutter/material.dart';
import 'package:import_service_app/core/themes/app_theme.dart';

/// Полноширинная outlined-кнопка выхода (нейтральный текст, красноватая обводка).
class AppLogoutOutlinedWideButton extends StatelessWidget {
  const AppLogoutOutlinedWideButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.height = 52,
  });

  final String label;
  final VoidCallback onPressed;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          backgroundColor: AppTheme.white,
          foregroundColor: AppTheme.textPrimary,
          side: const BorderSide(color: AppTheme.accentRed, width: 1),
        ),
        onPressed: onPressed,
        child: Text(label),
      ),
    );
  }
}
