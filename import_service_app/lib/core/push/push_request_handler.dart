import 'package:import_service_app/core/di/injection_container.dart';
import 'package:import_service_app/core/i18n/json_strings_service.dart';
import 'package:import_service_app/core/navigation/home_cars_navigation_controller.dart';
import 'package:import_service_app/core/push/request_remote_update.dart';
import 'package:import_service_app/core/ui/app_feedback_kind.dart';
import 'package:import_service_app/core/ui/app_feedback_service.dart';
import 'package:import_service_app/domain/entities/car_list_item.dart';
import 'package:import_service_app/domain/entities/request_status.dart';
import 'package:import_service_app/domain/entities/request_status_sub_type.dart';
import 'package:import_service_app/domain/repositories/cars_repository.dart';
import 'package:import_service_app/presentation/bloc/car_inventory/car_inventory_cubit.dart';
import 'package:import_service_app/presentation/bloc/request_attention/request_attention_cubit.dart';
import 'package:import_service_app/presentation/helpers/push_change_summary.dart';
import 'package:import_service_app/presentation/router/app_router.dart';

/// Обработка push по заявке: refresh, таб списка, подсветка карточки.
Future<void> handleRequestRemoteUpdate(RequestRemoteUpdate update) async {
  final id = update.requestId.trim();
  if (id.isEmpty) return;

  _focusTabFromPushStatus(update.status);

  final repo = sl<CarsRepository>();
  final single = await repo.getVehicle(id);
  if (single.isLeft()) {
    await repo.listVehicles();
    syncCarsTabFromInventory(id);
    return;
  }
  final item = single.getOrElse(() => throw StateError('unreachable'));

  if (update.isFilesUpdate && update.changedDocTypes.isNotEmpty) {
    sl<RequestAttentionCubit>().markFileHighlights(id, update.changedDocTypes);
    sl<AppFeedbackService>().show(
      sl<JsonStringsService>().text('pushToastFilesUpdated'),
      kind: AppFeedbackKind.success,
    );
    final encodedId = Uri.encodeComponent(id);
    appRouter.push('/request/$encodedId?focus=docs');
    return;
  }

  final sub = RequestStatusSubType.tryParse(item.statusSubType);
  if (sub == RequestStatusSubType.primaryDocumentsSent ||
      sub == RequestStatusSubType.signatureRevisionRequired) {
    sl<RequestAttentionCubit>().markDocsAction(id);
    final encodedId = Uri.encodeComponent(id);
    appRouter.push('/request/$encodedId?focus=docs');
    return;
  }

  final summary = buildPushChangeSummary(sl<JsonStringsService>(), update, item);
  sl<RequestAttentionCubit>().markStatusUpdated(id, summary: summary);
  sl<HomeCarsNavigationController>().focusCarsListForStatus(item.status);
}

/// Перед открытием деталки по тапу на push — сразу таб по data.status, затем refresh.
Future<void> prepareCarsTabBeforeDetailOpen(String requestId) async {
  final id = requestId.trim();
  if (id.isEmpty) return;

  syncCarsTabFromInventory(id);

  final repo = sl<CarsRepository>();
  final single = await repo.getVehicle(id);
  single.fold((_) async {
    await repo.listVehicles();
    syncCarsTabFromInventory(id);
  }, (item) {
    sl<HomeCarsNavigationController>().focusCarsListForStatus(item.status);
  });
}

/// После выхода с деталки — таб по актуальному статусу заявки в инвентаре.
void syncCarsTabFromInventory(String requestId) {
  final id = requestId.trim();
  if (id.isEmpty) return;

  CarListItem? item;
  for (final candidate in sl<CarInventoryCubit>().state.items) {
    if (candidate.id == id) {
      item = candidate;
      break;
    }
  }
  if (item != null) {
    sl<HomeCarsNavigationController>().focusCarsListForStatus(item.status);
  }
}

void _focusTabFromPushStatus(String? statusApi) {
  final raw = statusApi?.trim() ?? '';
  if (raw.isEmpty) return;
  sl<HomeCarsNavigationController>().focusCarsListForStatus(
    RequestStatus.fromApiValue(raw),
  );
}
