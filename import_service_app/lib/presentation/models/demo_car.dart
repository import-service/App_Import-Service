import 'package:import_service_app/domain/entities/request_status.dart';

/// Карточка в списке: те же смыслы, что в [CarListItem] (марка/модель отдельно).
class DemoCar {
  DemoCar({
    required this.id,
    required this.ownerFullName,
    required this.carMake,
    required this.carModel,
    required this.vin,
    required this.statusLabel,
    required this.requestStatus,
    this.managerFullName,
    this.external1cId,
  });

  final String id;
  final String ownerFullName;
  final String carMake;
  final String carModel;
  final String vin;
  final String statusLabel;
  final RequestStatus requestStatus;
  final String? managerFullName;
  final String? external1cId;

  String get displayCarLine {
    final a = carMake.trim();
    final b = carModel.trim();
    if (a.isEmpty && b.isEmpty) {
      return '—';
    }
    if (a.isEmpty) {
      return b;
    }
    if (b.isEmpty) {
      return a;
    }
    return '$a $b';
  }
}
