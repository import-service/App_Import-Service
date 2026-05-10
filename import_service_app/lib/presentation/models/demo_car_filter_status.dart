enum DemoCarFilterStatus {
  invoicePayment('Оплата инвойса'),
  factoryProduction('Изготовление на заводе'),
  chinaProcessing('Оформление Китай'),
  chinaInTransit('В пути Китай'),
  ussuriyskTransit('Транзит до Уссурийска'),
  customsWarehouse('СВХ'),
  waitingOriginals('Ждем оригиналы'),
  expertise('Экспертиза'),
  russiaProcessing('Оформление Россия'),
  resubmission('Переподача'),
  receipts('Квитанции'),
  release('Выпуск'),
  customsWarehouseExit('Выход с СВХ'),
  laboratory('Лаборатория'),
  russiaInTransit('В пути Россия'),
  completed('Выполнен');

  const DemoCarFilterStatus(this.label);

  final String label;
}
