import 'package:flutter/material.dart';
import 'package:import_service_app/core/themes/app_theme.dart';
import 'package:import_service_app/domain/entities/request_status.dart';

/// Стили чипа статуса на карточке в списке. Единая точка для [RequestStatus] (красный фон, белый текст).
/// При вариации по статусу — правьте геттеры ниже.
extension RequestStatusListStyle on RequestStatus {
  Color get listChipBackground {
    switch (this) {
      case RequestStatus.newRequest:
        return const Color(0xFF2962FF);
      case RequestStatus.onReview:
        return const Color(0xFFF9A825);
      case RequestStatus.inProgress:
        return AppTheme.accentRed;
      case RequestStatus.inTransit:
        return const Color(0xFF7E57C2);
      case RequestStatus.delivered:
        return const Color(0xFF2E7D32);
      case RequestStatus.closed:
        return const Color(0xFF546E7A);
      case RequestStatus.cancelled:
        return const Color(0xFF455A64);
    }
  }

  Color get listChipForeground => AppTheme.white;
}
