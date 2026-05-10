import 'package:import_service_app/data/local/default_cars_seed.dart';
import 'package:import_service_app/presentation/models/demo_car.dart';

/// Имитация ответа API GET `/vehicles` для демо-пользователя (не реальный HTTP).
///
/// Данные совпадают с [DefaultCarsSeed]; в приложении — [CarInventoryCubit].
final class DemoCarsRemoteMock {
  DemoCarsRemoteMock._();

  static const Duration _latency = Duration(milliseconds: 380);

  /// Список автомобилей «как с сервера». Поле [DemoCar.status] при показе подставляется
  /// под выбранный фильтр вкладки (клиентское поведение списка).
  static Future<List<DemoCar>> fetchVehicles() async {
    await Future<void>.delayed(_latency);
    return DefaultCarsSeed.items
        .map(
          (e) => DemoCar(
            id: e.id,
            ownerFullName: e.ownerFullName,
            carMake: e.carMake,
            carModel: e.carModel,
            vin: e.vin,
            statusLabel: '',
            requestStatus: e.status,
          ),
        )
        .toList(growable: false);
  }
}
