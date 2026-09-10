import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:import_service_app/presentation/widgets/bottom_sheets/app_modal_bottom_sheet.dart';
import 'package:import_service_app/presentation/widgets/bottom_sheets/sheet_header.dart';

/// Пункт универсальной шторки выбора действия.
final class AppChoiceSheetOption<T> {
  const AppChoiceSheetOption({
    required this.value,
    required this.label,
    required this.icon,
  });

  final T value;
  final String label;
  final IconData icon;
}

/// Одна шторка со списком опций (иконка + текст) на всё приложение.
///
/// Использовать вместо копипасты InkWell-рядов в пикерах и экранах.
abstract final class AppChoiceBottomSheet {
  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    required List<AppChoiceSheetOption<T>> options,
  }) {
    assert(options.isNotEmpty, 'AppChoiceBottomSheet: options пустой');
    return AppModalBottomSheet.show<T>(
      context: context,
      child: Builder(
        builder: (sheetContext) => Material(
          color: Colors.transparent,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SheetHeader(title: title),
              for (final option in options)
                InkWell(
                  onTap: () => Navigator.pop(sheetContext, option.value),
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Icon(option.icon),
                        const Gap(12),
                        Expanded(child: Text(option.label)),
                      ],
                    ),
                  ),
                ),
              const Gap(8),
            ],
          ),
        ),
      ),
    );
  }
}
