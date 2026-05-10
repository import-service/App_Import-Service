import 'package:flutter/material.dart';
import 'package:import_service_app/core/themes/app_theme.dart';

/// Горизонтальный ряд плиток-заглушек вместо фото до прихода URL.
class RequestDetailPhotoPlaceholdersRow extends StatelessWidget {
  const RequestDetailPhotoPlaceholdersRow({
    super.key,
    required this.count,
    required this.onTileTap,
    this.placeholderA11y,
  });

  final int count;
  final VoidCallback onTileTap;
  final String? placeholderA11y;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    return SizedBox(
      height: 88,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: count,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          return Semantics(
            button: true,
            label: placeholderA11y ?? '',
            child: Material(
              color: AppTheme.white,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: onTileTap,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 104,
                  height: 88,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.requestCardBorder,
                    ),
                    color: AppTheme.pageBackground,
                  ),
                  child: Icon(
                    Icons.image_outlined,
                    size: 36,
                    color: AppTheme.textSecondary.withValues(alpha: 0.55),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
