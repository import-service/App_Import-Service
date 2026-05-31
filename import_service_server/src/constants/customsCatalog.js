/**
 * Справочники заявки: подстатусы 1С, docType, dealType.
 * Синхронизировать с docs/api-1c.md и /docs (api.html).
 */

const DEAL_TYPES = ['bilateral', 'cash', 'tripartite', 'quadripartite'];

/** Подстатусы 1С — машинные коды (поле statusSubType в state). */
const STATUS_SUB_TYPES = [
  // На проверке (верхний status: on_review)
  {
    code: 'draft',
    label: 'Черновик',
    group: 'on_review',
    status: 'on_review',
  },
  // В работе (in_progress)
  {
    code: 'manager_execution',
    label: 'На исполнении у менеджера',
    group: 'in_progress',
    status: 'in_progress',
  },
  {
    code: 'primary_documents_sent',
    label: 'Отправлены первичные документы',
    group: 'in_progress',
    status: 'in_progress',
  },
  {
    code: 'originals_partial_no_transit',
    label: 'Получены оригиналы (не все документы), нет транзита',
    group: 'in_progress',
    status: 'in_progress',
  },
  {
    code: 'originals_complete_no_transit',
    label: 'Получены оригиналы (все документы), нет транзита',
    group: 'in_progress',
    status: 'in_progress',
  },
  {
    code: 'signature_revision_required',
    label: 'Требуется переподпись документов',
    group: 'in_progress',
    status: 'in_progress',
  },
  // В пути (in_transit)
  {
    code: 'originals_missing_transit',
    label: 'Оригиналы отсутствуют, есть транзит',
    group: 'in_transit',
    status: 'in_transit',
  },
  {
    code: 'originals_partial_transit',
    label: 'Получены оригиналы (не все документы), есть транзит',
    group: 'in_transit',
    status: 'in_transit',
  },
  {
    code: 'originals_complete_transit',
    label: 'Получены оригиналы (все документы), есть транзит',
    group: 'in_transit',
    status: 'in_transit',
  },
  // Доставлено (delivered / closed)
  {
    code: 'svh_no_originals_no_recycling',
    label: 'Авто на СВХ, оригиналы отсутствуют, нет утиля',
    group: 'delivered',
    status: 'delivered',
  },
  {
    code: 'svh_partial_docs_no_recycling',
    label: 'Авто на СВХ, не все документы, нет утиля',
    group: 'delivered',
    status: 'delivered',
  },
  {
    code: 'svh_no_originals_recycling',
    label: 'Авто на СВХ, оригиналы отсутствуют, есть утиль',
    group: 'delivered',
    status: 'delivered',
  },
  {
    code: 'svh_partial_docs_recycling',
    label: 'Авто на СВХ, не все документы, есть утиль',
    group: 'delivered',
    status: 'delivered',
  },
  {
    code: 'svh_all_docs_no_recycling',
    label: 'Авто на СВХ, все документы, нет утиля',
    group: 'delivered',
    status: 'delivered',
  },
  {
    code: 'svh_all_docs_recycling',
    label: 'Авто на СВХ, все документы, есть утиль',
    group: 'delivered',
    status: 'delivered',
  },
  {
    code: 'ptd_submitted',
    label: 'Подана ПТД',
    group: 'delivered',
    status: 'delivered',
  },
  {
    code: 'ptd_submitted_paid',
    label: 'Подана ПТД с оплатой',
    group: 'delivered',
    status: 'delivered',
  },
  {
    code: 'ptd_release',
    label: 'Выпуск ПТД',
    group: 'delivered',
    status: 'delivered',
  },
  {
    code: 'sent_to_lab',
    label: 'Направлено в лабораторию',
    group: 'delivered',
    status: 'delivered',
  },
  {
    code: 'issued_to_client',
    label: 'Выдано клиенту',
    group: 'delivered',
    status: 'delivered',
  },
  {
    code: 'request_closed',
    label: 'Заявка закрыта',
    group: 'delivered',
    status: 'closed',
  },
];

const STATUS_SUB_TYPE_CODES = STATUS_SUB_TYPES.map((x) => x.code);

const STATUS_SUB_TYPE_BY_CODE = Object.fromEntries(STATUS_SUB_TYPES.map((x) => [x.code, x]));

/** Полный перечень docType, встречающихся в заявке. */
const DOCUMENT_TYPES = [
  // Создание заявки (МП → сервер → 1С)
  { code: 'passport_front', label: 'Паспорт, лицевая', category: 'creation', requiredOnCreate: true },
  { code: 'passport_registration', label: 'Паспорт, прописка', category: 'creation', requiredOnCreate: true },
  { code: 'inn', label: 'ИНН', category: 'creation', requiredOnCreate: true },
  { code: 'snils', label: 'СНИЛС', category: 'creation', requiredOnCreate: true },
  { code: 'invoice', label: 'Инвойс', category: 'creation', requiredOnCreate: true },
  { code: 'contract', label: 'Контракт (при создании)', category: 'creation', requiredOnCreate: true },
  { code: 'payment_check', label: 'Чек оплаты за авто', category: 'creation', requiredOnCreate: true },
  { code: 'car_nameplate_photo', label: 'Фото шильдика (VIN)', category: 'creation', requiredOnCreate: true },
  { code: 'car_mileage_photo', label: 'Фото пробега', category: 'creation', requiredOnCreate: true },
  { code: 'car_front_photo', label: 'Фото спереди', category: 'creation', requiredOnCreate: true },
  { code: 'car_back_photo', label: 'Фото сзади', category: 'creation', requiredOnCreate: true },
  { code: 'add_doc1', label: 'Доп. документ 1', category: 'creation', requiredOnCreate: false },
  { code: 'add_doc2', label: 'Доп. документ 2', category: 'creation', requiredOnCreate: false },
  // Пакет на подпись (1С → МП, оригинал; МП → 1С — *_sign)
  { code: 'recycling_fee_calc', label: 'Расчёт утилизационного сбора', category: 'signing' },
  { code: 'kuts', label: 'КУТС', category: 'signing' },
  { code: 'explanatory_note', label: 'Пояснение', category: 'signing' },
  { code: 'customs_rep_agreement', label: 'Договор таможенного представителя', category: 'signing' },
  {
    code: 'funds_transfer_application',
    label: 'Заявление на перевод остатков средств (после растаможивания)',
    category: 'signing',
    clientSignOnly: true,
  },
  {
    code: 'passport_notarized_copy',
    label: 'Паспорт (нотариальная копия)',
    category: 'signing',
    clientSignOnly: true,
  },
  { code: 'receipt', label: 'Расписка', category: 'signing', dealTypes: ['cash'] },
  { code: 'additional_agreement', label: 'Дополнительное соглашение', category: 'signing', dealTypes: ['cash'] },
  { code: 'tripartite_agreement', label: 'Трёхсторонний договор', category: 'signing', dealTypes: ['tripartite'] },
  { code: 'quadripartite_agreement', label: 'Четырёхсторонний договор', category: 'signing', dealTypes: ['quadripartite'] },
  // Оплаты
  { code: 'payment_recycling_fee', label: 'Квитанция утилизационного сбора (1С → МП)', category: 'payment' },
  { code: 'payment_recycling_fee_receipt', label: 'Чек оплаты утилизационного сбора (МП → 1С)', category: 'payment' },
  { code: 'payment_customs_duty', label: 'Квитанция госпошлины (1С → МП)', category: 'payment' },
  { code: 'payment_customs_duty_receipt', label: 'Чек оплаты госпошлины (МП → 1С)', category: 'payment' },
  // Итоговые документы
  { code: 'epts', label: 'ЭПТС', category: 'final' },
  { code: 'sbkts', label: 'СБКТС', category: 'final' },
  // Архив перед транзитом (1С → МП, только скачивание; несколько фото — суффикс _1, _2, …)
  {
    code: 'transit_archive_photo',
    label: 'Фото архива перед транзитом (базовый код; при нескольких — transit_archive_photo_1, _2, …)',
    category: 'transit_archive',
  },
  { code: 'transit_archive_video', label: 'Видео архива перед транзитом', category: 'transit_archive' },
  // Служебный
  { code: 'uploaded_file', label: 'Ошибка: upload без docType (не использовать)', category: 'other' },
];

const REQUIRED_DOCUMENT_TYPES_ON_CREATE = DOCUMENT_TYPES.filter((d) => d.requiredOnCreate).map(
  (d) => d.code,
);

const DOCUMENT_TYPE_CODES = DOCUMENT_TYPES.map((d) => d.code);

/** Старые коды подстатусов → актуальные (обратная совместимость). */
const LEGACY_STATUS_SUB_TYPE_ALIASES = {
  manager_assigned: 'manager_execution',
};

function normalizeDocType(docType) {
  return String(docType ?? '').trim();
}

function isKnownDocType(docType) {
  const code = normalizeDocType(docType);
  if (!code) return false;
  if (DOCUMENT_TYPE_CODES.includes(code)) return true;
  if (/_sign$/.test(code)) {
    const base = code.replace(/_sign$/, '');
    return DOCUMENT_TYPE_CODES.includes(base);
  }
  if (/^transit_archive_photo_\d+$/.test(code)) return true;
  return false;
}

function normalizeStatusSubType(code) {
  const raw = String(code ?? '').trim();
  if (!raw) return '';
  const mapped = LEGACY_STATUS_SUB_TYPE_ALIASES[raw] || raw;
  return mapped;
}

function isKnownStatusSubType(code) {
  const normalized = normalizeStatusSubType(code);
  return Boolean(STATUS_SUB_TYPE_BY_CODE[normalized]);
}

function suggestedStatusForSubType(code) {
  const normalized = normalizeStatusSubType(code);
  return STATUS_SUB_TYPE_BY_CODE[normalized]?.status;
}

function statusSubTypeLabel(code) {
  return STATUS_SUB_TYPE_BY_CODE[String(code ?? '').trim()]?.label || '';
}

/** Суффикс подписи для docType пакета на подпись. */
function signedDocType(baseDocType) {
  const base = normalizeDocType(baseDocType);
  if (!base || base.endsWith('_sign')) return base;
  return `${base}_sign`;
}

module.exports = {
  DEAL_TYPES,
  STATUS_SUB_TYPES,
  STATUS_SUB_TYPE_CODES,
  STATUS_SUB_TYPE_BY_CODE,
  DOCUMENT_TYPES,
  DOCUMENT_TYPE_CODES,
  REQUIRED_DOCUMENT_TYPES_ON_CREATE,
  LEGACY_STATUS_SUB_TYPE_ALIASES,
  normalizeDocType,
  isKnownDocType,
  normalizeStatusSubType,
  isKnownStatusSubType,
  suggestedStatusForSubType,
  statusSubTypeLabel,
  signedDocType,
};
