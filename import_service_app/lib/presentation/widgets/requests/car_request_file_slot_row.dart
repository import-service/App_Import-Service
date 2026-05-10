import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:import_service_app/core/themes/app_theme.dart';

/// Одна позиция из экрана загрузки файлов заявки: подпись из [label], тап [onPressed].
class CarRequestFileSlotRow extends StatelessWidget {
  const CarRequestFileSlotRow({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.add_photo_alternate_outlined,
                  size: 22,
                  color: AppTheme.primaryBlue,
                ),
              ),
              const Gap(12),
              Expanded(
                child: Text(
                  label,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
