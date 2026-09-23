import 'package:flutter/material.dart';
import 'package:import_service_app/core/auth/session_preferences_keys.dart';
import 'package:import_service_app/core/di/injection_container.dart';
import 'package:import_service_app/core/i18n/json_strings_service.dart';
import 'package:import_service_app/core/themes/app_theme.dart';
import 'package:import_service_app/domain/entities/car_list_item.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Чип-фильтр по менеджеру 1С (`managerExternal1cId`).
class ManagerFilterBar extends StatelessWidget {
  const ManagerFilterBar({
    super.key,
    required this.items,
    required this.selectedExternal1cId,
    required this.onChanged,
  });

  final List<CarListItem> items;
  final String? selectedExternal1cId;
  final ValueChanged<String?> onChanged;

  static String? readSavedFilter() {
    final v = sl<SharedPreferences>()
        .getString(SessionPreferencesKeys.managerFilterExternal1cId);
    if (v == null || v.trim().isEmpty) return null;
    return v.trim();
  }

  static Future<void> saveFilter(String? id) async {
    final prefs = sl<SharedPreferences>();
    if (id == null || id.trim().isEmpty) {
      await prefs.remove(SessionPreferencesKeys.managerFilterExternal1cId);
    } else {
      await prefs.setString(
        SessionPreferencesKeys.managerFilterExternal1cId,
        id.trim(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = sl<JsonStringsService>();
    final options = <String, String>{};
    for (final item in items) {
      final id = item.managerExternal1cId?.trim();
      if (id == null || id.isEmpty) continue;
      final name = item.managerFullName?.trim();
      options[id] = (name != null && name.isNotEmpty) ? name : id;
    }
    // Сохранённый фильтр может отсутствовать в текущей странице — всё равно показать.
    final selected = selectedExternal1cId?.trim();
    if (selected != null &&
        selected.isNotEmpty &&
        !options.containsKey(selected)) {
      options[selected] = selected;
    }
    if (options.isEmpty && (selected == null || selected.isEmpty)) {
      return const SizedBox.shrink();
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Row(
        children: [
          FilterChip(
            label: Text(s.text('managerFilterAll')),
            selected: selected == null || selected.isEmpty,
            onSelected: (_) => onChanged(null),
            selectedColor: AppTheme.accentRed.withValues(alpha: 0.15),
          ),
          const SizedBox(width: 8),
          for (final entry in options.entries) ...[
            FilterChip(
              label: Text(entry.value),
              selected: selected == entry.key,
              onSelected: (_) => onChanged(entry.key),
              selectedColor: AppTheme.accentRed.withValues(alpha: 0.15),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}
