import 'package:import_service_app/domain/entities/car_list_item.dart';

/// Локальное хранение списка заявок: реализация — [CarInventoryCubit] (presentation).
abstract interface class CarInventoryStateHolder {
  List<CarListItem> get items;
  Future<void> reloadFromDisk();
  Future<void> add(CarListItem item);
  Future<void> replaceAll(List<CarListItem> items);

  /// Подменить существующую заявку по [CarListItem.id] или добавить в конец.
  Future<void> upsertItem(CarListItem item);
}
