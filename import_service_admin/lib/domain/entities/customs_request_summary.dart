import 'package:equatable/equatable.dart';

class CustomsRequestSummary extends Equatable {
  const CustomsRequestSummary({
    required this.id,
    required this.ownerFullName,
    required this.carMake,
    required this.carModel,
    required this.vin,
    required this.status,
    this.statusSinceDateLabel,
    this.isTest = false,
    this.managerFullName,
    this.external1cId,
    this.oneCUpdatePending = false,
  });

  final String id;
  final String ownerFullName;
  final String carMake;
  final String carModel;
  final String vin;
  final String status;
  final String? statusSinceDateLabel;
  final bool isTest;
  final String? managerFullName;
  final String? external1cId;
  final bool oneCUpdatePending;

  String get carTitle => '$carMake $carModel'.trim();

  bool get canSendTo1C =>
      status == 'new' &&
      (external1cId == null || external1cId!.trim().isEmpty);

  bool get canResendUpdateTo1C =>
      oneCUpdatePending &&
      external1cId != null &&
      external1cId!.trim().isNotEmpty;

  @override
  List<Object?> get props => [id, status, oneCUpdatePending];
}
