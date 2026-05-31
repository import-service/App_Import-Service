const { randomUUID } = require('crypto');
const path = require('path');
const { normalizeDocType, REQUIRED_DOCUMENT_TYPES_ON_CREATE } = require('../constants/customsCatalog');
const {
  notifyMessageFrom1C,
  notifyStateChangedFrom1C,
  notifyFilesChangedFrom1C,
} = require('./pushNotifications');
const {
  storageKeyForRequest,
  upsertRequestFile,
  renameRequestFilesToExternal1cId,
} = require('../util/requestFileStorage');

const UPLOAD_ROOT = path.join(process.cwd(), 'uploads', 'customs-requests');
const DEMO_FULL_NAME = 'тестов тест тестович';
const DEMO_MANAGER_NAME = 'Тестовый Менеджер 1С';
const DEMO_PDF_BUFFER = Buffer.from(
  '%PDF-1.4\n1 0 obj<</Type/Catalog/Pages 2 0 R>>endobj\n2 0 obj<</Type/Pages/Kids[]/Count 0>>endobj\ntrailer<</Root 1 0 R>>\n%%EOF',
);

/** Оригиналы пакета на подпись для demo (bilateral): только два документа. */
const DEMO_SIGNING_ORIGINALS = ['contract', 'kuts'];
const DEMO_SIGNING_UPLOADS = ['contract_sign', 'kuts_sign'];

/** @type {Map<number, { phase: string, timer: NodeJS.Timeout|null }>} */
const scenarios = new Map();

function normalizeName(v) {
  return String(v || '')
    .trim()
    .replace(/\s+/g, ' ')
    .toLowerCase();
}

function isDemoApplicantName(fullName) {
  return normalizeName(fullName) === DEMO_FULL_NAME;
}

function isDemoExternal1cId(external1cId) {
  return String(external1cId || '').startsWith('DEMO-1C-');
}

function demoDelayMs(fastify) {
  const fast = Number(fastify.config?.demoFlow?.fastStepMs);
  if (Number.isFinite(fast) && fast >= 3000) return fast;
  return Number(fastify.config?.demoFlow?.stepMs || 180000);
}

function clearScenarioTimer(requestId) {
  const s = scenarios.get(requestId);
  if (s?.timer) clearTimeout(s.timer);
}

function setScenarioPhase(requestId, phase) {
  clearScenarioTimer(requestId);
  scenarios.set(requestId, { phase, timer: null });
}

function schedulePhase(fastify, requestId, phase, delayMs) {
  clearScenarioTimer(requestId);
  const timer = setTimeout(() => {
    runDemoPhase(fastify, requestId, phase).catch((e) => {
      fastify.log.warn({ requestId, phase, err: e.message }, 'demoFlow phase failed');
    });
  }, delayMs);
  scenarios.set(requestId, { phase, timer });
}

async function fetchRequestRow(pool, requestId) {
  const [rows] = await pool.query(
    `SELECT id, external_1c_id, individual_full_name, status, status_sub_type, deleted_at
     FROM customs_requests
     WHERE id = ?
     LIMIT 1`,
    [requestId],
  );
  return rows[0] || null;
}

async function hasDocTypes(pool, requestId, docTypes) {
  const [rows] = await pool.query(
    `SELECT doc_type FROM customs_request_files
     WHERE request_id = ? AND deleted_at IS NULL`,
    [requestId],
  );
  const have = new Set(rows.map((r) => normalizeDocType(r.doc_type)));
  return docTypes.every((dt) => have.has(normalizeDocType(dt)));
}

async function updateRequestState(pool, requestId, patch) {
  const fields = [];
  const values = [];
  const map = {
    external1cId: 'external_1c_id',
    managerExternal1cId: 'manager_external_1c_id',
    managerFullName: 'manager_full_name',
    status: 'status',
    statusSubType: 'status_sub_type',
    statusSubTypeDateTime: 'status_sub_type_datetime',
    dealType: 'deal_type',
    advance_payment_json: 'advance_payment_json',
    actual_payment_json: 'actual_payment_json',
  };
  for (const [k, col] of Object.entries(map)) {
    if (patch[k] !== undefined) {
      fields.push(`${col} = ?`);
      values.push(patch[k]);
    }
  }
  if (!fields.length) return;
  values.push(requestId);
  await pool.query(
    `UPDATE customs_requests
     SET ${fields.join(', ')}, updated_at = CURRENT_TIMESTAMP(3)
     WHERE id = ? AND deleted_at IS NULL`,
    values,
  );
}

async function upsertDemoFiles(fastify, requestId, docTypes) {
  const [rows] = await fastify.pool.query(
    `SELECT id, external_1c_id FROM customs_requests WHERE id = ? AND deleted_at IS NULL LIMIT 1`,
    [requestId],
  );
  if (!rows.length) return [];
  const row = rows[0];
  const storageKey = storageKeyForRequest(row);
  const changed = [];
  for (const raw of docTypes) {
    const docType = normalizeDocType(raw);
    if (!docType) continue;
    await upsertRequestFile(
      fastify.pool,
      UPLOAD_ROOT,
      requestId,
      storageKey,
      docType,
      DEMO_PDF_BUFFER,
      'application/pdf',
    );
    changed.push(docType);
  }
  return changed;
}

async function pushFilesNotification(fastify, requestId, changedDocTypes) {
  const row = await fetchRequestRow(fastify.pool, requestId);
  if (!row || !changedDocTypes.length) return;
  await notifyFilesChangedFrom1C(fastify, {
    requestId,
    external1cId: row.external_1c_id,
    changedDocTypes,
  });
}

async function pushStateNotification(fastify, requestId, beforeRow) {
  const row = await fetchRequestRow(fastify.pool, requestId);
  if (!row) return;
  await notifyStateChangedFrom1C(fastify, {
    requestId,
    external1cId: row.external_1c_id,
    previousStatus: beforeRow?.status,
    previousStatusSubType: beforeRow?.status_sub_type,
    status: row.status,
    statusSubType: row.status_sub_type,
  });
}

async function updateRequestStateAndNotify(fastify, requestId, patch) {
  const before = await fetchRequestRow(fastify.pool, requestId);
  await updateRequestState(fastify.pool, requestId, patch);
  await pushStateNotification(fastify, requestId, before);
}

async function insertIncomingMessageFrom1C(fastify, requestId, external1cId, text, senderName) {
  const message1cId = `demo-msg-${requestId}-${Date.now()}-${randomUUID().slice(0, 8)}`;
  const [ins] = await fastify.pool.query(
    `INSERT INTO customs_request_messages
      (request_id, author_type, user_id, direction, message_1c_id, text_content, attachments_json, delivery_status)
     VALUES
      (?, 'manager_1c', NULL, 'from_1c', ?, ?, ?, NULL)`,
    [
      requestId,
      message1cId,
      text,
      JSON.stringify({ attachments: [], meta: { senderName: senderName || DEMO_MANAGER_NAME } }),
    ],
  );
  const messageId = ins.insertId;

  if (fastify.chatWss) {
    try {
      await fastify.chatWss.broadcast(requestId, {
        type: 'message_incoming',
        requestId,
        message: {
          id: messageId,
          request_id: requestId,
          author_type: 'manager_1c',
          direction: 'from_1c',
          message_1c_id: message1cId,
          text_content: text,
          attachments: { attachments: [], meta: { senderName: senderName || DEMO_MANAGER_NAME } },
        },
      });
    } catch (e) {
      fastify.log.warn({ requestId, err: e.message }, 'demoFlow wss broadcast failed');
    }
  }

  await notifyMessageFrom1C(fastify, {
    requestId,
    external1cId,
    messageId,
    text,
  });
}

async function assertDemoRequest(fastify, requestId) {
  const row = await fetchRequestRow(fastify.pool, requestId);
  if (!row || row.deleted_at) return null;
  if (!isDemoApplicantName(row.individual_full_name)) return null;
  if (!isDemoExternal1cId(row.external_1c_id)) return null;
  return row;
}

/**
 * После upload 11/11 из МП: имитация ответа 1С на create (без реального HTTP в 1С).
 */
async function completeDemoCreateFromMpUpload(fastify, requestId) {
  const row = await fetchRequestRow(fastify.pool, requestId);
  if (!row || row.deleted_at) return { ok: false, reason: 'NOT_FOUND' };
  if (!isDemoApplicantName(row.individual_full_name)) return { ok: false, reason: 'NOT_DEMO' };

  const external1cId = `DEMO-1C-${requestId}`;
  const before = await fetchRequestRow(fastify.pool, requestId);
  await updateRequestState(fastify.pool, requestId, {
    external1cId,
    status: 'on_review',
    statusSubType: 'draft',
    statusSubTypeDateTime: new Date().toISOString(),
  });

  await renameRequestFilesToExternal1cId(fastify.pool, UPLOAD_ROOT, requestId, external1cId);
  await pushStateNotification(fastify, requestId, before);

  fastify.log.info({ requestId, external1cId }, 'demoFlow: create linked (MP uploads complete)');
  setScenarioPhase(requestId, 'on_review');
  schedulePhase(fastify, requestId, 'manager', demoDelayMs(fastify));
  return { ok: true, external1cId };
}

async function runDemoPhase(fastify, requestId, phase) {
  const row = await assertDemoRequest(fastify, requestId);
  if (!row) return;

  const ext = row.external_1c_id;
  const nowIso = new Date().toISOString();
  const delay = demoDelayMs(fastify);

  if (phase === 'manager') {
    await updateRequestStateAndNotify(fastify, requestId, {
      status: 'in_progress',
      statusSubType: 'manager_execution',
      statusSubTypeDateTime: nowIso,
      managerExternal1cId: `DEMO-MANAGER-${requestId}`,
      managerFullName: DEMO_MANAGER_NAME,
      dealType: 'bilateral',
      advance_payment_json: JSON.stringify({ amount: '830998.00' }),
      actual_payment_json: JSON.stringify({ amount: '750000.00' }),
    });
    await insertIncomingMessageFrom1C(
      fastify,
      requestId,
      ext,
      'Здравствуйте! Заявку приняли. Скоро выложим два документа на подпись: контракт и КУТС.',
      DEMO_MANAGER_NAME,
    );
    setScenarioPhase(requestId, 'manager');
    schedulePhase(fastify, requestId, 'signing', delay);
    return;
  }

  if (phase === 'signing') {
    const before = await fetchRequestRow(fastify.pool, requestId);
    await updateRequestState(fastify.pool, requestId, {
      statusSubType: 'primary_documents_sent',
      statusSubTypeDateTime: nowIso,
    });
    const changed = await upsertDemoFiles(fastify, requestId, DEMO_SIGNING_ORIGINALS);
    await pushFilesNotification(fastify, requestId, changed);
    await pushStateNotification(fastify, requestId, before);
    setScenarioPhase(requestId, 'await_signs');
    fastify.log.info({ requestId }, 'demoFlow: waiting contract_sign + kuts_sign');
    return;
  }

  if (phase === 'after_signs') {
    await updateRequestStateAndNotify(fastify, requestId, {
      statusSubType: 'originals_complete_no_transit',
      statusSubTypeDateTime: nowIso,
    });
    await insertIncomingMessageFrom1C(
      fastify,
      requestId,
      ext,
      'Подписи приняты. Выложим квитанцию утилизационного сбора.',
      DEMO_MANAGER_NAME,
    );
    setScenarioPhase(requestId, 'after_signs');
    schedulePhase(fastify, requestId, 'recycling_fee', delay);
    return;
  }

  if (phase === 'recycling_fee') {
    const changed = await upsertDemoFiles(fastify, requestId, ['payment_recycling_fee']);
    await pushFilesNotification(fastify, requestId, changed);
    setScenarioPhase(requestId, 'await_recycling_receipt');
    fastify.log.info({ requestId }, 'demoFlow: waiting payment_recycling_fee_receipt');
    return;
  }

  if (phase === 'after_recycling_receipt') {
    const before = await fetchRequestRow(fastify.pool, requestId);
    const changed = await upsertDemoFiles(fastify, requestId, [
      'transit_archive_photo_1',
      'transit_archive_video',
    ]);
    await updateRequestState(fastify.pool, requestId, {
      status: 'in_transit',
      statusSubType: 'originals_complete_transit',
      statusSubTypeDateTime: nowIso,
    });
    await pushFilesNotification(fastify, requestId, changed);
    await pushStateNotification(fastify, requestId, before);
    setScenarioPhase(requestId, 'after_recycling_receipt');
    schedulePhase(fastify, requestId, 'customs_duty', delay);
    return;
  }

  if (phase === 'customs_duty') {
    const changed = await upsertDemoFiles(fastify, requestId, ['payment_customs_duty']);
    await pushFilesNotification(fastify, requestId, changed);
    setScenarioPhase(requestId, 'await_customs_receipt');
    fastify.log.info({ requestId }, 'demoFlow: waiting payment_customs_duty_receipt');
    return;
  }

  if (phase === 'after_customs_receipt') {
    const before = await fetchRequestRow(fastify.pool, requestId);
    const changed = await upsertDemoFiles(fastify, requestId, ['epts', 'sbkts']);
    await updateRequestState(fastify.pool, requestId, {
      status: 'delivered',
      statusSubType: 'issued_to_client',
      statusSubTypeDateTime: nowIso,
    });
    await pushFilesNotification(fastify, requestId, changed);
    await pushStateNotification(fastify, requestId, before);
    setScenarioPhase(requestId, 'after_customs_receipt');
    schedulePhase(fastify, requestId, 'closed', delay);
    return;
  }

  if (phase === 'closed') {
    await updateRequestStateAndNotify(fastify, requestId, {
      status: 'closed',
      statusSubType: 'request_closed',
      statusSubTypeDateTime: nowIso,
    });
    await insertIncomingMessageFrom1C(
      fastify,
      requestId,
      ext,
      'Тестовый сценарий завершён: заявка доставлена и закрыта.',
      DEMO_MANAGER_NAME,
    );
    setScenarioPhase(requestId, 'done');
    scenarios.delete(requestId);
    fastify.log.info({ requestId }, 'demoFlow: scenario complete');
  }
}

/** Продвижение сценария после upload из МП (подписи, чеки). */
async function tryAdvanceDemoFlow(fastify, requestId) {
  const row = await assertDemoRequest(fastify, requestId);
  if (!row) return { advanced: false };

  const state = scenarios.get(requestId);
  const phase = state?.phase;
  const delay = Math.min(demoDelayMs(fastify), 15000);

  if (phase === 'await_signs') {
    if (!(await hasDocTypes(fastify.pool, requestId, DEMO_SIGNING_UPLOADS))) {
      return { advanced: false, waiting: 'signs' };
    }
    schedulePhase(fastify, requestId, 'after_signs', delay);
    return { advanced: true, next: 'after_signs' };
  }

  if (phase === 'await_recycling_receipt') {
    if (!(await hasDocTypes(fastify.pool, requestId, ['payment_recycling_fee_receipt']))) {
      return { advanced: false, waiting: 'recycling_receipt' };
    }
    schedulePhase(fastify, requestId, 'after_recycling_receipt', delay);
    return { advanced: true, next: 'after_recycling_receipt' };
  }

  if (phase === 'await_customs_receipt') {
    if (!(await hasDocTypes(fastify.pool, requestId, ['payment_customs_duty_receipt']))) {
      return { advanced: false, waiting: 'customs_receipt' };
    }
    schedulePhase(fastify, requestId, 'after_customs_receipt', delay);
    return { advanced: true, next: 'after_customs_receipt' };
  }

  return { advanced: false, phase };
}

/** Автоответ менеджера на сообщение клиента в demo-заявке. */
async function handleDemoUserChatMessage(fastify, requestId, userText) {
  const row = await assertDemoRequest(fastify, requestId);
  if (!row) return false;

  const trimmed = String(userText || '').trim();
  const preview = trimmed ? ` «${trimmed.slice(0, 120)}${trimmed.length > 120 ? '…' : ''}»` : '';
  const replyDelay = Number(fastify.config?.demoFlow?.chatReplyMs) || 4000;

  setTimeout(() => {
    insertIncomingMessageFrom1C(
      fastify,
      requestId,
      row.external_1c_id,
      `Получил ваше сообщение${preview}. Ответил тестовый менеджер — чат работает.`,
      DEMO_MANAGER_NAME,
    ).catch((e) => {
      fastify.log.warn({ requestId, err: e.message }, 'demoFlow chat reply failed');
    });
  }, replyDelay);

  return true;
}

function startDemoFlowForRequest(fastify, requestId) {
  fastify.log.warn({ requestId }, 'startDemoFlowForRequest: сценарий стартует после upload 11/11');
}

module.exports = {
  isDemoApplicantName,
  isDemoExternal1cId,
  DEMO_FULL_NAME,
  REQUIRED_DOCUMENT_TYPES_ON_CREATE,
  completeDemoCreateFromMpUpload,
  tryAdvanceDemoFlow,
  handleDemoUserChatMessage,
  startDemoFlowForRequest,
};
