import 'package:flutter/material.dart';

/// XOR-выбор роли сотрудника СВХ (не две галки сразу).
/// [compact] — на карточке в списке (без длинной подсказки).
class StaffManagerRoleRadios extends StatelessWidget {
  const StaffManagerRoleRadios({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.compact = false,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final bool enabled;
  final bool compact;

  static const String svh = 'svh_manager';
  static const String declarant = 'declarant_manager';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Роль',
          style: (compact
                  ? theme.textTheme.labelMedium
                  : theme.textTheme.titleSmall)
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        if (!compact) ...[
          const SizedBox(height: 4),
          Text(
            'Оба — менеджеры СВХ; отличаются объёмом прав',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ] else
          const SizedBox(height: 2),
        RadioGroup<String>(
          groupValue: value,
          onChanged: enabled
              ? (v) {
                  if (v != null) onChanged(v);
                }
              : (_) {},
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<String>(
                contentPadding: EdgeInsets.zero,
                dense: true,
                visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
                title: Text(
                  compact ? 'Менеджер СВХ' : 'Менеджер СВХ (фото/видео)',
                  style: compact ? theme.textTheme.bodySmall : null,
                ),
                value: svh,
                enabled: enabled,
              ),
              RadioListTile<String>(
                contentPadding: EdgeInsets.zero,
                dense: true,
                visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
                title: Text(
                  compact
                      ? 'Менеджер-декларант'
                      : 'Менеджер-декларант (заявки/чаты)',
                  style: compact ? theme.textTheme.bodySmall : null,
                ),
                value: declarant,
                enabled: enabled,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
