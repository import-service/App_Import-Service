import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:import_service_app/core/di/injection_container.dart';
import 'package:import_service_app/core/i18n/json_strings_service.dart';
import 'package:import_service_app/presentation/bloc/request_draft/request_draft_cubit.dart';
import 'package:import_service_app/presentation/bloc/request_draft/request_draft_state.dart';
import 'package:import_service_app/presentation/pages/request_create_page.dart';
import 'package:import_service_app/presentation/widgets/bottom_sheets/app_modal_bottom_sheet.dart';
import 'package:import_service_app/presentation/widgets/bottom_sheets/request_draft_delete_confirm_bottom_sheet.dart';
import 'package:import_service_app/presentation/widgets/bottom_sheets/sheet_header.dart';
import 'package:import_service_app/presentation/widgets/drafts/request_draft_list_tile.dart';
import 'package:intl/intl.dart';

class RequestDraftsBottomSheet extends StatelessWidget {
  const RequestDraftsBottomSheet({super.key});

  static Future<void> show(BuildContext context) {
    return AppModalBottomSheet.show<void>(
      context: context,
      child: const RequestDraftsBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = sl<JsonStringsService>();
    final cubit = sl<RequestDraftCubit>();
    final dateFormat = DateFormat('dd.MM.yyyy HH:mm');

    return BlocBuilder<RequestDraftCubit, RequestDraftState>(
      bloc: cubit,
      builder: (context, state) {
        final drafts = state.draftsSorted;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SheetHeader(title: strings.requestDraftsSheetTitle),
            if (drafts.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  strings.noDataTitle,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.55,
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: drafts.length,
                  itemBuilder: (context, index) {
                    final draft = drafts[index];
                    return RequestDraftListTile(
                      draft: draft,
                      fieldsProgressLabel: strings.requestDraftsFieldsProgress,
                      savedAtLabel: dateFormat.format(draft.updatedAt),
                      onOpen: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => RequestCreatePage(draftId: draft.id),
                          ),
                        );
                      },
                      onDelete: () async {
                        final ok =
                            await RequestDraftDeleteConfirmBottomSheet.show(context);
                        if (!ok || !context.mounted) return;
                        await cubit.delete(draft.id);
                      },
                    );
                  },
                ),
              ),
            const Gap(8),
          ],
        );
      },
    );
  }
}

