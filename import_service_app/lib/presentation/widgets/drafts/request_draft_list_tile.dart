import 'package:flutter/material.dart';
import 'package:import_service_app/core/themes/app_theme.dart';
import 'package:import_service_app/data/models/request_draft.dart';
import 'package:import_service_app/data/models/request_form_model.dart';

class RequestDraftListTile extends StatelessWidget {
  const RequestDraftListTile({
    super.key,
    required this.draft,
    required this.fieldsProgressLabel,
    required this.savedAtLabel,
    required this.onOpen,
    required this.onDelete,
  });

  final RequestDraft draft;
  final String fieldsProgressLabel;
  final String savedAtLabel;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final filled = RequestFormModel.countFilledFields(draft.form);
    final progress = fieldsProgressLabel
        .replaceAll('{filled}', filled.toString())
        .replaceAll('{total}', RequestFormModel.trackedFieldCount.toString());

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE0E0E0)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      savedAtLabel,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      progress,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline),
                color: AppTheme.primaryBlue,
                tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
