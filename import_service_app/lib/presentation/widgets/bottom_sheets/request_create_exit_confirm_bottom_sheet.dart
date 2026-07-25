import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:import_service_app/core/di/injection_container.dart';
import 'package:import_service_app/core/i18n/json_strings_service.dart';
import 'package:import_service_app/core/themes/app_theme.dart';
import 'package:import_service_app/presentation/widgets/bottom_sheets/app_modal_bottom_sheet.dart';
import 'package:import_service_app/presentation/widgets/bottom_sheets/sheet_header.dart';
import 'package:import_service_app/presentation/widgets/buttons/app_primary_filled_wide_button.dart';

/// Результат шторки выхода с формы заявки.
enum RequestCreateExitChoice {
  saveDraft,
  discard,
}

/// Спросить: сохранить черновик или выйти без сохранения.
class RequestCreateExitConfirmBottomSheet extends StatelessWidget {
  const RequestCreateExitConfirmBottomSheet({super.key});

  static Future<RequestCreateExitChoice?> show(BuildContext context) {
    return AppModalBottomSheet.show<RequestCreateExitChoice>(
      context: context,
      child: const RequestCreateExitConfirmBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = sl<JsonStringsService>();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetHeader(title: strings.text('requestCreateLeaveTitle')),
        Text(
          strings.text('requestCreateLeaveMessage'),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.accentRed,
              ),
        ),
        const Gap(20),
        Row(
          children: [
            Expanded(
              child: AppPrimaryFilledWideButton(
                label: strings.text('requestCreateLeaveSave'),
                onPressed: () => Navigator.of(context).pop(
                  RequestCreateExitChoice.saveDraft,
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
                    RequestCreateExitChoice.discard,
                  ),
                  child: Text(
                    strings.text('requestCreateLeaveDiscard'),
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
