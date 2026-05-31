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
    this.hasUnreadChat = false,
    this.hasStatusUpdate = false,
    this.hasDocsAction = false,
    this.statusUpdateSummary,
    this.pendingActionHints = const [],
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
  final bool hasUnreadChat;
  final bool hasStatusUpdate;
  final bool hasDocsAction;
  final String? statusUpdateSummary;

  /// Что нужно сделать в заявке (подпись, чек…) — из данных item, не только push.
  final List<String> pendingActionHints;

  bool get hasPendingActions => pendingActionHints.isNotEmpty;

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
