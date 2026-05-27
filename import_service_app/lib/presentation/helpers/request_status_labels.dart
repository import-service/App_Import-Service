import 'package:import_service_app/core/i18n/json_strings_service.dart';
import 'package:import_service_app/domain/entities/request_status.dart';

/// Подпись верхнего статуса для UI (без [statusSubType]).
String requestStatusLabel(RequestStatus status, JsonStringsService s) {
  switch (status) {
    case RequestStatus.newRequest:
      return s.carStatusNew;
    case RequestStatus.onReview:
      return s.carStatusOnReview;
    case RequestStatus.inProgress:
      return s.carStatusInWork;
    case RequestStatus.inTransit:
      return s.carStatusOnWay;
    case RequestStatus.delivered:
      return s.carStatusDelivered;
    case RequestStatus.closed:
      return s.carStatusClosed;
    case RequestStatus.cancelled:
      return s.carStatusCancelled;
  }
}

/// Первая вкладка списка «В работе».
bool requestStatusInWorkTab(RequestStatus status) {
  return status == RequestStatus.newRequest ||
      status == RequestStatus.onReview ||
      status == RequestStatus.inProgress;
}

/// Третья вкладка «Доставлено» (+ закрыта/отменена).
bool requestStatusDeliveredTab(RequestStatus status) {
  return status == RequestStatus.delivered ||
      status == RequestStatus.closed ||
      status == RequestStatus.cancelled;
}

/// Чат доступен после привязки к 1С.
bool requestChatAvailable(String? external1cId) {
  return external1cId != null && external1cId.trim().isNotEmpty;
}
