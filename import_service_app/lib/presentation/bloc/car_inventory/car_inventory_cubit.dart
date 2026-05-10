import 'dart:convert';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:import_service_app/data/local/car_inventory_state_holder.dart';
import 'package:import_service_app/domain/entities/car_list_item.dart';
import 'package:import_service_app/presentation/bloc/car_inventory/car_inventory_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Список заявок на главной: демо / локальное, синхр. с [SharedPreferences].
final class CarInventoryCubit extends Cubit<CarInventoryState>
    implements CarInventoryStateHolder {
  CarInventoryCubit(this._prefs) : super(const CarInventoryState(items: []));

  static const _prefsKey = 'cars_inventory_v13';

  final SharedPreferences _prefs;

  @override
  List<CarListItem> get items => state.items;

  @override
  Future<void> reloadFromDisk() async {
    final raw = _prefs.getString(_prefsKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List<dynamic>) {
          final list = decoded
              .whereType<Map<String, dynamic>>()
              .map(CarListItem.fromJson)
              .where((e) => e.id.isNotEmpty)
              .toList();
          if (list.isNotEmpty) {
            emit(CarInventoryState(items: list));
            return;
          }
        }
      } catch (_) {
        // падаем в сид ниже
      }
    }
    emit(const CarInventoryState(items: []));
    await _persist();
  }

  @override
  Future<void> add(CarListItem item) async {
    final next = List<CarListItem>.from(state.items)..add(item);
    emit(CarInventoryState(items: next));
    await _persist();
  }

  @override
  Future<void> replaceAll(List<CarListItem> items) async {
    final next = List<CarListItem>.from(items);
    emit(CarInventoryState(items: next));
    await _persist();
  }

  @override
  Future<void> upsertItem(CarListItem item) async {
    final next = <CarListItem>[];
    var replaced = false;
    for (final e in state.items) {
      if (e.id == item.id) {
        next.add(item);
        replaced = true;
      } else {
        next.add(e);
      }
    }
    if (!replaced) {
      next.add(item);
    }
    emit(CarInventoryState(items: next));
    await _persist();
  }

  Future<void> _persist() async {
    final encoded =
        jsonEncode(state.items.map((e) => e.toJson()).toList(growable: false));
    await _prefs.setString(_prefsKey, encoded);
  }
}
