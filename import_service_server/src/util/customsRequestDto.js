const CUSTOMS_REQUEST_SELECT = `
  id, external_1c_id, manager_external_1c_id,
  legal_entity_name, legal_email, legal_phone,
  individual_full_name, individual_phone, individual_snils,
  owner_full_name,
  car_make, car_model, vin,
  has_sunroof, has_all_wheel_drive, imported_last_12_months, owns_other_cars, comment_text, is_test,
  status,
  engine_spec, engine_volume, status_since_date_label, status_sub_type,
  finance_items_json, vehicle_photo_urls_json, delivered_documents_json,
  created_at, updated_at
`.replace(/\s+/g, ' ');

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

function normalizeFinanceItem(raw) {
  if (!raw || typeof raw !== 'object') return null;
  const lineType = String(raw.lineType ?? raw.line_type ?? '').trim();
  if (!lineType) return null;
  let amountText = raw.amountText != null ? String(raw.amountText) : '';
  if (!amountText && raw.amount != null && raw.amount !== '') {
    amountText = String(raw.amount);
  }
  const o = {
    lineType,
    amountText,
    title: raw.title != null ? String(raw.title) : '',
    paymentQrUrl: String(raw.paymentQrUrl ?? raw.payment_qr_url ?? ''),
    receiptUrl: String(raw.receiptUrl ?? raw.receipt_url ?? ''),
  };
  if (raw.amount != null && raw.amount !== '' && !Number.isNaN(Number(raw.amount))) {
    o.amount = Number(raw.amount);
  }
  return o;
}

function parseFinanceItemsJson(v) {
  const p = parseJsonCol(v);
  if (!Array.isArray(p)) return [];
  return p.map(normalizeFinanceItem).filter(Boolean);
}

function parseStringUrlArray(v, base) {
  const p = parseJsonCol(v);
  if (!Array.isArray(p)) return [];
  return p.map((s) => toAbsoluteUrl(String(s).trim(), base)).filter(Boolean);
}

function parseDeliveredDocs(v, base) {
  const p = parseJsonCol(v);
  if (!Array.isArray(p)) return [];
  const out = [];
  for (const raw of p) {
    if (!raw || typeof raw !== 'object') continue;
    const title = String(raw.title ?? raw.documentTitle ?? '').trim();
    const downloadUrl = toAbsoluteUrl(
      String(raw.downloadUrl ?? raw.download_url ?? raw.url ?? ''),
      base,
    );
    if (title || downloadUrl) {
      out.push({ title, downloadUrl });
    }
  }
  return out;
}

function mergeVehiclePhotoUrls(vehicleUrls, fileRows, base) {
  const seen = new Set(vehicleUrls);
  for (const f of fileRows || []) {
    const t = f.doc_type;
    if (t === 'car_front_photo' || t === 'car_back_photo') {
      const u = toAbsoluteUrl(f.file_url, base);
      if (u) seen.add(u);
    }
  }
  return Array.from(seen);
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
 * DTO заявки для мобильного контракта: camelCase, id — string, алиасы detail* для обратной совместимости.
 * @param {{ includeFiles?: boolean, mergeVehicleFiles?: boolean }} [options]
 *   list: { includeFiles: false, mergeVehicleFiles: false } — нет `files`, vehiclePhotoUrls только из JSON
 *   detail/по умолчанию: `files` есть, в vehiclePhotoUrls мержатся car_front/car_back из upload
 */
function toCustomsRequestDto(fastify, request, row, fileRows, options) {
  const includeFiles = !options || options.includeFiles !== false;
  const withFileMerge = !options || options.mergeVehicleFiles !== false;

  const base = getPublicBaseUrl(fastify, request);

  const ownerFullName =
    (row.owner_full_name && String(row.owner_full_name).trim()) ||
    String(row.individual_full_name || '');

  const financeItems = parseFinanceItemsJson(row.finance_items_json);
  const financeRef = financeItems;

  let vehiclePhotoUrls = parseStringUrlArray(row.vehicle_photo_urls_json, base);
  if (withFileMerge) {
    vehiclePhotoUrls = mergeVehiclePhotoUrls(vehiclePhotoUrls, fileRows, base);
  }
  const vehicleRef = vehiclePhotoUrls;

  const deliveredDocuments = parseDeliveredDocs(row.delivered_documents_json, base);

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
    statusSinceDateLabel:
      row.status_since_date_label != null && String(row.status_since_date_label).trim() !== ''
        ? String(row.status_since_date_label)
        : null,
    statusSubType:
      row.status_sub_type != null && String(row.status_sub_type).trim() !== ''
        ? String(row.status_sub_type)
        : null,
    financeItems: financeRef,
    vehiclePhotoUrls: vehicleRef,
    deliveredDocuments,
    // Устаревшие имена (тот же смысл) — моб. клиент умеет читать для миграции
    detailFinanceLines: financeRef,
    detailPhotoUrls: vehicleRef,
    legalEntityName: String(row.legal_entity_name),
    legalEmail: String(row.legal_email),
    legalPhone: String(row.legal_phone),
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
    createdAt: toIso(row.created_at),
    updatedAt: toIso(row.updated_at),
  };

  if (includeFiles) {
    dto.files = (fileRows || []).map((f) => ({
      id: String(f.id),
      docType: f.doc_type,
      fileName: f.original_name,
      storedName: f.stored_name,
      mimeType: f.mime_type,
      fileSizeBytes: Number(f.file_size_bytes),
      fileUrl: toAbsoluteUrl(f.file_url, base),
      createdAt: toIso(f.created_at),
      updatedAt: toIso(f.updated_at),
    }));
  }

  return dto;
}

function financeItemsToJsonPayload(body) {
  if (body == null) return null;
  const arr = Array.isArray(body) ? body : [];
  const out = [];
  for (const raw of arr) {
    const n = normalizeFinanceItem({ ...raw, lineType: raw?.lineType ?? raw?.line_type });
    if (n) out.push(n);
  }
  return JSON.stringify(out);
}

function stringArrayToJsonPayload(body) {
  if (body == null) return null;
  const arr = Array.isArray(body) ? body : [];
  return JSON.stringify(arr.map((s) => String(s).trim()).filter(Boolean));
}

function deliveredDocsToJsonPayload(body) {
  if (body == null) return null;
  const arr = Array.isArray(body) ? body : [];
  const out = [];
  for (const raw of arr) {
    if (!raw || typeof raw !== 'object') continue;
    const title = String(raw.title || '').trim();
    const downloadUrl = String(raw.downloadUrl || raw.download_url || '').trim();
    if (title || downloadUrl) {
      out.push({ title, downloadUrl });
    }
  }
  return JSON.stringify(out);
}

module.exports = {
  CUSTOMS_REQUEST_SELECT,
  toCustomsRequestDto,
  getPublicBaseUrl,
  toAbsoluteUrl,
  financeItemsToJsonPayload,
  stringArrayToJsonPayload,
  deliveredDocsToJsonPayload,
  normalizeFinanceItem,
};
