const admin = require('firebase-admin');
const {
  statusSubTypeLabel,
  docTypeLabel,
  docTypeCategory,
  normalizeDocType,
} = require('../constants/customsCatalog');

const MAX_BODY_LEN = 200;
const MAX_TITLE_LEN = 64;

const REQUEST_STATUS_LABELS = {
  new: 'Новая',
  on_review: 'На рассмотрении',
  in_progress: 'В работе',
  in_transit: 'В пути',
  delivered: 'Доставлено',
  closed: 'Закрыта',
  cancelled: 'Отменена',
};

/** Короткие формулировки для пуша (остальное — из справочника подстатусов). */
const SUBTYPE_USER_HINTS = {
  manager_execution: 'Назначен менеджер',
  primary_documents_sent: 'Отправлены документы на подпись',
  signature_revision_required: 'Нужно переподписать документы',
  issued_to_client: 'Автомобиль выдан',
  request_closed: 'Заявка закрыта',
};

function clipText(text, maxLen = MAX_BODY_LEN) {
  const s = String(text || '').trim();
  if (!s) return '';
  if (s.length <= maxLen) return s;
  return `${s.slice(0, maxLen - 1)}…`;
}

function statusLabel(code) {
  const c = String(code ?? '').trim();
  return REQUEST_STATUS_LABELS[c] || '';
}

function requestRef(requestId) {
  const id = String(requestId ?? '').trim();
  return id ? `Заявка №${id}` : 'Заявка';
}

function subtypeUserHint(code) {
  const c = String(code ?? '').trim();
  if (!c) return '';
  return SUBTYPE_USER_HINTS[c] || statusSubTypeLabel(c) || '';
}

function formatStatusPhrase(status) {
  const label = statusLabel(status);
  return label ? `«${label}»` : '';
}

/**
 * Текст пуша при смене state от 1С.
 */
function buildStateChangeSummary({
  requestId,
  previousStatus,
  status,
  previousStatusSubType,
  statusSubType,
}) {
  const req = requestRef(requestId);
  const prev = String(previousStatus ?? '').trim();
  const next = String(status ?? '').trim();
  const prevSub = String(previousStatusSubType ?? '').trim();
  const nextSub = String(statusSubType ?? '').trim();
  const parts = [];

  if (prev && next && prev !== next) {
    parts.push(`статус изменён на ${formatStatusPhrase(next)}`);
  } else if (next && !prev) {
    parts.push(`статус ${formatStatusPhrase(next)}`);
  }

  if (nextSub && nextSub !== prevSub) {
    const hint = subtypeUserHint(nextSub);
    if (hint) parts.push(hint);
  }

  if (!parts.length) {
    if (next) {
      return clipText(`${req}: обновление — ${formatStatusPhrase(next)}`);
    }
    return clipText(`${req}: обновление по заявке`);
  }

  return clipText(`${req}: ${parts.join('. ')}`);
}

function buildStatePushTitle({ requestId, status, statusSubType }) {
  const req = requestRef(requestId);
  const sub = String(statusSubType ?? '').trim();
  if (sub === 'primary_documents_sent' || sub === 'signature_revision_required') {
    return clipText('Документы на подпись', MAX_TITLE_LEN);
  }
  if (sub === 'request_closed') {
    return clipText('Заявка закрыта', MAX_TITLE_LEN);
  }
  if (sub === 'issued_to_client') {
    return clipText('Автомобиль выдан', MAX_TITLE_LEN);
  }
  const st = statusLabel(status);
  if (st) {
    return clipText(`${req}: ${st}`, MAX_TITLE_LEN);
  }
  return clipText('Обновление заявки', MAX_TITLE_LEN);
}

function classifyChangedFiles(changedDocTypes) {
  const types = (changedDocTypes || []).map((d) => normalizeDocType(d)).filter(Boolean);
  const categories = new Set(types.map((t) => docTypeCategory(t)));
  return { types, categories };
}

/**
 * Текст пуша при upload файлов от 1С.
 */
function buildFilesChangeSummary({ requestId, status, changedDocTypes }) {
  const req = requestRef(requestId);
  const statusPhrase = formatStatusPhrase(status);
  const { types, categories } = classifyChangedFiles(changedDocTypes);

  if (!types.length) {
    return clipText(`${req}: появились новые файлы`);
  }

  const signingTypes = types.filter(
    (t) => !t.endsWith('_sign') && (docTypeCategory(t) === 'signing' || t === 'contract'),
  );
  const paymentTypes = types.filter(
    (t) => t === 'payment_recycling_fee' || t === 'payment_customs_duty',
  );
  const finalTypes = types.filter((t) => t === 'epts' || t === 'sbkts');
  const transitTypes = types.filter((t) => docTypeCategory(t) === 'transit_archive');

  if (signingTypes.length) {
    const names = signingTypes.map(docTypeLabel).filter(Boolean).slice(0, 3).join(', ');
    const suffix = signingTypes.length > 3 ? '…' : '';
    const statusPart = statusPhrase ? `, ${statusPhrase}` : '';
    return clipText(
      `${req}${statusPart}: документы на подпись${names ? ` — ${names}${suffix}` : ''}`,
    );
  }

  if (paymentTypes.length) {
    const kind = paymentTypes.some((t) => t === 'payment_recycling_fee')
      ? 'утилизационного сбора'
      : 'госпошлины';
    return clipText(`${req}: квитанция ${kind} — оплатите и загрузите чек`);
  }

  if (finalTypes.length) {
    const names = finalTypes.map(docTypeLabel).join(', ');
    return clipText(`${req}: итоговые документы — ${names}`);
  }

  if (transitTypes.length || categories.has('transit_archive')) {
    return clipText(`${req}: архив перед транзитом — скачайте файлы`);
  }

  const names = types.map(docTypeLabel).filter(Boolean).slice(0, 3).join(', ');
  const suffix = types.length > 3 ? '…' : '';
  return clipText(`${req}: новые документы — ${names}${suffix}`);
}

function buildFilesPushTitle({ requestId, changedDocTypes }) {
  const { types } = classifyChangedFiles(changedDocTypes);
  const signingTypes = types.filter(
    (t) => !t.endsWith('_sign') && (docTypeCategory(t) === 'signing' || t === 'contract'),
  );
  if (signingTypes.length) {
    return clipText('Документы на подпись', MAX_TITLE_LEN);
  }
  if (types.some((t) => t === 'payment_recycling_fee' || t === 'payment_customs_duty')) {
    return clipText('Квитанция к оплате', MAX_TITLE_LEN);
  }
  return clipText(requestRef(requestId), MAX_TITLE_LEN);
}

let app = null;

function ensureFirebaseApp(config) {
  if (app) return app;
  const fcm = config?.push?.fcm || {};
  if (!fcm.projectId || !fcm.clientEmail || !fcm.privateKey) {
    return null;
  }
  app = admin.initializeApp({
    credential: admin.credential.cert({
      projectId: fcm.projectId,
      clientEmail: fcm.clientEmail,
      privateKey: fcm.privateKey,
    }),
  });
  return app;
}

async function fetchOrgPushTokens(pool, orgId) {
  try {
    const [rows] = await pool.query(
      `SELECT token
       FROM user_push_tokens
       WHERE org_id = ? AND deleted_at IS NULL`,
      [orgId],
    );
    return rows.map((r) => String(r.token || '').trim()).filter(Boolean);
  } catch (e) {
    if (e && e.code === 'ER_NO_SUCH_TABLE') {
      return [];
    }
    throw e;
  }
}

async function resolveOrgIdByRequestId(pool, requestId) {
  const [rows] = await pool.query(
    `SELECT o.id
     FROM customs_requests r
     JOIN organizations o ON o.login = r.legal_email AND o.deleted_at IS NULL
     WHERE r.id = ? AND r.deleted_at IS NULL
     LIMIT 1`,
    [requestId],
  );
  if (!rows.length) return null;
  return Number(rows[0].id);
}

async function markTokensDeleted(pool, tokens) {
  if (!Array.isArray(tokens) || !tokens.length) return;
  await pool.query(
    `UPDATE user_push_tokens
     SET deleted_at = CURRENT_TIMESTAMP(3), updated_at = CURRENT_TIMESTAMP(3)
     WHERE token IN (?) AND deleted_at IS NULL`,
    [tokens],
  );
}

async function sendPushToOrganization(fastify, orgId, message) {
  if (!orgId) return { ok: false, skipped: true, reason: 'MISSING_ORG_ID' };
  const firebaseApp = ensureFirebaseApp(fastify.config);
  if (!firebaseApp) return { ok: false, skipped: true, reason: 'FCM_NOT_CONFIGURED' };

  const tokens = await fetchOrgPushTokens(fastify.pool, orgId);
  if (!tokens.length) return { ok: false, skipped: true, reason: 'NO_TOKENS' };

  const multicast = {
    tokens,
    notification: {
      title: clipText(message.title || 'Импорт Сервис', MAX_TITLE_LEN),
      body: clipText(message.body || '', MAX_BODY_LEN),
    },
    data: Object.fromEntries(
      Object.entries(message.data || {}).map(([k, v]) => [k, String(v ?? '')]),
    ),
  };

  const res = await admin.messaging(firebaseApp).sendEachForMulticast(multicast);
  const invalid = [];
  res.responses.forEach((r, idx) => {
    if (!r.success) {
      const code = String(r.error?.code || '');
      if (
        code === 'messaging/registration-token-not-registered' ||
        code === 'messaging/invalid-registration-token'
      ) {
        invalid.push(tokens[idx]);
      }
    }
  });
  if (invalid.length) {
    await markTokensDeleted(fastify.pool, invalid);
  }
  return {
    ok: true,
    total: tokens.length,
    success: res.successCount,
    failed: res.failureCount,
    invalid: invalid.length,
  };
}

async function notifyFilesChangedFrom1C(fastify, dto) {
  const orgId = await resolveOrgIdByRequestId(fastify.pool, dto.requestId);
  const requestId = String(dto.requestId || '');
  const changed = Array.isArray(dto.changedDocTypes) ? dto.changedDocTypes : [];
  const changeSummary =
    dto.changeSummary ||
    buildFilesChangeSummary({
      requestId,
      status: dto.status,
      changedDocTypes: changed,
    });

  return sendPushToOrganization(fastify, orgId, {
    title:
      dto.title ||
      buildFilesPushTitle({ requestId, changedDocTypes: changed }),
    body: changeSummary,
    data: {
      type: 'request_files_update',
      requestId,
      request_id: requestId,
      id: requestId,
      external1cId: dto.external1cId || '',
      status: dto.status || '',
      changedDocTypes: changed.join(','),
      changeSummary,
    },
  });
}

async function notifyStateChangedFrom1C(fastify, dto) {
  const orgId = await resolveOrgIdByRequestId(fastify.pool, dto.requestId);
  const requestId = String(dto.requestId || '');
  const status = String(dto.status || '').trim();
  const statusSubType = String(dto.statusSubType || '').trim();
  const previousStatusRaw = String(dto.previousStatus ?? '').trim();
  const previousStatus =
    previousStatusRaw && status && previousStatusRaw !== status ? previousStatusRaw : '';

  const changeSummary =
    dto.changeSummary ||
    buildStateChangeSummary({
      requestId,
      previousStatus: previousStatusRaw || dto.previousStatus,
      status,
      previousStatusSubType: dto.previousStatusSubType,
      statusSubType,
    });

  const data = {
    type: 'request_update',
    requestId,
    request_id: requestId,
    id: requestId,
    external1cId: dto.external1cId || '',
    status,
    statusSubType,
  };
  if (previousStatus) {
    data.previousStatus = previousStatus;
  }
  if (changeSummary) {
    data.changeSummary = changeSummary;
  }

  return sendPushToOrganization(fastify, orgId, {
    title:
      dto.title ||
      buildStatePushTitle({ requestId, status, statusSubType }),
    body: changeSummary,
    data,
  });
}

async function notifyMessageFrom1C(fastify, dto) {
  const orgId = await resolveOrgIdByRequestId(fastify.pool, dto.requestId);
  const requestId = String(dto.requestId || '');
  const req = requestRef(requestId);
  return sendPushToOrganization(fastify, orgId, {
    title: 'Сообщение от менеджера',
    body: clipText(dto.text || `${req}: новое сообщение в чате`),
    data: {
      type: 'new_message',
      requestId,
      request_id: requestId,
      id: requestId,
      external1cId: dto.external1cId || '',
      messageId: dto.messageId,
    },
  });
}

module.exports = {
  sendPushToOrganization,
  notifyStateChangedFrom1C,
  notifyFilesChangedFrom1C,
  notifyMessageFrom1C,
  buildStateChangeSummary,
  buildFilesChangeSummary,
  buildStatePushTitle,
  buildFilesPushTitle,
};
