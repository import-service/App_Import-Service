import 'package:import_service_app/domain/entities/car_list_item.dart';
import 'package:import_service_app/domain/entities/customs_request_file.dart';
import 'package:import_service_app/domain/entities/delivered_vehicle_document.dart';
import 'package:import_service_app/domain/entities/request_status.dart';
import 'package:import_service_app/domain/entities/vehicle_finance_item.dart';

/// Сид: те же поля, что ждёт клиент с API. Демо-URL примеры; в проде с бэка/1С.
final class DefaultCarsSeed {
  DefaultCarsSeed._();

  static const _demoFileBase = 'https://www.example.com/demo/files';

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
      files: [
        CustomsRequestFile(
          docType: 'passport_front',
          fileName: 'passport-front.jpg',
          fileUrl: '$_demoFileBase/passport-front.jpg',
        ),
        CustomsRequestFile(
          docType: 'invoice',
          fileName: 'invoice.pdf',
          fileUrl: '$_demoFileBase/invoice.pdf',
        ),
        CustomsRequestFile(
          docType: 'contract',
          fileName: 'contract.pdf',
          fileUrl: '$_demoFileBase/contract-create.pdf',
        ),
      ],
    ),
    CarListItem(
      id: 'seed_demo_uni_k',
      ownerFullName: 'Тютчев Федор Иванович',
      carMake: 'CHANGAN',
      carModel: 'Uni-k',
      vin: 'LS5A3CKE5SA310003',
      status: RequestStatus.inProgress,
      external1cId: 'GUID-DEMO-UNI-K',
      managerFullName: 'Петрова Мария Сергеевна',
      statusSubType: 'primary_documents_sent',
      files: [
        CustomsRequestFile(
          docType: 'contract',
          fileName: 'contract-pack.pdf',
          fileUrl: '$_demoFileBase/contract-pack.pdf',
        ),
        CustomsRequestFile(
          docType: 'kuts',
          fileName: 'kuts.pdf',
          fileUrl: '$_demoFileBase/kuts.pdf',
        ),
        CustomsRequestFile(
          docType: 'payment_recycling_fee',
          fileName: 'recycling-fee.pdf',
          fileUrl: '$_demoFileBase/recycling-fee.pdf',
        ),
      ],
    ),
    CarListItem(
      id: 'seed_demo_camry',
      ownerFullName: 'Жуковский Василий Андреевич',
      carMake: 'Li',
      carModel: 'ONE',
      vin: 'LW433B103M1013122',
      status: RequestStatus.inTransit,
      external1cId: 'GUID-DEMO-CAMRY',
      engineSpec: 'Гибридный на основе бензинового / 96 квт / 131 л.с.',
      engineVolume: 'V — 1199 см³',
      statusSinceDateLabel: '02.04.2025',
      statusSubType: 'originals_missing_transit',
      managerFullName: 'Сидоров Алексей Петрович',
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
      vehiclePhotoUrls: [
        '$_demoFileBase/transit-photo-1.jpg',
        '$_demoFileBase/transit-photo-2.jpg',
      ],
      files: [
        CustomsRequestFile(
          docType: 'transit_archive_photo',
          fileName: 'transit-1.jpg',
          fileUrl: '$_demoFileBase/transit-archive-1.jpg',
        ),
        CustomsRequestFile(
          docType: 'transit_archive_video',
          fileName: 'transit.mp4',
          fileUrl: '$_demoFileBase/transit-archive.mp4',
        ),
        CustomsRequestFile(
          docType: 'contract_sign',
          fileName: 'contract-signed.pdf',
          fileUrl: '$_demoFileBase/contract-signed.pdf',
        ),
        CustomsRequestFile(
          docType: 'payment_customs_duty',
          fileName: 'customs-duty.pdf',
          fileUrl: '$_demoFileBase/customs-duty.pdf',
        ),
      ],
    ),
    CarListItem(
      id: 'seed_demo_lixiang',
      ownerFullName: 'Лермонтов Михаил Юрьевич',
      carMake: 'Mercedes',
      carModel: 'CLA',
      vin: 'W1K5J8HB9LN132222',
      status: RequestStatus.closed,
      external1cId: 'GUID-DEMO-LIXIANG',
      engineSpec: 'Бензиновый / 120 кВт / 163 л.с.',
      engineVolume: 'V — 1332 см³',
      statusSinceDateLabel: '11.04.2025',
      statusSubType: 'request_closed',
      managerFullName: 'Козлов Дмитрий Викторович',
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
      files: [
        CustomsRequestFile(
          docType: 'epts',
          fileName: 'epts.pdf',
          fileUrl: 'https://www.example.com/docs/epts',
        ),
      ],
    ),
    CarListItem(
      id: 'seed_demo_on_review',
      ownerFullName: 'Демо На рассмотрении',
      carMake: 'Toyota',
      carModel: 'Camry',
      vin: 'JTDBR32E123456789',
      status: RequestStatus.onReview,
      external1cId: 'GUID-DEMO-ON-REVIEW',
      statusSinceDateLabel: '20.05.2026',
    ),
  ];
}
