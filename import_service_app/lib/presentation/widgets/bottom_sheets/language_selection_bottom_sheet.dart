import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:import_service_app/core/di/injection_container.dart';
import 'package:import_service_app/core/i18n/app_locale.dart';
import 'package:import_service_app/core/i18n/language_autonyms.dart';
import 'package:import_service_app/core/i18n/json_strings_service.dart';
import 'package:import_service_app/core/themes/app_theme_mode.dart';
import 'package:import_service_app/presentation/widgets/bottom_sheets/app_modal_bottom_sheet.dart';
import 'package:import_service_app/presentation/widgets/bottom_sheets/sheet_header.dart';
import 'package:import_service_app/presentation/widgets/selection/language_option_tile.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Настройки с экрана логина / шестерёнки: язык + тема.
class LanguageSelectionBottomSheet extends StatefulWidget {
  const LanguageSelectionBottomSheet({super.key});

  static Future<void> show(BuildContext context) {
    return AppModalBottomSheet.show<void>(
      context: context,
      child: const LanguageSelectionBottomSheet(),
    );
  }

  @override
  State<LanguageSelectionBottomSheet> createState() =>
      _LanguageSelectionBottomSheetState();
}

class _LanguageSelectionBottomSheetState
    extends State<LanguageSelectionBottomSheet> {
  late String _selected = appLocale.value.languageCode;

  Future<void> _applyLanguage(String languageCode) async {
    setState(() => _selected = languageCode);

    final navigator = Navigator.of(context);
    final router = GoRouter.maybeOf(context);

    final prefs = sl<SharedPreferences>();
    await prefs.setString('app_language', languageCode);

    final nextLocale =
        languageCode == 'zh' ? const Locale('zh') : const Locale('ru');
    await sl<JsonStringsService>().load(nextLocale);
    appLocale.value = nextLocale;

    if (!mounted) return;
    router?.refresh();
    navigator.pop();
  }

  Future<void> _onThemeMode(Set<ThemeMode> selection) async {
    if (selection.isEmpty) return;
    await setAppThemeMode(sl<SharedPreferences>(), selection.first);
  }

  @override
  Widget build(BuildContext context) {
    final strings = sl<JsonStringsService>();
    final onVariant = Theme.of(context).colorScheme.onSurfaceVariant;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetHeader(title: strings.settingsTitle),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            strings.languagePickerTitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: onVariant,
                ),
          ),
        ),
        const Gap(12),
        LanguageOptionTile(
          title: LanguageAutonyms.russian,
          selected: _selected == 'ru',
          onTap: () => _applyLanguage('ru'),
        ),
        const Gap(10),
        LanguageOptionTile(
          title: LanguageAutonyms.chinese,
          selected: _selected == 'zh',
          onTap: () => _applyLanguage('zh'),
        ),
        const Gap(20),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            strings.text('profileThemeLabel'),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: onVariant,
                ),
          ),
        ),
        const Gap(10),
        ValueListenableBuilder<ThemeMode>(
          valueListenable: appThemeMode,
          builder: (context, mode, _) {
            return SizedBox(
              width: double.infinity,
              child: SegmentedButton<ThemeMode>(
                segments: [
                  ButtonSegment<ThemeMode>(
                    value: ThemeMode.light,
                    label: Text(strings.text('profileThemeLight')),
                    tooltip: strings.text('profileThemeLight'),
                  ),
                  ButtonSegment<ThemeMode>(
                    value: ThemeMode.dark,
                    label: Text(strings.text('profileThemeDark')),
                    tooltip: strings.text('profileThemeDark'),
                  ),
                  ButtonSegment<ThemeMode>(
                    value: ThemeMode.system,
                    label: Text(strings.text('profileThemeSystem')),
                    tooltip: strings.text('profileThemeSystem'),
                  ),
                ],
                selected: {mode},
                onSelectionChanged: _onThemeMode,
                showSelectedIcon: false,
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
