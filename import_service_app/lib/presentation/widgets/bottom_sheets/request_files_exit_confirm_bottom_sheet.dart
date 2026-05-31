import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:import_service_app/core/di/injection_container.dart';
import 'package:import_service_app/core/i18n/json_strings_service.dart';
import 'package:import_service_app/core/themes/app_theme.dart';
import 'package:import_service_app/presentation/widgets/bottom_sheets/app_modal_bottom_sheet.dart';
import 'package:import_service_app/presentation/widgets/bottom_sheets/sheet_header.dart';
import 'package:import_service_app/presentation/widgets/buttons/app_primary_filled_wide_button.dart';

/// Результат шторки выхода со страницы файлов.
enum RequestFilesExitChoice {
  save,
  leaveWithoutSave,
}

/// Подтверждение выхода со страницы файлов без сохранения.
class RequestFilesExitConfirmBottomSheet extends StatelessWidget {
  const RequestFilesExitConfirmBottomSheet({super.key});

  static Future<RequestFilesExitChoice?> show(BuildContext context) {
    return AppModalBottomSheet.show<RequestFilesExitChoice>(
      context: context,
      child: const RequestFilesExitConfirmBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = sl<JsonStringsService>();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetHeader(title: strings.requestFilesLeaveTitle),
        Text(
          strings.requestFilesLeaveMessage,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.accentRed,
              ),
        ),
        const Gap(20),
        Row(
          children: [
            Expanded(
              child: AppPrimaryFilledWideButton(
                label: strings.requestFilesLeaveSave,
                onPressed: () => Navigator.of(context).pop(
                  RequestFilesExitChoice.save,
                ),
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
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  onPressed: () => Navigator.of(context).pop(
                    RequestFilesExitChoice.leaveWithoutSave,
                  ),
                  child: Text(
                    strings.requestFilesLeaveConfirm,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
