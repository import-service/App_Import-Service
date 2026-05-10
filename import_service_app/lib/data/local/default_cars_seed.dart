import 'package:import_service_app/domain/entities/car_list_item.dart';
import 'package:import_service_app/domain/entities/delivered_vehicle_document.dart';
import 'package:import_service_app/domain/entities/request_status.dart';
import 'package:import_service_app/domain/entities/vehicle_finance_item.dart';

/// Сид: те же поля, что ждёт клиент с API. Демо-URL примеры; в проде с бэка/1С.
final class DefaultCarsSeed {
  DefaultCarsSeed._();

  static const List<CarListItem> items = <CarListItem>[
    CarListItem(
      id: 'seed_demo_vesta',
      ownerFullName: 'Тютчев Федор Иванович',
      carMake: 'Lada',
      carModel: 'Vesta',
      vin: 'XTA217440R0000003',
      status: RequestStatus.newRequest,
      engineSpec: 'Бензин / 1.6 л / 106 л.с. / 4 цил.',
      engineVolume: 'V — 1998 см³',
      statusSinceDateLabel: '11.04.2025',
    ),
    CarListItem(
      id: 'seed_demo_uni_k',
      ownerFullName: 'Тютчев Федор Иванович',
      carMake: 'CHANGAN',
      carModel: 'Uni-k',
      vin: 'LS5A3CKE5SA310003',
      status: RequestStatus.inProgress,
    ),
    CarListItem(
      id: 'seed_demo_camry',
      ownerFullName: 'Жуковский Василий Андреевич',
      carMake: 'Li',
      carModel: 'ONE',
      vin: 'LW433B103M1013122',
      status: RequestStatus.inTransit,
      engineSpec: 'Гибридный на основе бензинового / 96 квт / 131 л.с.',
      engineVolume: 'V — 1199 см³',
      statusSinceDateLabel: '02.04.2025',
      statusSubType: 'in_transit_loading',
      financeItems: [
        VehicleFinanceItem(
          lineType: 'customs_duty',
          amountText: '830 998,00 ₽',
          paymentQrUrl: 'https://www.example.com/pay/customs',
        ),
        VehicleFinanceItem(
          lineType: 'recycling_fee',
          amountText: '3 200,00 ₽',
          paymentQrUrl: 'https://www.example.com/pay/ut',
        ),
      ],
      vehiclePhotoUrls: <String>[],
    ),
    CarListItem(
      id: 'seed_demo_lixiang',
      ownerFullName: 'Лермонтов Михаил Юрьевич',
      carMake: 'Mercedes',
      carModel: 'CLA',
      vin: 'W1K5J8HB9LN132222',
      status: RequestStatus.delivered,
      engineSpec: 'Бензиновый / 120 кВт / 163 л.с.',
      engineVolume: 'V — 1332 см³',
      statusSinceDateLabel: '11.04.2025',
      statusSubType: 'delivered_temporary_storage',
      financeItems: [
        VehicleFinanceItem(
          lineType: 'customs_duty',
          amountText: '291 000,00 ₽',
          paymentQrUrl: 'https://www.example.com/pay/customs',
        ),
        VehicleFinanceItem(
          lineType: 'recycling_fee',
          amountText: '5 200,00 ₽',
          paymentQrUrl: 'https://www.example.com/pay/ut',
        ),
      ],
      vehiclePhotoUrls: <String>[],
      deliveredDocuments: [
        DeliveredVehicleDocument(
          title: 'СБКТС',
          downloadUrl: 'https://www.example.com/docs/sbcts',
        ),
        DeliveredVehicleDocument(
          title: 'ЭПТС',
          downloadUrl: 'https://www.example.com/docs/epts',
        ),
        DeliveredVehicleDocument(
          title: 'ТПО',
          downloadUrl: 'https://www.example.com/docs/tpo',
        ),
        DeliveredVehicleDocument(
          title: 'ПТД',
          downloadUrl: 'https://www.example.com/docs/ptd',
        ),
      ],
    ),
  ];
}
