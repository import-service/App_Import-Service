import 'package:flutter/material.dart';
import 'package:import_service_app/presentation/widgets/bottom_sheets/language_selection_bottom_sheet.dart';

/// Кнопка настроек (язык) для [AppBar.actions].
class SettingsAppBarAction extends StatelessWidget {
  const SettingsAppBarAction({super.key, required this.tooltip});

  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () => LanguageSelectionBottomSheet.show(context),
      icon: const Icon(Icons.settings_outlined),
      tooltip: tooltip,
    );
  }
}
