import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:import_service_app/core/i18n/json_strings_service.dart';
import 'package:import_service_app/core/themes/app_theme.dart';
import 'package:import_service_app/core/util/vin_display.dart';
import 'package:import_service_app/data/local/request_detail_section_prefs.dart';
import 'package:import_service_app/domain/entities/car_list_item.dart';
import 'package:import_service_app/presentation/helpers/deal_type_labels.dart';
import 'package:import_service_app/presentation/widgets/requests/request_detail_collapsible_section.dart';

/// Секция «О заявке»: владелец, сделка, авто — по умолчанию свёрнута.
class RequestDetailOwnerSection extends StatelessWidget {
  const RequestDetailOwnerSection({
    super.key,
    required this.requestId,
    required this.item,
    required this.strings,
  });

  final String requestId;
  final CarListItem item;
  final JsonStringsService strings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rows = <Widget>[
      _LabeledValue(
        label: strings.requestDetailOwner,
        value: item.ownerFullName,
        theme: theme,
      ),
    ];

    final dealTypeText = dealTypeLabelForCode(item.dealType, strings);
    if (dealTypeText != null) {
      rows
        ..add(const Gap(14))
        ..add(
          _LabeledValue(
            label: strings.requestDetailDealType,
            value: dealTypeText,
            theme: theme,
          ),
        );
    }

    if (item.managerFullName != null && item.managerFullName!.trim().isNotEmpty) {
      rows
        ..add(const Gap(14))
        ..add(
          _LabeledValue(
            label: strings.requestDetailManager,
            value: item.managerFullName!.trim(),
            theme: theme,
          ),
        );
    }

    rows
      ..add(const Gap(14))
      ..add(
        _LabeledValue(
          label: strings.requestDetailVehicle,
          value: item.displayCarLine,
          theme: theme,
        ),
      );

    if ((item.engineSpec != null && item.engineSpec!.trim().isNotEmpty) ||
        (item.engineVolume != null && item.engineVolume!.trim().isNotEmpty)) {
      rows
        ..add(const Gap(14))
        ..add(
          _EngineLabeled(
            label: strings.requestDetailEngine,
            specLine: item.engineSpec != null && item.engineSpec!.trim().isNotEmpty
                ? item.engineSpec!.trim()
                : null,
            volumeLine:
                item.engineVolume != null && item.engineVolume!.trim().isNotEmpty
                    ? item.engineVolume!.trim()
                    : null,
            theme: theme,
          ),
        );
    }

    rows
      ..add(const Gap(14))
      ..add(
        _LabeledValue(
          label: strings.requestDetailVin,
          value: formatVinForDetail(item.vin),
          theme: theme,
        ),
      );

    return RequestDetailCollapsibleSection(
      requestId: requestId,
      sectionKey: RequestDetailSectionKeys.owner,
      title: strings.requestDetailAboutSection,
      needsAction: false,
      children: rows,
    );
  }
}

class _LabeledValue extends StatelessWidget {
  const _LabeledValue({
    required this.label,
    required this.value,
    required this.theme,
  });

  final String label;
  final String value;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
        ),
        const Gap(4),
        Text(
          value,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _EngineLabeled extends StatelessWidget {
  const _EngineLabeled({
    required this.label,
    required this.specLine,
    required this.volumeLine,
    required this.theme,
  });

  final String label;
  final String? specLine;
  final String? volumeLine;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final parts = <String>[
      if (specLine != null) specLine!,
      if (volumeLine != null) volumeLine!,
    ];
    return _LabeledValue(
      label: label,
      value: parts.join(', '),
      theme: theme,
    );
  }
}
