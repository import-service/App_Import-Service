import 'package:import_service_app/core/i18n/json_strings_service.dart';
import 'package:import_service_app/core/push/request_remote_update.dart';
import 'package:import_service_app/domain/entities/car_list_item.dart';
import 'package:import_service_app/domain/entities/request_status.dart';
import 'package:import_service_app/presentation/helpers/doc_type_labels.dart';
import 'package:import_service_app/presentation/helpers/request_status_labels.dart';
import 'package:import_service_app/presentation/helpers/request_status_sub_type_labels.dart';

/// Краткое описание изменений для карточки (1–2 строки).
String? buildPushChangeSummary(
  JsonStringsService strings,
  RequestRemoteUpdate update,
  CarListItem item,
) {
  final fromPush = update.changeSummary?.trim();
  if (fromPush != null && fromPush.isNotEmpty) {
    return fromPush;
  }

  final lines = <String>[];

  final previousApi = update.previousStatus?.trim();
  final statusApi = (update.status?.trim().isNotEmpty == true)
      ? update.status!.trim()
      : item.status.apiValue;
  final newStatus = RequestStatus.fromApiValue(statusApi);
  final newLabel = requestStatusLabel(newStatus, strings);

  if (previousApi != null && previousApi.isNotEmpty) {
    final prevLabel = requestStatusLabel(
      RequestStatus.fromApiValue(previousApi),
      strings,
    );
    lines.add(strings.requestCardChangeStatusTransition(prevLabel, newLabel));
  } else {
    lines.add(strings.requestCardChangeNewStatus(newLabel));
  }

  final subRaw = update.statusSubType?.trim().isNotEmpty == true
      ? update.statusSubType!.trim()
      : item.statusSubType;
  final subLabel = requestStatusSubTypeLabel(subRaw, strings);
  if (subLabel != null && subLabel.trim().isNotEmpty) {
    lines.add(subLabel.trim());
  }

  if (update.isFilesUpdate && update.changedDocTypes.isNotEmpty) {
    final docLabels = update.changedDocTypes
        .map((code) => docTypeLabelForCode(code, strings))
        .where((e) => e.trim().isNotEmpty)
        .take(3)
        .join(', ');
    if (docLabels.isNotEmpty) {
      lines.add(strings.requestCardChangeFiles(docLabels));
    }
  }

  if (lines.isEmpty) return null;
  return lines.take(2).join('\n');
}
