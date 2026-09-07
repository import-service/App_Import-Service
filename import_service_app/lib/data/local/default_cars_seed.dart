import 'package:import_service_app/core/constants/customs_catalog.dart';
import 'package:import_service_app/data/demo/demo_seed_files.dart';
import 'package:import_service_app/domain/entities/car_list_item.dart';
import 'package:import_service_app/domain/entities/deal_type.dart';
import 'package:import_service_app/domain/entities/request_status.dart';

/// Сид демо МП: те же секции/docType/поля, что в боевом флоу (моки).
final class DefaultCarsSeed {
  DefaultCarsSeed._();

  static List<CarListItem> get items => [
        _newRequest,
        _onReview,
        _bilateralSigning,
        _cashSigning,
        _tripartiteSigning,
        _quadripartiteSigning,
        _inTransitFull,
        _delivered,
        _closed,
      ];

  static final CarListItem _newRequest = CarListItem(
    id: 'seed_demo_new',
    ownerFullName: 'Демо Новая заявка',
    carMake: 'Lada',
    carModel: 'Vesta',
    vin: 'XTA217440R0000001',
    status: RequestStatus.newRequest,
    engineSpec: 'Бензин / 1.6 л / 106 л.с.',
    engineVolume: 'V — 1596 см³',
    statusSubTypeDateTime: '2026-05-01T10:00:00+03:00',
    files: demoCreationFiles(),
  );

  static final CarListItem _onReview = CarListItem(
    id: 'seed_demo_on_review',
    ownerFullName: 'Демо На рассмотрении',
    carMake: 'Toyota',
    carModel: 'Camry',
    vin: 'JTDBR32E123456789',
    status: RequestStatus.onReview,
    external1cId: 'GUID-DEMO-ON-REVIEW',
    statusSubTypeDateTime: '2026-05-02T10:00:00+03:00',
    files: demoCreationFiles(),
  );

  static CarListItem _signingCar({
    required String id,
    required String owner,
    required String make,
    required String model,
    required String vin,
    required DealType dealType,
    required String manager,
    String? externalSuffix,
  }) {
    return CarListItem(
      id: id,
      ownerFullName: owner,
      carMake: make,
      carModel: model,
      vin: vin,
      status: RequestStatus.inProgress,
      external1cId: 'GUID-DEMO-${externalSuffix ?? dealType.apiCode}'.toUpperCase(),
      managerFullName: manager,
      statusSubType: 'primary_documents_sent',
      statusSubTypeDateTime: '2026-05-10T12:00:00+03:00',
      dealType: dealType.apiCode,
      advancePayment: '500000.00',
      actualPayment: '0.00',
      refundAmount: '500000.00',
      engineSpec: 'Бензин / 2.0 л',
      engineVolume: 'V — 1998 см³',
      files: mergeDemoFiles([
        demoCreationFiles(),
        demoSigningFiles(dealType, includeSigned: false),
      ]),
    );
  }

  static final CarListItem _bilateralSigning = _signingCar(
    id: 'seed_demo_bilateral',
    owner: 'Демо Двухсторонняя',
    make: 'Hyundai',
    model: 'Sonata',
    vin: 'KMHEC41B1XA000001',
    dealType: DealType.bilateral,
    manager: 'Иванова Анна Петровна',
  );

  static final CarListItem _cashSigning = _signingCar(
    id: 'seed_demo_cash',
    owner: 'Демо Наличный расчёт',
    make: 'Kia',
    model: 'K5',
    vin: 'KNAGN412345000002',
    dealType: DealType.cash,
    manager: 'Петров Сергей Игоревич',
  );

  static final CarListItem _tripartiteSigning = _signingCar(
    id: 'seed_demo_tripartite',
    owner: 'Демо Трёхсторонняя',
    make: 'CHANGAN',
    model: 'Uni-K',
    vin: 'LS5A3CKE5SA310003',
    dealType: DealType.tripartite,
    manager: 'Петрова Мария Сергеевна',
  );

  static final CarListItem _quadripartiteSigning = _signingCar(
    id: 'seed_demo_quadripartite',
    owner: 'Демо Четырёхсторонняя',
    make: 'Geely',
    model: 'Monjaro',
    vin: 'L6T79XES0N0000004',
    dealType: DealType.quadripartite,
    manager: 'Сидоров Алексей Петрович',
  );

  /// В пути: создание + подпись (bilateral) + оплаты + архив.
  static final CarListItem _inTransitFull = CarListItem(
    id: 'seed_demo_in_transit',
    ownerFullName: 'Демо В пути',
    carMake: 'Li',
    carModel: 'ONE',
    vin: 'LW433B103M1013122',
    status: RequestStatus.inTransit,
    external1cId: 'GUID-DEMO-IN-TRANSIT',
    engineSpec: 'Гибрид / 131 л.с.',
    engineVolume: 'V — 1199 см³',
    statusSubType: 'originals_complete_transit',
    statusSubTypeDateTime: '2026-05-15T10:00:00+03:00',
    managerFullName: 'Козлов Дмитрий Викторович',
    dealType: DealType.bilateral.apiCode,
    advancePayment: '830998.00',
    actualPayment: '750000.00',
    refundAmount: '80998.00',
    files: mergeDemoFiles([
      demoCreationFiles(),
      demoSigningFiles(DealType.bilateral, includeSigned: true),
      demoPaymentFiles(withReceipts: true),
      demoTransitArchiveFiles(),
    ]),
  );

  static final CarListItem _delivered = CarListItem(
    id: 'seed_demo_delivered',
    ownerFullName: 'Демо Доставлено',
    carMake: 'BMW',
    carModel: 'X3',
    vin: 'WBAXXXXXXXX000005',
    status: RequestStatus.delivered,
    external1cId: 'GUID-DEMO-DELIVERED',
    managerFullName: 'Козлов Дмитрий Викторович',
    statusSubType: 'issued_to_client',
    statusSubTypeDateTime: '2026-05-20T10:00:00+03:00',
    dealType: DealType.tripartite.apiCode,
    advancePayment: '900000.00',
    actualPayment: '880000.00',
    refundAmount: '20000.00',
    files: mergeDemoFiles([
      demoCreationFiles(includeOptional: false),
      demoSigningFiles(DealType.tripartite, includeSigned: true),
      demoPaymentFiles(withReceipts: true),
      demoTransitArchiveFiles(),
      demoFinalFiles(),
    ]),
  );

  static final CarListItem _closed = CarListItem(
    id: 'seed_demo_closed',
    ownerFullName: 'Демо Закрыта',
    carMake: 'Mercedes',
    carModel: 'CLA',
    vin: 'W1K5J8HB9LN132222',
    status: RequestStatus.closed,
    external1cId: 'GUID-DEMO-CLOSED',
    engineSpec: 'Бензин / 163 л.с.',
    engineVolume: 'V — 1332 см³',
    statusSubType: 'request_closed',
    statusSubTypeDateTime: '2026-05-25T10:00:00+03:00',
    managerFullName: 'Козлов Дмитрий Викторович',
    dealType: DealType.cash.apiCode,
    advancePayment: '291000.00',
    actualPayment: '285000.00',
    refundAmount: '6000.00',
    files: mergeDemoFiles([
      demoCreationFiles(includeOptional: false),
      demoSigningFiles(DealType.cash, includeSigned: true),
      demoPaymentFiles(withReceipts: true),
      demoTransitArchiveFiles(),
      demoFinalFiles(),
    ]),
  );
}
