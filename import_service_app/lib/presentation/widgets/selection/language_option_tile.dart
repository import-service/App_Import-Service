import 'package:flutter/material.dart';
import 'package:import_service_app/core/themes/app_theme.dart';

/// Карточка выбора языка в стиле "radio", но без deprecated RadioListTile API.
class LanguageOptionTile extends StatelessWidget {
  const LanguageOptionTile({
    super.key,
    required this.title,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? AppTheme.primaryBlue
                  : theme.dividerColor.withValues(alpha: 0.35),
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              _RadioDot(selected: selected),
            ],
          ),
        ),
      ),
    );
  }
}

class _RadioDot extends StatelessWidget {
  const _RadioDot({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected
              ? AppTheme.primaryBlue
              : theme.dividerColor.withValues(alpha: 0.55),
          width: 2,
        ),
      ),
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: selected ? 10 : 0,
          height: selected ? 10 : 0,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.primaryBlue,
          ),
        ),
      ),
    );
  }
}
