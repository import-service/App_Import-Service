const { hoursSince } = require('./time');

const CUSTOMS_REQUEST_SELECT = `
  id, external_1c_id, manager_external_1c_id, manager_full_name,
  legal_entity_name, legal_email, legal_phone, legal_inn,
  individual_full_name, individual_phone, individual_snils,
  owner_full_name,
  car_make, car_model, vin,
  has_sunroof, has_all_wheel_drive, imported_last_12_months, owns_other_cars, comment_text, is_test,
  status,
  engine_spec, engine_volume, status_sub_type,
  status_sub_type_datetime, deal_type,
  one_c_update_pending, one_c_update_last_error_json, one_c_update_last_attempt_at,
  one_c_update_first_failed_at,
  one_c_create_pending, one_c_create_last_error_json, one_c_create_last_attempt_at,
  one_c_create_first_failed_at,
  advance_payment_json, actual_payment_json,
  created_at, updated_at
`.replace(/\s+/g, ' ');

/** Сумма в рублях в state: строка или число. */
const MONEY_AMOUNT_SCHEMA = {
  type: ['string', 'number'],
};

function getPublicBaseUrl(fastify, request) {
  const fixed = String(fastify?.config?.publicBaseUrl || '').replace(/\/$/, '');
  if (fixed) return fixed;
  if (!request) return '';
  const proto = String(request.headers['x-forwarded-proto'] || '')
    .split(',')[0]
    .trim() || (request.protocol ? String(request.protocol).replace(':', '') : 'https');
  const host = String(request.headers['x-forwarded-host'] || '')
    .split(',')[0]
    .trim() || String(request.headers.host || '').trim();
  if (!host) return '';
  return `${proto}://${host}`;
}

function toAbsoluteUrl(path, base) {
  if (path == null) return path;
  const s = String(path).trim();
  if (!s) return s;
  if (/^https?:\/\//i.test(s)) return s;
  if (!base) return s.startsWith('/') ? s : `/${s}`;
  return `${String(base).replace(/\/$/, '')}${s.startsWith('/') ? s : `/${s}`}`;
}

function parseJsonCol(v) {
  if (v == null) return null;
  if (typeof v === 'object' && v !== null && !Buffer.isBuffer(v)) return v;
  try {
    return JSON.parse(String(v));
  } catch {
    return null;
  }
}

function normalizeMoneyAmount(raw) {
  if (raw == null || raw === '') return null;
  if (typeof raw === 'object' && raw !== null) {
    return normalizeMoneyAmount(raw.amount);
  }
  const amountStr =
    typeof raw === 'number' ? raw.toFixed(2) : String(raw).trim().replace(',', '.');
  if (!amountStr || Number.isNaN(Number(amountStr))) return null;
  return amountStr;
}

function parseMoneyAmountJson(v) {
  const p = parseJsonCol(v);
  if (p == null) return null;
  if (typeof p === 'object' && p.amount != null) {
    return normalizeMoneyAmount(p.amount);
  }
  return normalizeMoneyAmount(p);
}

function computeRefundAmount(advancePayment, actualPayment) {
  if (!advancePayment || !actualPayment) return null;
  const advance = Number(advancePayment);
  const actual = Number(actualPayment);
  if (Number.isNaN(advance) || Number.isNaN(actual)) return null;
  return (advance - actual).toFixed(2);
}

/** Цифры ИНН из тела запроса (legalInn или inn — не docType файла). */
function readLegalInnFromBody(body) {
  if (!body || typeof body !== 'object') return '';
  if (body.legalInn !== undefined) return String(body.legalInn).replace(/\D/g, '');
  if (body.inn !== undefined) return String(body.inn).replace(/\D/g, '');
  return '';
}

function validateLegalInnDigits(digits, { required = true } = {}) {
  const v = String(digits ?? '').replace(/\D/g, '');
  if (!v) {
    if (required) {
      throw new Error('VALIDATION_ERROR: legalInn обязателен (10 или 12 цифр)');
    }
    return null;
  }
  if (v.length !== 10 && v.length !== 12) {
    throw new Error('VALIDATION_ERROR: legalInn должен содержать 10 или 12 цифр');
  }
  return v;
}

/** Распарсить legalInn из create/patch; undefined — поле не передано. */
function resolveLegalInnFromBody(body, { required = false } = {}) {
  const hasKey = body && (body.legalInn !== undefined || body.inn !== undefined);
  if (!hasKey) {
    if (required) return validateLegalInnDigits('', { required: true });
    return undefined;
  }
  return validateLegalInnDigits(readLegalInnFromBody(body), { required: true });
}

function moneyAmountToJsonPayload(body) {
  const amount = normalizeMoneyAmount(body);
  return amount ? JSON.stringify({ amount }) : null;
}

function toIso(mysqlDate) {
  if (!mysqlDate) return null;
  try {
    return new Date(mysqlDate).toISOString();
  } catch {
    return null;
  }
}

/**
 * DTO заявки для МП: camelCase, единый массив files[].
 */
function toCustomsRequestDto(fastify, request, row, fileRows, options) {
  const includeFiles = !options || options.includeFiles !== false;
  const base = getPublicBaseUrl(fastify, request);

  const ownerFullName =
    (row.owner_full_name && String(row.owner_full_name).trim()) ||
    String(row.individual_full_name || '');

  const advancePayment = parseMoneyAmountJson(row.advance_payment_json);
  const actualPayment = parseMoneyAmountJson(row.actual_payment_json);
  const refundAmount = computeRefundAmount(advancePayment, actualPayment);

  const dto = {
    id: String(row.id),
    ownerFullName,
    carMake: String(row.car_make),
    carModel: String(row.car_model),
    vin: String(row.vin),
    status: row.status,
    engineSpec:
      row.engine_spec != null && String(row.engine_spec).trim() !== ''
        ? String(row.engine_spec)
        : null,
    engineVolume:
      row.engine_volume != null && String(row.engine_volume).trim() !== ''
        ? String(row.engine_volume)
        : null,
    statusSubType:
      row.status_sub_type != null && String(row.status_sub_type).trim() !== ''
        ? String(row.status_sub_type)
        : null,
    statusSubTypeDateTime:
      row.status_sub_type_datetime != null ? toIso(row.status_sub_type_datetime) : null,
    dealType:
      row.deal_type != null && String(row.deal_type).trim() !== ''
        ? String(row.deal_type).trim()
        : null,
    oneCUpdatePending: Number(row.one_c_update_pending) === 1,
    oneCUpdateLastAttemptAt:
      row.one_c_update_last_attempt_at != null
        ? toIso(row.one_c_update_last_attempt_at)
        : null,
    oneCUpdateFirstFailedAt:
      row.one_c_update_first_failed_at != null
        ? toIso(row.one_c_update_first_failed_at)
        : null,
    oneCUpdateHoursPending: Number(row.one_c_update_pending) === 1
      ? hoursSince(row.one_c_update_first_failed_at || row.one_c_update_last_attempt_at)
      : null,
    oneCCreatePending: Number(row.one_c_create_pending) === 1,
    oneCCreateLastAttemptAt:
      row.one_c_create_last_attempt_at != null
        ? toIso(row.one_c_create_last_attempt_at)
        : null,
    oneCCreateFirstFailedAt:
      row.one_c_create_first_failed_at != null
        ? toIso(row.one_c_create_first_failed_at)
        : null,
    oneCCreateHoursPending: Number(row.one_c_create_pending) === 1
      ? hoursSince(row.one_c_create_first_failed_at || row.one_c_create_last_attempt_at)
      : null,
    advancePayment,
    actualPayment,
    refundAmount,
    legalEntityName: String(row.legal_entity_name),
    legalEmail: String(row.legal_email),
    legalPhone: String(row.legal_phone),
    legalInn:
      row.legal_inn != null && String(row.legal_inn).trim() !== ''
        ? String(row.legal_inn).trim()
        : null,
    inn:
      row.legal_inn != null && String(row.legal_inn).trim() !== ''
        ? String(row.legal_inn).trim()
        : null,
    individualFullName: String(row.individual_full_name),
    individualPhone: String(row.individual_phone),
    individualSnils: String(row.individual_snils),
    hasSunroof: Boolean(row.has_sunroof),
    hasAllWheelDrive: Boolean(row.has_all_wheel_drive),
    importedLast12Months: Boolean(row.imported_last_12_months),
    ownsOtherCars: Boolean(row.owns_other_cars),
    commentText: row.comment_text != null ? String(row.comment_text) : null,
    isTest: row.is_test === undefined ? false : Number(row.is_test) === 1,
    external1cId: row.external_1c_id != null ? String(row.external_1c_id) : null,
    managerExternal1cId:
      row.manager_external_1c_id != null ? String(row.manager_external_1c_id) : null,
    managerFullName:
      row.manager_full_name != null && String(row.manager_full_name).trim() !== ''
        ? String(row.manager_full_name).trim()
        : null,
    createdAt: toIso(row.created_at),
    updatedAt: toIso(row.updated_at),
  };

  const lastErr = parseJsonCol(row.one_c_update_last_error_json);
  if (lastErr && typeof lastErr === 'object') {
    dto.oneCUpdateLastError = lastErr;
  }

  const createErr = parseJsonCol(row.one_c_create_last_error_json);
  if (createErr && typeof createErr === 'object') {
    dto.oneCCreateLastError = createErr;
  }

  const createH = dto.oneCCreateHoursPending;
  const updateH = dto.oneCUpdateHoursPending;
  dto.oneCOutboundStaleOver24h =
    (dto.oneCCreatePending && createH != null && createH >= 24) ||
    (dto.oneCUpdatePending && updateH != null && updateH >= 24);

  if (includeFiles) {
    dto.files = (fileRows || []).map((f) => ({
      id: String(f.id),
      docType: f.doc_type,
      fileName: f.original_name,
      storedName: f.stored_name,
      mimeType: f.mime_type,
      fileSizeBytes: Number(f.file_size_bytes),
      fileUrl: toAbsoluteUrl(f.file_url, base),
      previewUrl: f.preview_url ? toAbsoluteUrl(f.preview_url, base) : null,
      createdAt: toIso(f.created_at),
      updatedAt: toIso(f.updated_at),
    }));
  }

  return dto;
}

module.exports = {
  CUSTOMS_REQUEST_SELECT,
  MONEY_AMOUNT_SCHEMA,
  toCustomsRequestDto,
  getPublicBaseUrl,
  toAbsoluteUrl,
  moneyAmountToJsonPayload,
  normalizeMoneyAmount,
  computeRefundAmount,
  readLegalInnFromBody,
  validateLegalInnDigits,
  resolveLegalInnFromBody,
};
