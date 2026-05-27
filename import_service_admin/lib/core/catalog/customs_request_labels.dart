// Подписи кодов заявки (синхрон с docs/catalog-reference.md и customsCatalog.js).

const Map<String, String> kRequestStatusLabels = {
  'new': 'Новая',
  'on_review': 'На рассмотрении',
  'in_progress': 'В работе',
  'in_transit': 'В пути',
  'delivered': 'Доставлена',
  'closed': 'Закрыта',
  'cancelled': 'Отменена',
};

const Map<String, String> kDealTypeLabels = {
  'bilateral': 'Двухсторонняя сделка',
  'cash': 'Наличный расчёт',
  'tripartite': 'Трёхсторонняя сделка',
  'quadripartite': 'Четырёхсторонняя сделка',
};

const Map<String, String> kFinanceLineTypeLabels = {
  'recycling_fee': 'Утилизационный сбор',
  'customs_duty': 'Госпошлина',
};

const Map<String, String> kStatusSubTypeLabels = {
  'draft': 'Черновик',
  'manager_execution': 'На исполнении у менеджера',
  'primary_documents_sent': 'Отправлены первичные документы',
  'originals_partial_no_transit':
      'Получены оригиналы (не все документы), нет транзита',
  'originals_complete_no_transit':
      'Получены оригиналы (все документы), нет транзита',
  'signature_revision_required': 'Требуется переподпись документов',
  'originals_missing_transit': 'Оригиналы отсутствуют, есть транзит',
  'originals_partial_transit':
      'Получены оригиналы (не все документы), есть транзит',
  'originals_complete_transit':
      'Получены оригиналы (все документы), есть транзит',
  'svh_no_originals_no_recycling':
      'Авто на СВХ, оригиналы отсутствуют, нет утиля',
  'svh_partial_docs_no_recycling':
      'Авто на СВХ, не все документы, нет утиля',
  'svh_no_originals_recycling':
      'Авто на СВХ, оригиналы отсутствуют, есть утиль',
  'svh_partial_docs_recycling':
      'Авто на СВХ, не все документы, есть утиль',
  'svh_all_docs_no_recycling': 'Авто на СВХ, все документы, нет утиля',
  'svh_all_docs_recycling': 'Авто на СВХ, все документы, есть утиль',
  'ptd_submitted': 'Подана ПТД',
  'ptd_submitted_paid': 'Подана ПТД с оплатой',
  'ptd_release': 'Выпуск ПТД',
  'sent_to_lab': 'Направлено в лабораторию',
  'issued_to_client': 'Выдано клиенту',
  'request_closed': 'Заявка закрыта',
  'manager_assigned': 'На исполнении у менеджера',
};

const Map<String, String> kDocTypeLabels = {
  'passport_front': 'Паспорт, лицевая',
  'passport_registration': 'Паспорт, прописка',
  'inn': 'ИНН',
  'snils': 'СНИЛС',
  'invoice': 'Инвойс',
  'contract': 'Контракт',
  'payment_check': 'Чек оплаты за авто',
  'car_nameplate_photo': 'Фото шильдика (VIN)',
  'car_mileage_photo': 'Фото пробега',
  'car_front_photo': 'Фото спереди',
  'car_back_photo': 'Фото сзади',
  'add_doc1': 'Доп. документ 1',
  'add_doc2': 'Доп. документ 2',
  'recycling_fee_calc': 'Расчёт утилизационного сбора',
  'kuts': 'КУТС',
  'explanatory_note': 'Пояснение',
  'customs_rep_agreement': 'Договор таможенного представителя',
  'funds_transfer_application':
      'Заявление на перевод остатков после растаможивания',
  'passport_notarized_copy': 'Паспорт (нотариальная копия)',
  'receipt': 'Расписка',
  'additional_agreement': 'Дополнительное соглашение',
  'tripartite_agreement': 'Трёхсторонний договор',
  'quadripartite_agreement': 'Четырёхсторонний договор',
  'payment_recycling_fee': 'Квитанция утилизационного сбора',
  'payment_recycling_fee_receipt': 'Чек оплаты утилизационного сбора',
  'payment_customs_duty': 'Квитанция госпошлины',
  'payment_customs_duty_receipt': 'Чек оплаты госпошлины',
  'epts': 'ЭПТС',
  'sbkts': 'СБКТС',
  'uploaded_file': 'Загруженный файл',
  'title_doc': 'Инвойс (устар.)',
  'additional_file': 'Доп. файл (устар.)',
  'transport_application': 'Заявление на перевод (устар.)',
};

String requestStatusLabel(String code) =>
    kRequestStatusLabels[code] ?? code;

String statusSubTypeLabel(String? code) {
  final c = (code ?? '').trim();
  if (c.isEmpty) return '—';
  return kStatusSubTypeLabels[c] ?? c;
}

String dealTypeLabel(String? code) {
  final c = (code ?? '').trim();
  if (c.isEmpty) return '—';
  return kDealTypeLabels[c] ?? c;
}

String docTypeLabel(String? code, {String? fileName}) {
  var c = (code ?? '').trim();
  if (c.endsWith('_sign')) {
    final base = c.substring(0, c.length - 5);
    return '${docTypeLabel(base)} (подпись)';
  }
  switch (c) {
    case 'title_doc':
      c = 'invoice';
      break;
    case 'transport_application':
      c = 'funds_transfer_application';
      break;
  }
  final label = kDocTypeLabels[c];
  if (label != null) return label;
  final name = (fileName ?? '').trim();
  return name.isNotEmpty ? name : (c.isNotEmpty ? c : 'Файл');
}

String financeLineLabel({
  required String lineType,
  String? title,
}) {
  final t = (title ?? '').trim();
  if (t.isNotEmpty) return t;
  return kFinanceLineTypeLabels[lineType] ?? lineType;
}

String yesNoLabel(bool value) => value ? 'Да' : 'Нет';

String formatDateTimeLabel(String? iso) {
  if (iso == null || iso.trim().isEmpty) return '—';
  final d = DateTime.tryParse(iso);
  if (d == null) return iso;
  final l = d.toLocal();
  final dd = l.day.toString().padLeft(2, '0');
  final mm = l.month.toString().padLeft(2, '0');
  final hh = l.hour.toString().padLeft(2, '0');
  final min = l.minute.toString().padLeft(2, '0');
  return '$dd.$mm.${l.year} $hh:$min';
}
