import 'package:equatable/equatable.dart';
import 'package:import_service_app/domain/entities/car_list_item.dart';

final class CarInventoryState extends Equatable {
  const CarInventoryState({required this.items});

  final List<CarListItem> items;

  CarInventoryState copyWith({List<CarListItem>? items}) {
    return CarInventoryState(
      items: items ?? this.items,
    );
  }

  @override
  List<Object?> get props => [items];
}
