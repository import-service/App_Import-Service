const admin = require('firebase-admin');
const { statusSubTypeLabel } = require('../constants/customsCatalog');

const MAX_BODY_LEN = 160;
const MAX_CHANGE_SUMMARY_LEN = 120;

const REQUEST_STATUS_LABELS = {
  new: 'Новая',
  on_review: 'На рассмотрении',
  in_progress: 'В работе',
  in_transit: 'В пути',
  delivered: 'Доставлено',
  closed: 'Закрыта',
  cancelled: 'Отменена',
};

function clipText(text, maxLen = MAX_BODY_LEN) {
  const s = String(text || '').trim();
  if (!s) return '';
  if (s.length <= maxLen) return s;
  return `${s.slice(0, maxLen - 1)}…`;
}

function clipChangeSummary(text) {
  return clipText(text, MAX_CHANGE_SUMMARY_LEN);
}

function statusLabel(code) {
  const c = String(code ?? '').trim();
  return REQUEST_STATUS_LABELS[c] || c;
}

function normalizeSub(code) {
  return String(code ?? '').trim();
}

/**
 * Готовая строка для списка заявок в МП (RU).
 */
function buildStateChangeSummary({
  previousStatus,
  status,
  previousStatusSubType,
  statusSubType,
}) {
  const prev = String(previousStatus ?? '').trim();
  const next = String(status ?? '').trim();
  const prevSub = normalizeSub(previousStatusSubType);
  const nextSub = normalizeSub(statusSubType);

  if (prev && next && prev !== next) {
    return clipChangeSummary(`Статус: ${statusLabel(prev)} → ${statusLabel(next)}`);
  }

  if (nextSub === 'signature_revision_required') {
    return 'Требуется подпись документов';
  }

  if (nextSub && nextSub !== prevSub) {
    const label = statusSubTypeLabel(nextSub);
    if (label) {
      return clipChangeSummary(`Обновлён подстатус: ${label}`);
    }
  }

  return '';
}

function buildFilesChangeSummary(changedDocTypes) {
  const changed = Array.isArray(changedDocTypes)
    ? changedDocTypes.map((d) => String(d || '').trim()).filter(Boolean)
    : [];
  if (!changed.length) {
    return 'Появились новые файлы';
  }
  const list = changed.slice(0, 8).join(', ');
  const suffix = changed.length > 8 ? '…' : '';
  return clipChangeSummary(`Новые документы: ${list}${suffix}`);
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
      title: String(message.title || 'Обновление заявки'),
      body: clipText(message.body || ''),
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
  const changeSummary = dto.changeSummary || buildFilesChangeSummary(changed);

  return sendPushToOrganization(fastify, orgId, {
    title: 'Новые документы по заявке',
    body: changeSummary,
    data: {
      type: 'request_files_update',
      requestId,
      request_id: requestId,
      id: requestId,
      external1cId: dto.external1cId || '',
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

  const fallbackBody = statusSubType
    ? `Статус: ${status}. Деталь: ${statusSubType}`
    : `Статус заявки изменён: ${status}`;

  return sendPushToOrganization(fastify, orgId, {
    title: 'Обновление по заявке',
    body: changeSummary || fallbackBody,
    data,
  });
}

async function notifyMessageFrom1C(fastify, dto) {
  const orgId = await resolveOrgIdByRequestId(fastify.pool, dto.requestId);
  const requestId = String(dto.requestId || '');
  return sendPushToOrganization(fastify, orgId, {
    title: 'Новое сообщение менеджера',
    body: dto.text || 'У вас новое сообщение по заявке',
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
};
