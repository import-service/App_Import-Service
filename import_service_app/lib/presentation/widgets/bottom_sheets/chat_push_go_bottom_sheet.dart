import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:import_service_app/core/di/injection_container.dart';
import 'package:import_service_app/core/i18n/json_strings_service.dart';
import 'package:import_service_app/presentation/widgets/bottom_sheets/app_modal_bottom_sheet.dart';
import 'package:import_service_app/presentation/widgets/bottom_sheets/sheet_header.dart';
import 'package:import_service_app/presentation/widgets/buttons/app_primary_filled_wide_button.dart';

/// Foreground: новое сообщение в чате — предложить перейти.
class ChatPushGoBottomSheet extends StatelessWidget {
  const ChatPushGoBottomSheet({super.key});

  /// `true` — перейти в чат.
  static Future<bool?> show(BuildContext context) {
    return AppModalBottomSheet.show<bool>(
      context: context,
      child: const ChatPushGoBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = sl<JsonStringsService>();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetHeader(title: strings.text('pushToastNewMessage')),
        Text(
          strings.text('pushChatGoMessage'),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const Gap(20),
        AppPrimaryFilledWideButton(
          label: strings.text('requestCardGoToChat'),
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
  }
}
