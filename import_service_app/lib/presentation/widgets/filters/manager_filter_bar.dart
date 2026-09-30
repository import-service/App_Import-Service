import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:import_service_app/core/auth/auth_session_controller.dart';
import 'package:import_service_app/core/auth/session_preferences_keys.dart';
import 'package:import_service_app/core/di/injection_container.dart';
import 'package:import_service_app/core/i18n/json_strings_service.dart';
import 'package:import_service_app/core/themes/app_theme.dart';
import 'package:import_service_app/domain/entities/car_list_item.dart';
import 'package:import_service_app/presentation/widgets/bottom_sheets/app_modal_bottom_sheet.dart';
import 'package:import_service_app/presentation/widgets/bottom_sheets/sheet_header.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Режим dropdown-фильтра менеджеров 1С.
enum ManagerFilterMode {
  /// Заявки текущего пользователя (`managerExternal1cId` = session.external1cId).
  mine,

  /// Все заявки без фильтра.
  all,

  /// Один менеджер 1С.
  manager,
}

/// Выбор фильтра: Мои / Все / конкретный менеджер.
final class ManagerFilterSelection {
  const ManagerFilterSelection._(this.mode, [this.managerId]);

  const ManagerFilterSelection.mine() : this._(ManagerFilterMode.mine);
  const ManagerFilterSelection.all() : this._(ManagerFilterMode.all);
  factory ManagerFilterSelection.manager(String id) =>
      ManagerFilterSelection._(ManagerFilterMode.manager, id.trim());

  final ManagerFilterMode mode;
  final String? managerId;

  static const String persistMine = '__mine__';
  static const String persistAll = '__all__';

  bool get isMine => mode == ManagerFilterMode.mine;
  bool get isAll => mode == ManagerFilterMode.all;

  /// Query `managerExternal1cId` для API; `null` = без фильтра.
  /// Для «Мои» без `external1cId` в сессии — пустая строка (родитель покажет пустой список).
  String? resolveApiManagerExternal1cId(String? sessionExternal1cId) {
    switch (mode) {
      case ManagerFilterMode.all:
        return null;
      case ManagerFilterMode.mine:
        final id = sessionExternal1cId?.trim() ?? '';
        return id.isEmpty ? '' : id;
      case ManagerFilterMode.manager:
        final id = managerId?.trim() ?? '';
        return id.isEmpty ? null : id;
    }
  }

  String label(JsonStringsService s, Map<String, String> managerNames) {
    switch (mode) {
      case ManagerFilterMode.mine:
        return s.text('managerFilterMine');
      case ManagerFilterMode.all:
        return s.text('managerFilterAll');
      case ManagerFilterMode.manager:
        final id = managerId ?? '';
        return managerNames[id] ?? id;
    }
  }

  static ManagerFilterSelection readSaved() {
    final raw = sl<SharedPreferences>()
        .getString(SessionPreferencesKeys.managerFilterExternal1cId)
        ?.trim();
    if (raw == null || raw.isEmpty || raw == persistMine) {
      return const ManagerFilterSelection.mine();
    }
    if (raw == persistAll) {
      return const ManagerFilterSelection.all();
    }
    // Старый мультивыбор — первый id.
    final first = raw.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).firstOrNull;
    if (first == null || first == persistMine) {
      return const ManagerFilterSelection.mine();
    }
    if (first == persistAll) {
      return const ManagerFilterSelection.all();
    }
    return ManagerFilterSelection.manager(first);
  }

  static Future<void> save(ManagerFilterSelection selection) async {
    final prefs = sl<SharedPreferences>();
    switch (selection.mode) {
      case ManagerFilterMode.mine:
        await prefs.setString(
          SessionPreferencesKeys.managerFilterExternal1cId,
          persistMine,
        );
      case ManagerFilterMode.all:
        await prefs.setString(
          SessionPreferencesKeys.managerFilterExternal1cId,
          persistAll,
        );
      case ManagerFilterMode.manager:
        final id = selection.managerId?.trim() ?? '';
        if (id.isEmpty) {
          await prefs.setString(
            SessionPreferencesKeys.managerFilterExternal1cId,
            persistMine,
          );
        } else {
          await prefs.setString(
            SessionPreferencesKeys.managerFilterExternal1cId,
            id,
          );
        }
    }
  }

  @override
  bool operator ==(Object other) {
    return other is ManagerFilterSelection &&
        other.mode == mode &&
        other.managerId == managerId;
  }

  @override
  int get hashCode => Object.hash(mode, managerId);
}

/// Dropdown-фильтр по менеджерам 1С, один выбор, persist.
///
/// Меню: «Мои заявки» → «Все менеджеры» → менеджеры A–Я.
class ManagerFilterBar extends StatelessWidget {
  const ManagerFilterBar({
    super.key,
    required this.items,
    required this.selection,
    required this.onChanged,
    this.optionsOverride,
    this.padding = const EdgeInsets.fromLTRB(20, 0, 20, 8),
  });

  final List<CarListItem> items;
  final ManagerFilterSelection selection;
  final ValueChanged<ManagerFilterSelection> onChanged;

  final Map<String, String>? optionsOverride;
  final EdgeInsetsGeometry padding;

  /// @Deprecated — используйте [ManagerFilterSelection.readSaved].
  static Set<String> readSavedFilter() {
    final sel = ManagerFilterSelection.readSaved();
    switch (sel.mode) {
      case ManagerFilterMode.mine:
        return <String>{ManagerFilterSelection.persistMine};
      case ManagerFilterMode.all:
        return <String>{};
      case ManagerFilterMode.manager:
        return sel.managerId == null ? <String>{} : <String>{sel.managerId!};
    }
  }

  /// @Deprecated — используйте [ManagerFilterSelection.save].
  static Future<void> saveFilter(Set<String> ids) async {
    if (ids.isEmpty) {
      await ManagerFilterSelection.save(const ManagerFilterSelection.all());
      return;
    }
    final first = ids.first;
    if (first == ManagerFilterSelection.persistMine) {
      await ManagerFilterSelection.save(const ManagerFilterSelection.mine());
    } else if (first == ManagerFilterSelection.persistAll) {
      await ManagerFilterSelection.save(const ManagerFilterSelection.all());
    } else {
      await ManagerFilterSelection.save(ManagerFilterSelection.manager(first));
    }
  }

  static Map<String, String> optionsFromItems(List<CarListItem> items) {
    final options = <String, String>{};
    for (final item in items) {
      final id = item.managerExternal1cId?.trim();
      if (id == null || id.isEmpty) continue;
      final name = item.managerFullName?.trim();
      options[id] = (name != null && name.isNotEmpty) ? name : id;
    }
    return options;
  }

  Map<String, String> _resolvedOptions() {
    final options = Map<String, String>.from(
      optionsOverride ?? optionsFromItems(items),
    );
    if (selection.mode == ManagerFilterMode.manager) {
      final id = selection.managerId;
      if (id != null && id.isNotEmpty && !options.containsKey(id)) {
        options[id] = id;
      }
    }
    return options;
  }

  Future<void> _openPicker(
    BuildContext context,
    JsonStringsService s,
    Map<String, String> options,
  ) async {
    final sorted = options.entries.toList()
      ..sort(
        (a, b) => a.value.toLowerCase().compareTo(b.value.toLowerCase()),
      );

    final picked = await AppModalBottomSheet.show<ManagerFilterSelection>(
      context: context,
      child: _ManagerFilterSheet(
        title: s.text('managerFilterSheetTitle'),
        mineLabel: s.text('managerFilterMine'),
        allManagersLabel: s.text('managerFilterAll'),
        managers: sorted,
        selection: selection,
      ),
    );
    if (!context.mounted || picked == null) return;
    onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final s = sl<JsonStringsService>();
    final options = _resolvedOptions();
    final label = selection.label(s, options);

    return Padding(
      padding: padding,
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            backgroundColor: AppTheme.cardBackground,
            foregroundColor: AppTheme.textPrimary,
            side: const BorderSide(color: AppTheme.primaryBlue),
            padding: const EdgeInsets.symmetric(horizontal: 14),
          ),
          onPressed: () => _openPicker(context, s, options),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.left,
                ),
              ),
              const Icon(Icons.keyboard_arrow_down_rounded, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

class _ManagerFilterSheet extends StatelessWidget {
  const _ManagerFilterSheet({
    required this.title,
    required this.mineLabel,
    required this.allManagersLabel,
    required this.managers,
    required this.selection,
  });

  final String title;
  final String mineLabel;
  final String allManagersLabel;
  final List<MapEntry<String, String>> managers;
  final ManagerFilterSelection selection;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetHeader(title: title),
        _optionTile(
          context: context,
          label: mineLabel,
          selected: selection.isMine,
          onTap: () => Navigator.pop(
            context,
            const ManagerFilterSelection.mine(),
          ),
        ),
        _optionTile(
          context: context,
          label: allManagersLabel,
          selected: selection.isAll,
          onTap: () => Navigator.pop(
            context,
            const ManagerFilterSelection.all(),
          ),
        ),
        for (final entry in managers)
          _optionTile(
            context: context,
            label: entry.value,
            selected: selection.mode == ManagerFilterMode.manager &&
                selection.managerId == entry.key,
            onTap: () => Navigator.pop(
              context,
              ManagerFilterSelection.manager(entry.key),
            ),
          ),
        const Gap(8),
      ],
    );
  }

  Widget _optionTile({
    required BuildContext context,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: selected ? AppTheme.primaryBlue : AppTheme.textPrimary,
                ),
              ),
            ),
            if (selected)
              const Icon(
                Icons.check_rounded,
                size: 20,
                color: AppTheme.primaryBlue,
              ),
          ],
        ),
      ),
    );
  }
}

/// `external1cId` текущего логина для режима «Мои заявки».
String? sessionManagerExternal1cIdForMineFilter() {
  return sl<AuthSessionController>().external1cId?.trim();
}
