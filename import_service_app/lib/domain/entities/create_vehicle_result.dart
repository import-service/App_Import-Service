import 'package:equatable/equatable.dart';
import 'package:import_service_app/domain/entities/car_list_item.dart';

/// Результат создания заявки: карточка + незагруженные docType (дозагрузка).
final class CreateVehicleResult extends Equatable {
  const CreateVehicleResult({
    required this.item,
    this.failedDocTypes = const [],
  });

  final CarListItem item;
  final List<String> failedDocTypes;

  bool get allFilesUploaded => failedDocTypes.isEmpty;

  @override
  List<Object?> get props => [item, failedDocTypes];
}
