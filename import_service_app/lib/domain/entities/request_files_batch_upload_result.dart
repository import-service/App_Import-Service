import 'package:equatable/equatable.dart';
import 'package:import_service_app/domain/entities/car_list_item.dart';

/// Результат батча upload (create или дозагрузка).
final class RequestFilesBatchUploadResult extends Equatable {
  const RequestFilesBatchUploadResult({
    required this.item,
    this.failedDocTypes = const [],
  });

  final CarListItem item;
  final List<String> failedDocTypes;

  bool get allSucceeded => failedDocTypes.isEmpty;

  @override
  List<Object?> get props => [item, failedDocTypes];
}
