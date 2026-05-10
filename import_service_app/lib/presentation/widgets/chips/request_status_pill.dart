import 'package:flutter/material.dart';
import 'package:import_service_app/core/themes/app_theme.dart';

/// Красный чип статуса (список и детализация заявки) — низкая высота, без `InkWell`.
class RequestStatusPill extends StatelessWidget {
  const RequestStatusPill({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.accentRed,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppTheme.white,
                fontWeight: FontWeight.w600,
                fontSize: 12.5,
                height: 1.2,
              ),
        ),
      ),
    );
  }
}
