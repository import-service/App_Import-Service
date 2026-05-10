import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:import_service_app/core/di/injection_container.dart';
import 'package:import_service_app/core/i18n/json_strings_service.dart';
import 'package:import_service_app/core/themes/app_theme.dart';
import 'package:import_service_app/presentation/widgets/bottom_sheets/app_modal_bottom_sheet.dart';
import 'package:import_service_app/presentation/widgets/bottom_sheets/sheet_header.dart';
import 'package:import_service_app/presentation/widgets/buttons/app_primary_outlined_wide_button.dart';

class RequestDraftDeleteConfirmBottomSheet extends StatelessWidget {
  const RequestDraftDeleteConfirmBottomSheet({super.key});

  static Future<bool> show(BuildContext context) async {
    final result = await AppModalBottomSheet.show<bool>(
      context: context,
      child: const RequestDraftDeleteConfirmBottomSheet(),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final strings = sl<JsonStringsService>();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetHeader(title: strings.requestDraftsDeleteTitle),
        Text(
          strings.requestDraftsDeleteMessage,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.accentRed,
              ),
        ),
        const Gap(20),
        Row(
          children: [
            Expanded(
              child: AppPrimaryOutlinedWideButton(
                label: strings.actionCancel,
                onPressed: () => Navigator.of(context).pop(false),
              ),
            ),
            const Gap(12),
            Expanded(
              child: SizedBox(
                height: 48,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.accentRed,
                    foregroundColor: AppTheme.white,
                  ),
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(strings.requestDraftsDeleteConfirm),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
