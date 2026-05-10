import 'package:flutter/material.dart';
import 'package:import_service_app/core/themes/app_theme.dart';

/// Полноширинная синяя [FilledButton], опционально с индикатором загрузки.
class AppPrimaryFilledWideButton extends StatelessWidget {
  const AppPrimaryFilledWideButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.height = 48,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: AppTheme.primaryBlue,
          foregroundColor: AppTheme.white,
          disabledBackgroundColor: const Color(0xFFE0E0E0),
          disabledForegroundColor: const Color(0xFF9E9E9E),
        ),
        onPressed: isLoading ? null : onPressed,
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(label),
      ),
    );
  }
}
