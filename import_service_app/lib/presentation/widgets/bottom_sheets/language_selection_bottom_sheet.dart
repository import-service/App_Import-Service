import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:import_service_app/core/di/injection_container.dart';
import 'package:import_service_app/core/i18n/app_locale.dart';
import 'package:import_service_app/core/i18n/language_autonyms.dart';
import 'package:import_service_app/core/i18n/json_strings_service.dart';
import 'package:import_service_app/presentation/widgets/bottom_sheets/app_modal_bottom_sheet.dart';
import 'package:import_service_app/presentation/widgets/bottom_sheets/sheet_header.dart';
import 'package:import_service_app/presentation/widgets/selection/language_option_tile.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  Future<void> _apply(String languageCode) async {
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

  @override
  Widget build(BuildContext context) {
    final strings = sl<JsonStringsService>();

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
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),
        const Gap(12),
        LanguageOptionTile(
          title: LanguageAutonyms.russian,
          selected: _selected == 'ru',
          onTap: () => _apply('ru'),
        ),
        const Gap(10),
        LanguageOptionTile(
          title: LanguageAutonyms.chinese,
          selected: _selected == 'zh',
          onTap: () => _apply('zh'),
        ),
      ],
    );
  }
}
