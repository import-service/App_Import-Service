import 'package:flutter/foundation.dart';
import 'package:import_service_app/domain/entities/request_status.dart';

/// Навигация на главной после push: нижний таб «Мои авто» + чип статуса.
final class HomeCarsNavigationController extends ChangeNotifier {
  bool _focusCarsTab = false;
  int? _statusFilterIndex;

  bool get focusCarsTab => _focusCarsTab;

  int? get statusFilterIndex => _statusFilterIndex;

  void focusCarsListForStatus(RequestStatus status) {
    _focusCarsTab = true;
    _statusFilterIndex = status.carsListTabIndex;
    notifyListeners();
  }
}
