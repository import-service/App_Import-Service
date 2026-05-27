const { getAppSettings } = require('./appSettings');
const { buildRequestDetailPayloadById } = require('./requestDetailPayload');

const DEFAULT_TIMEOUT_MS = 30_000;
const MAX_ONE_C_BODY_CHARS = 4000;

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

/** URL update: тот же хост/база, что в админке для create; путь — customs-request-update. */
function buildOneCUpdateUrl(createUrl) {
  const raw = String(createUrl || '').trim();
  if (!raw) return '';
  if (/\/customs-request-update\/?$/i.test(raw)) return raw;
  if (/\/customs-request\/?$/i.test(raw)) {
    return raw.replace(/\/customs-request\/?$/i, '/customs-request-update');
  }
  return `${raw.replace(/\/$/, '')}/customs-request-update`;
}

async function postJson({ url, body, bearerToken, timeoutMs }) {
  const controller = new AbortController();
  const t = setTimeout(() => controller.abort(), timeoutMs);
  const headers = { 'content-type': 'application/json; charset=utf-8' };
  if (bearerToken) headers.authorization = `Bearer ${bearerToken}`;
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
    const err = new Error(`ONE_C_UPDATE_HTTP_${res.status}`);
    err.status = res.status;
    err.body = json;
    throw err;
  }
  return json;
}

function formatUpdateFailureForClient(err) {
  const httpStatus = err.status ?? null;
  const code = err.message || 'ONE_C_UPDATE_FAILED';
  let oneCMessage = null;
  if (err.body && typeof err.body === 'object') {
    for (const key of ['message', 'error', 'errorMessage', 'description']) {
      const v = err.body[key];
      if (typeof v === 'string' && v.trim()) {
        oneCMessage = v.trim();
        break;
      }
    }
  }
  const oneC = {
    code,
    httpStatus,
    responseBody: serializeOneCBody(err.body),
    oneCMessage,
  };
  const parts = [];
  if (httpStatus) parts.push(`1С HTTP ${httpStatus}`);
  if (oneCMessage) {
    parts.push(oneCMessage);
  } else if (!String(code).startsWith('ONE_C_UPDATE_HTTP_')) {
    parts.push(code);
  } else {
    parts.push('ошибка ответа 1С');
  }
  return { message: parts.join(': '), oneC };
}

async function submitCustomsRequestUpdateTo1CFromDb(fastify, requestId) {
  const settings = await getAppSettings(fastify.pool);
  const updateUrl = buildOneCUpdateUrl(settings.oneCRequestCreateUrl);
  if (!updateUrl) {
    return { ok: false, skipped: true, reason: 'URL_NOT_CONFIGURED' };
  }

  const payload = await buildRequestDetailPayloadById(fastify, requestId);
  if (!payload || !payload.external1cId) {
    return { ok: false, skipped: true, reason: 'MISSING_EXTERNAL_1C_ID' };
  }

  try {
    const json = await postJson({
      url: updateUrl,
      body: payload,
      bearerToken: settings.oneCRequestCreateBearerToken,
      timeoutMs: DEFAULT_TIMEOUT_MS,
    });
    fastify.log.info({ requestId }, 'ONE_C_UPDATE ok');
    return { ok: true, oneCResponse: serializeOneCBody(json) };
  } catch (e) {
    const failure = formatUpdateFailureForClient(e);
    fastify.log.error({ requestId, oneC: failure.oneC }, 'ONE_C_UPDATE failed');
    return { ok: false, error: e.message, message: failure.message, oneC: failure.oneC };
  }
}

module.exports = { submitCustomsRequestUpdateTo1CFromDb, formatUpdateFailureForClient };

