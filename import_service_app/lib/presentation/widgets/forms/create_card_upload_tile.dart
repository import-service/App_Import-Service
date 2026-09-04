import 'package:flutter/material.dart';
import 'package:import_service_app/core/themes/app_theme.dart';

class CreateCardUploadTile extends StatelessWidget {
  const CreateCardUploadTile({
    super.key,
    required this.title,
    required this.buttonLabel,
    required this.onTap,
  });

  final String title;
  final String buttonLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 10),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              color: AppTheme.isDark
                  ? AppTheme.requestCardStatusPillBg
                  : const Color(0xFFFFF7F7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  buttonLabel,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.upload_outlined,
                  color: AppTheme.accentRed,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
