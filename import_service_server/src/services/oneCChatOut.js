const { getAppSettings } = require('./appSettings');
const DEFAULT_TIMEOUT_MS = 15_000;
const MAX_ATTEMPTS = 2;

async function sleep(ms) {
  return new Promise((r) => setTimeout(r, ms));
}

async function postJson({ url, body, bearerToken, timeoutMs }) {
  const controller = new AbortController();
  const t = setTimeout(() => controller.abort(), timeoutMs);
  const headers = {
    'content-type': 'application/json; charset=utf-8',
  };
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
    const err = new Error(`ONE_C_HTTP_${res.status}`);
    err.status = res.status;
    err.body = json;
    throw err;
  }
  return { status: res.status, json, raw: text };
}

/** Отдельный endpoint чата на стороне 1С (не files update). */
function buildOneCChatUrl(createUrl) {
  const raw = String(createUrl || '').trim();
  if (!raw) return '';
  if (/\/customs-request-chat\/?$/i.test(raw)) return raw;
  if (/\/customs-request-update\/?$/i.test(raw)) {
    return raw.replace(/\/customs-request-update\/?$/i, '/customs-request-chat');
  }
  if (/\/customs-request\/?$/i.test(raw)) {
    return raw.replace(/\/customs-request\/?$/i, '/customs-request-chat');
  }
  return `${raw.replace(/\/$/, '')}/customs-request-chat`;
}

/**
 * @param {import('fastify').FastifyInstance} fastify
 */
async function sendUserMessageTo1C(fastify, { external1cId, clientMessageId, text, attachmentsJson }) {
  const settings = await getAppSettings(fastify.pool);
  const chatUrl = buildOneCChatUrl(settings.oneCRequestCreateUrl);
  if (!chatUrl) {
    const e = new Error('ONE_C_CHAT_URL_NOT_SET');
    e.code = 'ONE_C_CHAT_URL_NOT_SET';
    throw e;
  }

  const body = {
    external1cId,
    clientMessageId,
    text,
    attachments: attachmentsJson,
  };

  let lastErr;
  for (let attempt = 1; attempt <= MAX_ATTEMPTS; attempt += 1) {
    try {
      return await postJson({
        url: chatUrl,
        body,
        bearerToken: settings.oneCRequestCreateBearerToken || '',
        timeoutMs: DEFAULT_TIMEOUT_MS,
      });
    } catch (e) {
      lastErr = e;
      if (attempt < MAX_ATTEMPTS) {
        await sleep(250 * attempt);
      }
    }
  }
  throw lastErr;
}

module.exports = { sendUserMessageTo1C, buildOneCChatUrl };
