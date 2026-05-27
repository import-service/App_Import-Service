import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:import_service_app/core/di/injection_container.dart';
import 'package:import_service_app/core/i18n/json_strings_service.dart';
import 'package:import_service_app/core/themes/app_theme.dart';
import 'package:import_service_app/domain/entities/car_list_item.dart';
import 'package:import_service_app/domain/entities/customs_request_file.dart';
import 'package:import_service_app/domain/services/request_files_grouper.dart';
import 'package:import_service_app/presentation/helpers/doc_type_labels.dart';

typedef RequestFileRowBuilder = Widget Function(
  CustomsRequestFile file, {
  required bool highlight,
  String? badge,
});

/// Секции файлов заявки по этапам (концепция §13).
class RequestDetailFilesSections extends StatelessWidget {
  const RequestDetailFilesSections({
    super.key,
    required this.item,
    required this.buildFileRow,
  });

  final CarListItem item;
  final RequestFileRowBuilder buildFileRow;

  @override
  Widget build(BuildContext context) {
    final grouped = groupRequestFiles(
      files: item.files,
      statusSubType: item.statusSubType,
    );
    final s = sl<JsonStringsService>();
    final theme = Theme.of(context);
    final children = <Widget>[];

    void addSection(String title, List<Widget> rows) {
      if (rows.isEmpty) return;
      if (children.isNotEmpty) children.add(const Gap(24));
      children.add(_sectionShell(theme: theme, title: title, children: rows));
    }

    addSection(
      s.requestFilesSectionCreation,
      grouped.creation
          .map((f) => buildFileRow(f, highlight: false))
          .toList(),
    );

    final signingRows = <Widget>[];
    for (final pair in grouped.signingPairs) {
      if (pair.original != null) {
        signingRows.add(
          buildFileRow(
            pair.original!,
            highlight: pair.highlightSignature,
            badge: pair.needsSignature ? s.requestFileNeedsSignature : null,
          ),
        );
      }
      if (pair.signed != null) {
        signingRows.add(
          buildFileRow(pair.signed!, highlight: false),
        );
      } else if (pair.needsSignature && pair.original == null) {
        signingRows.add(
          _missingSignPlaceholder(
            theme: theme,
            label: docTypeLabelForCode(pair.baseDocType, s),
            hint: s.requestFileNeedsSignature,
          ),
        );
      }
    }
    addSection(s.requestFilesSectionSigning, signingRows);

    addSection(
      s.requestFilesSectionPayment,
      grouped.payment.map((f) => buildFileRow(f, highlight: false)).toList(),
    );

    if (grouped.other.isNotEmpty) {
      addSection(
        s.requestFilesSectionOther,
        grouped.other.map((f) => buildFileRow(f, highlight: false)).toList(),
      );
    }

    if (children.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}

Widget _sectionShell({
  required ThemeData theme,
  required String title,
  required List<Widget> children,
}) {
  return Container(
    decoration: BoxDecoration(
      color: AppTheme.primaryBlue.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppTheme.primaryBlue.withValues(alpha: 0.6)),
    ),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    child: Theme(
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        initiallyExpanded: true,
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(top: 8, bottom: 4),
        title: Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1) const Gap(8),
          ],
        ],
      ),
    ),
  );
}

Widget _missingSignPlaceholder({
  required ThemeData theme,
  required String label,
  required String hint,
}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: AppTheme.accentRed.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppTheme.accentRed.withValues(alpha: 0.45)),
    ),
    child: Row(
      children: [
        Icon(Icons.draw_outlined, color: AppTheme.accentRed, size: 22),
        const Gap(10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                hint,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppTheme.accentRed,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
