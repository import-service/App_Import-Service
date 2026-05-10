import 'package:flutter/material.dart';
import 'package:import_service_app/core/themes/app_theme.dart';

/// Полноширинная кнопка с синей обводкой (вторичные CTA).
class AppPrimaryOutlinedWideButton extends StatelessWidget {
  const AppPrimaryOutlinedWideButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.height = 48,
  });

  final String label;
  final VoidCallback? onPressed;
  final double height;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return SizedBox(
      width: double.infinity,
      height: height,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: enabled
              ? AppTheme.primaryBlue
              : const Color(0xFF9E9E9E),
          side: BorderSide(
            color: enabled ? AppTheme.primaryBlue : const Color(0xFFBDBDBD),
          ),
        ),
        onPressed: onPressed,
        child: Text(label),
      ),
    );
  }
}
