import 'package:flutter/material.dart';
import 'package:import_service_app/core/themes/app_theme.dart';
import 'package:import_service_app/domain/entities/request_status.dart';

/// Стили чипа статуса на карточке в списке. Единая точка для [RequestStatus] (красный фон, белый текст).
/// При вариации по статусу — правьте геттеры ниже.
extension RequestStatusListStyle on RequestStatus {
  Color get listChipBackground => AppTheme.accentRed;

  Color get listChipForeground => AppTheme.white;
}
