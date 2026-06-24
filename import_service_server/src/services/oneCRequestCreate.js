const { getAppSettings } = require('./appSettings');
const { ensureDisplayFileName } = require('../util/displayFileName');

const DEFAULT_TIMEOUT_MS = 30_000;
const MAX_ONE_C_BODY_CHARS = 4000;

function normalize(v) {
  return String(v ?? '').trim();
}

function absoluteFileUrl(fastify, fileUrl) {
  const raw = normalize(fileUrl);
  if (!raw) return raw;
  if (/^https?:\/\//i.test(raw)) return raw;
  const base = String(fastify.config.publicBaseUrl || '').trim().replace(/\/$/, '');
  if (!base) return raw;
  return `${base}${raw.startsWith('/') ? '' : '/'}${raw}`;
}

function buildCreatePayloadFromBody(requestId, body) {
  const files = Array.isArray(body.files) ? body.files : [];
  const legalInn = normalize(String(body.legalInn ?? body.inn ?? '').replace(/\D/g, ''));
  return {
    requestId,
    legalEntityName: normalize(body.legalEntityName),
    legalEmail: normalize(body.legalEmail),
    legalPhone: normalize(body.legalPhone),
    legalInn: legalInn || null,
    inn: legalInn || null,
    individualFullName: normalize(body.individualFullName),
    individualPhone: normalize(body.individualPhone),
    individualSnils: normalize(body.individualSnils),
    carMake: normalize(body.carMake),
    carModel: normalize(body.carModel),
    vin: normalize(body.vin),
    hasSunroof: Boolean(body.hasSunroof),
    hasAllWheelDrive: Boolean(body.hasAllWheelDrive),
    importedLast12Months: Boolean(body.importedLast12Months),
    ownsOtherCars: Boolean(body.ownsOtherCars),
    commentText: normalize(body.commentText) || null,
    isTest: Boolean(body.isTest),
    files: files.map((f) => ({
      docType: normalize(f.docType),
      fileName: normalize(f.fileName),
      mimeType: normalize(f.mimeType) || 'application/octet-stream',
      fileUrl: normalize(f.fileUrl),
    })),
  };
}

function buildCreatePayloadFromRow(requestId, row, fileRows) {
  const legalInn = normalize(String(row.legal_inn ?? '').replace(/\D/g, ''));
  return {
    requestId,
    legalEntityName: normalize(row.legal_entity_name),
    legalEmail: normalize(row.legal_email),
    legalPhone: normalize(row.legal_phone),
    legalInn: legalInn || null,
    inn: legalInn || null,
    individualFullName: normalize(row.individual_full_name),
    individualPhone: normalize(row.individual_phone),
    individualSnils: normalize(row.individual_snils),
    carMake: normalize(row.car_make),
    carModel: normalize(row.car_model),
    vin: normalize(row.vin),
    hasSunroof: Boolean(row.has_sunroof),
    hasAllWheelDrive: Boolean(row.has_all_wheel_drive),
    importedLast12Months: Boolean(row.imported_last_12_months),
    ownsOtherCars: Boolean(row.owns_other_cars),
    commentText: normalize(row.comment_text) || null,
    isTest: Boolean(row.is_test),
    files: fileRows.map((f) => ({
      docType: normalize(f.doc_type),
      fileName: ensureDisplayFileName({
        docType: f.doc_type,
        mimeType: f.mime_type,
        storedName: f.stored_name,
        clientFileName: f.original_name,
      }),
      mimeType: normalize(f.mime_type) || 'application/octet-stream',
      fileUrl: normalize(f.file_url),
    })),
  };
}

function pickMessageFromBody(body) {
  if (!body || typeof body !== 'object') return null;
  for (const key of ['message', 'error', 'errorMessage', 'description', 'detail']) {
    const v = body[key];
    if (typeof v === 'string' && v.trim()) return v.trim();
  }
  if (typeof body.raw === 'string' && body.raw.trim()) {
    return body.raw.trim().slice(0, 500);
  }
  return null;
}

function serializeOneCBody(body) {
  if (body == null) return null;
  if (typeof body === 'string') {
    return body.length <= MAX_ONE_C_BODY_CHARS
      ? body
      : { truncated: true, preview: body.slice(0, MAX_ONE_C_BODY_CHARS) };
  }
  const text = JSON.stringify(body);
  if (text.length <= MAX_ONE_C_BODY_CHARS) return body;
  return { truncated: true, preview: text.slice(0, MAX_ONE_C_BODY_CHARS) };
}

function buildOneCFailureDetail(err) {
  const httpStatus = err.status ?? null;
  const code = err.message || 'ONE_C_CREATE_FAILED';
  return {
    code,
    httpStatus,
    responseBody: serializeOneCBody(err.body),
    oneCMessage: pickMessageFromBody(err.body),
  };
}

function formatFailureForClient(err) {
  const oneC = buildOneCFailureDetail(err);
  const parts = [];
  if (oneC.httpStatus) parts.push(`1С HTTP ${oneC.httpStatus}`);
  if (oneC.oneCMessage) {
    parts.push(oneC.oneCMessage);
  } else if (oneC.code && !String(oneC.code).startsWith('ONE_C_CREATE_HTTP_')) {
    parts.push(oneC.code);
  } else if (oneC.httpStatus) {
    parts.push('ошибка ответа 1С');
  } else {
    parts.push('Ошибка при отправке в 1С');
  }
  return { message: parts.join(': '), oneC };
}

async function postJson({ url, body, bearerToken, timeoutMs }) {
  const controller = new AbortController();
  const t = setTimeout(() => controller.abort(), timeoutMs);
  const headers = { 'content-type': 'application/json; charset=utf-8' };
  if (bearerToken) {
    headers.authorization = `Bearer ${bearerToken}`;
  }
  const res = await fetch(url, {
    method: 'POST',
    headers,
    body: JSON.stringify(body),
    signal: controller.signal,
  });
  clearTimeout(t);
  const text = await res.text();
  let json;
  try {
    json = text ? JSON.parse(text) : null;
  } catch {
    json = { raw: text };
  }
  if (!res.ok) {
    const err = new Error(`ONE_C_CREATE_HTTP_${res.status}`);
    err.status = res.status;
    err.body = json;
    throw err;
  }
  return json;
}

function parseCreateResponse(json, expectedRequestId) {
  if (!json || typeof json !== 'object') {
    throw new Error('ONE_C_CREATE_INVALID_RESPONSE');
  }
  const external1cId = normalize(json.external1cId ?? json.external_1c_id);
  const responseRequestId = json.requestId != null ? Number(json.requestId) : null;

  if (!external1cId) {
    throw new Error('ONE_C_CREATE_MISSING_external1cId');
  }
  if (
    responseRequestId != null &&
    Number.isFinite(responseRequestId) &&
    Number(expectedRequestId) !== responseRequestId
  ) {
    throw new Error('ONE_C_CREATE_REQUEST_ID_MISMATCH');
  }

  return { external1cId, requestId: responseRequestId };
}

async function applyCreateFrom1C(pool, requestId, link) {
  const [result] = await pool.query(
    `UPDATE customs_requests
     SET external_1c_id = ?, status = 'on_review'
     WHERE id = ? AND deleted_at IS NULL AND status = 'new'`,
    [link.external1cId, requestId],
  );
  return result.affectedRows > 0;
}

async function submitCustomsRequestTo1C(fastify, requestId, payloadBuilder) {
  const settings = await getAppSettings(fastify.pool);
  if (!settings.oneCRequestCreateUrl) {
    fastify.log.warn({ requestId }, 'ONE_C_CREATE_URL not configured, skip');
    return { ok: false, skipped: true, reason: 'URL_NOT_CONFIGURED' };
  }

  const payload = payloadBuilder();
  payload.files = payload.files.map((f) => ({
    ...f,
    fileUrl: absoluteFileUrl(fastify, f.fileUrl),
  }));

  try {
    const json = await postJson({
      url: settings.oneCRequestCreateUrl,
      body: payload,
      bearerToken: settings.oneCRequestCreateBearerToken,
      timeoutMs: DEFAULT_TIMEOUT_MS,
    });
    const link = parseCreateResponse(json, requestId);
    const updated = await applyCreateFrom1C(fastify.pool, requestId, link);
    fastify.log.info({ requestId, external1cId: link.external1cId, updated }, 'ONE_C_CREATE ok');
    return {
      ok: true,
      updated,
      link,
      oneCResponse: serializeOneCBody(json),
    };
  } catch (e) {
    const failure = formatFailureForClient(e);
    fastify.log.error({ requestId, oneC: failure.oneC }, 'ONE_C_CREATE failed');
    return {
      ok: false,
      error: e.message,
      message: failure.message,
      oneC: failure.oneC,
    };
  }
}

async function submitCustomsRequestTo1CFromBody(fastify, requestId, body) {
  return submitCustomsRequestTo1C(fastify, requestId, () => buildCreatePayloadFromBody(requestId, body));
}

async function submitCustomsRequestTo1CFromDb(fastify, requestId) {
  const [rows] = await fastify.pool.query(
    `SELECT * FROM customs_requests WHERE id = ? AND deleted_at IS NULL LIMIT 1`,
    [requestId],
  );
  if (!rows.length) {
    return { ok: false, error: 'NOT_FOUND' };
  }
  const [fileRows] = await fastify.pool.query(
    `SELECT doc_type, original_name, stored_name, mime_type, file_url
     FROM customs_request_files WHERE request_id = ? AND deleted_at IS NULL ORDER BY id ASC`,
    [requestId],
  );
  return submitCustomsRequestTo1C(fastify, requestId, () =>
    buildCreatePayloadFromRow(requestId, rows[0], fileRows),
  );
}

module.exports = {
  submitCustomsRequestTo1CFromBody,
  submitCustomsRequestTo1CFromDb,
  buildCreatePayloadFromBody,
};
