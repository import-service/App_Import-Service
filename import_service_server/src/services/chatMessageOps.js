const { v4: uuidv4 } = require('uuid');
const { notifyMessageFrom1C } = require('./pushNotifications');
const { sendUserMessageTo1C } = require('./oneCChatOut');
const { handleDemoUserChatMessage, isDemoExternal1cId } = require('./demoFlow');
const { getPublicBaseUrl, toAbsoluteUrl } = require('../util/customsRequestDto');

const MAX_TEXT = 2000;

function normalize(v) {
  return String(v ?? '').trim();
}

function clipText(text) {
  const s = String(text ?? '');
  if (s.length <= MAX_TEXT) return s;
  return s.slice(0, MAX_TEXT);
}

/** Полный HTTPS URL для вложений чата (1С и МП). */
function absolutizeAttachments(attachments, publicBaseUrl) {
  if (!Array.isArray(attachments)) return [];
  const base = String(publicBaseUrl || '').replace(/\/$/, '');
  return attachments.map((a) => {
    if (!a || typeof a !== 'object') return a;
    const fileUrl = a.fileUrl != null ? toAbsoluteUrl(a.fileUrl, base) : a.fileUrl;
    return { ...a, fileUrl };
  });
}

function publicBaseFromFastify(fastify, request = null) {
  return getPublicBaseUrl(fastify, request);
}

function jsonAttachmentsOrNull(attachments) {
  if (!attachments) return null;
  return JSON.stringify(attachments);
}

function parseRowAttachments(value) {
  if (value == null) return null;
  if (typeof value === 'string') {
    try {
      return JSON.parse(value);
    } catch {
      return { raw: value };
    }
  }
  return value;
}

/** Разбор attachments_json → массив файлов + meta (sender/recipient). */
function splitAttachmentsPayload(parsed) {
  if (!parsed) {
    return { attachments: [], meta: {} };
  }
  if (Array.isArray(parsed)) {
    return { attachments: parsed, meta: {} };
  }
  if (typeof parsed === 'object') {
    const attachments = Array.isArray(parsed.attachments) ? parsed.attachments : [];
    const meta = parsed.meta && typeof parsed.meta === 'object' ? { ...parsed.meta } : {};
    // Старый формат: sender* могли лежать на корне рядом с attachments.
    if (meta.senderName == null && parsed.senderName != null) meta.senderName = parsed.senderName;
    if (meta.sender1cId == null && parsed.sender1cId != null) meta.sender1cId = parsed.sender1cId;
    if (meta.recipientName == null && parsed.recipientName != null) {
      meta.recipientName = parsed.recipientName;
    }
    return { attachments, meta };
  }
  return { attachments: [], meta: {} };
}

/**
 * Имена сторон заявки для чата (снимок / fallback для старых сообщений).
 * @returns {{ clientName: string, managerName: string }}
 */
async function resolveChatPartyNames(pool, requestId) {
  const id = Number(requestId);
  if (!Number.isFinite(id) || id <= 0) {
    return { clientName: 'Клиент', managerName: 'Менеджер' };
  }
  const [rows] = await pool.query(
    `SELECT r.individual_full_name, r.manager_full_name, r.organization_id,
            o.company_name, o.login
     FROM customs_requests r
     LEFT JOIN organizations o ON o.id = r.organization_id
     WHERE r.id = ?
     LIMIT 1`,
    [id],
  );
  if (!rows.length) {
    return { clientName: 'Клиент', managerName: 'Менеджер' };
  }
  const r = rows[0];
  const clientName = normalize(r.individual_full_name)
    || normalize(r.company_name)
    || normalize(r.login)
    || 'Клиент';
  const managerName = normalize(r.manager_full_name) || 'Менеджер';
  return { clientName, managerName };
}

const MESSAGE_SELECT = `id, request_id, author_type, user_id, direction, client_message_id, message_1c_id,
                text_content, attachments_json, delivery_status, delivered_to_1c_at, last_1c_error,
                read_by_user_at, read_by_1c_at, created_at, updated_at`;

/**
 * @param {object} row
 * @param {string|null} external1cId
 * @param {{ clientName?: string, managerName?: string }|null} parties
 * @param {string} [publicBaseUrl] — для абсолютных fileUrl во вложениях
 */
function messageDto(row, external1cId, parties = null, publicBaseUrl = '') {
  const parsed = parseRowAttachments(row.attachments_json);
  const { attachments, meta } = splitAttachmentsPayload(parsed);
  const authorType = row.author_type;
  const isFrom1c = authorType === 'manager_1c' || row.direction === 'from_1c';

  let senderName = normalize(meta.senderName) || null;
  let sender1cId = normalize(meta.sender1cId) || null;
  let recipientName = normalize(meta.recipientName) || null;

  if (!senderName) {
    senderName = isFrom1c
      ? (normalize(parties?.managerName) || 'Менеджер')
      : (normalize(parties?.clientName) || 'Клиент');
  }
  if (!recipientName) {
    recipientName = isFrom1c
      ? (normalize(parties?.clientName) || 'Клиент')
      : (normalize(parties?.managerName) || 'Менеджер');
  }

  return {
    id: row.id,
    requestId: row.request_id,
    external1cId: external1cId || null,
    authorType: row.author_type,
    direction: row.direction,
    clientMessageId: row.client_message_id,
    message1cId: row.message_1c_id,
    text: row.text_content,
    attachments: absolutizeAttachments(attachments, publicBaseUrl),
    sender1cId,
    senderName,
    recipientName,
    deliveryStatus: row.delivery_status,
    deliveredTo1cAt: row.delivered_to_1c_at,
    last1cError: row.last_1c_error,
    readByUserAt: row.read_by_user_at,
    readBy1cAt: row.read_by_1c_at,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

async function listMessageDtos(pool, requestId, external1cId, publicBaseUrl = '') {
  const parties = await resolveChatPartyNames(pool, requestId);
  const rows = await listMessagesAsc(pool, requestId);
  return rows.map((r) => messageDto(r, external1cId, parties, publicBaseUrl));
}

async function findRequestByExternal1cId(pool, external1cId) {
  const id = normalize(external1cId);
  if (!id) return null;
  const [rows] = await pool.query(
    `SELECT id, external_1c_id, deleted_at, organization_id
     FROM customs_requests
     WHERE external_1c_id = ? AND deleted_at IS NULL
     LIMIT 1`,
    [id],
  );
  return rows[0] || null;
}

async function findRequestById(pool, requestId) {
  const [rows] = await pool.query(
    `SELECT id, external_1c_id, deleted_at, organization_id
     FROM customs_requests
     WHERE id = ? AND deleted_at IS NULL
     LIMIT 1`,
    [requestId],
  );
  return rows[0] || null;
}

async function listMessagesAsc(pool, requestId) {
  const [rows] = await pool.query(
    `SELECT ${MESSAGE_SELECT}
     FROM customs_request_messages
     WHERE request_id = ? AND deleted_at IS NULL
     ORDER BY id ASC`,
    [requestId],
  );
  return rows;
}

async function loadMessageRow(pool, messageId) {
  const [rowRows] = await pool.query(
    `SELECT ${MESSAGE_SELECT}
     FROM customs_request_messages
     WHERE id = ?
     LIMIT 1`,
    [messageId],
  );
  return rowRows[0] || null;
}

/**
 * Сообщение менеджера из 1С (HTTP или WSS).
 */
async function createMessageFrom1c(fastify, {
  external1cId,
  message1cId,
  text,
  attachments = [],
  sender1cId,
  senderName,
}) {
  const extId = normalize(external1cId);
  const msgId = normalize(message1cId);
  const bodyText = clipText(text || '');
  const atts = Array.isArray(attachments) ? attachments : [];
  if (!extId || !msgId) {
    const e = new Error('VALIDATION_ERROR');
    e.code = 'VALIDATION_ERROR';
    e.messageRu = 'external1cId и message1cId обязательны';
    throw e;
  }
  if (!bodyText && !atts.length) {
    const e = new Error('VALIDATION_ERROR');
    e.code = 'VALIDATION_ERROR';
    e.messageRu = 'Пустое сообщение';
    throw e;
  }

  const reqRow = await findRequestByExternal1cId(fastify.pool, extId);
  if (!reqRow) {
    const e = new Error('NOT_FOUND');
    e.code = 'NOT_FOUND';
    throw e;
  }
  const requestId = reqRow.id;
  const parties = await resolveChatPartyNames(fastify.pool, requestId);
  const base = publicBaseFromFastify(fastify);
  const attsAbs = absolutizeAttachments(atts, base);

  const [ex] = await fastify.pool.query(
    `SELECT id FROM customs_request_messages WHERE message_1c_id=? AND deleted_at IS NULL LIMIT 1`,
    [msgId],
  );
  if (ex.length) {
    const existingRow = await loadMessageRow(fastify.pool, ex[0].id);
    return {
      ok: true,
      dedup: true,
      id: ex[0].id,
      requestId,
      external1cId: extId,
      message: existingRow ? messageDto(existingRow, extId, parties, base) : null,
    };
  }

  const meta = {
    sender1cId: normalize(sender1cId) || null,
    senderName: normalize(senderName) || parties.managerName,
    recipientName: parties.clientName,
  };
  const [ins] = await fastify.pool.query(
    `INSERT INTO customs_request_messages
      (request_id, author_type, user_id, direction, message_1c_id, text_content, attachments_json, delivery_status)
     VALUES
      (?, 'manager_1c', NULL, 'from_1c', ?, ?, ?, NULL)`,
    [
      requestId,
      msgId,
      bodyText,
      jsonAttachmentsOrNull({ attachments: attsAbs, meta }),
    ],
  );

  const newId = ins.insertId;
  const messageRow = await loadMessageRow(fastify.pool, newId);
  const dto = messageDto(messageRow, extId, parties, base);

  if (fastify.chatWss) {
    try {
      await fastify.chatWss.broadcast(requestId, {
        type: 'message_created',
        requestId,
        external1cId: extId,
        message: dto,
      });
    } catch (e) {
      fastify.log.error(e, 'chat broadcast failed (incoming 1C message)');
    }
  }

  notifyMessageFrom1C(fastify, {
    requestId,
    external1cId: extId,
    messageId: newId,
    text: bodyText,
  }).catch((e) => {
    fastify.log.warn({ requestId, err: e.message }, 'push notify incoming 1c message failed');
  });

  return {
    ok: true,
    dedup: false,
    id: newId,
    requestId,
    external1cId: extId,
    message: dto,
  };
}

/**
 * Сообщение клиента из МП (HTTP или WSS).
 */
async function createMessageFromUser(fastify, {
  requestId,
  userId,
  text,
  attachments = [],
  clientMessageId,
}) {
  const id = Number(requestId);
  const reqRow = await findRequestById(fastify.pool, id);
  if (!reqRow) {
    const e = new Error('NOT_FOUND');
    e.code = 'NOT_FOUND';
    throw e;
  }
  if (!reqRow.external_1c_id) {
    const e = new Error('CHAT_NOT_AVAILABLE');
    e.code = 'CHAT_NOT_AVAILABLE';
    e.messageRu = 'Чат недоступен';
    throw e;
  }

  const bodyText = clipText(text || '');
  const base = publicBaseFromFastify(fastify);
  const atts = absolutizeAttachments(
    Array.isArray(attachments) ? attachments : [],
    base,
  );
  if (!bodyText && !atts.length) {
    const e = new Error('VALIDATION_ERROR');
    e.code = 'VALIDATION_ERROR';
    e.messageRu = 'Пустое сообщение';
    throw e;
  }
  for (const a of atts) {
    if (!normalize(a.fileUrl)) {
      const e = new Error('VALIDATION_ERROR');
      e.code = 'VALIDATION_ERROR';
      e.messageRu = 'fileUrl обязателен';
      throw e;
    }
  }

  const cid = normalize(clientMessageId) || uuidv4();
  const [existing] = await fastify.pool.query(
    `SELECT ${MESSAGE_SELECT}
     FROM customs_request_messages
     WHERE client_message_id = ? AND deleted_at IS NULL
     LIMIT 1`,
    [cid],
  );
  if (existing.length) {
    const r = existing[0];
    const parties = await resolveChatPartyNames(fastify.pool, id);
    return {
      ok: true,
      dedup: true,
      id: r.id,
      requestId: id,
      message: messageDto(r, reqRow.external_1c_id, parties, base),
      oneC: { status: 200, via: 'dedup' },
    };
  }

  const parties = await resolveChatPartyNames(fastify.pool, id);
  const meta = {
    sender1cId: null,
    senderName: parties.clientName,
    recipientName: parties.managerName,
  };
  const payloadJson = { attachments: atts, meta };
  const [ins] = await fastify.pool.query(
    `INSERT INTO customs_request_messages
       (request_id, author_type, user_id, direction, client_message_id, text_content, attachments_json,
        delivery_status)
     VALUES (?, 'app_user', ?, 'to_1c', ?, ?, ?, 'pending')`,
    [id, userId, cid, bodyText, jsonAttachmentsOrNull(payloadJson)],
  );

  const messageId = ins.insertId;
  let messageRow = await loadMessageRow(fastify.pool, messageId);
  let oneC;

  if (isDemoExternal1cId(reqRow.external_1c_id)) {
    oneC = { status: 200, demo: true, via: 'demo' };
    await fastify.pool.query(
      `UPDATE customs_request_messages
       SET delivery_status='delivered',
           delivered_to_1c_at=NOW(3),
           last_1c_error=NULL
       WHERE id=? AND deleted_at IS NULL`,
      [messageId],
    );
    messageRow = await loadMessageRow(fastify.pool, messageId);
    handleDemoUserChatMessage(fastify, id, bodyText).catch((e) => {
      fastify.log.warn({ requestId: id, err: e.message }, 'demo chat reply failed');
    });
  } else {
    let deliverViaWss = false;
    if (fastify.chatWss) {
      try {
        const stats = await fastify.chatWss.roomStats(id);
        deliverViaWss = Number(stats.integrationSubscribers || 0) > 0;
      } catch (e) {
        fastify.log.warn({ err: e.message, requestId: id }, 'chat roomStats failed; fallback HTTP→1С');
      }
    }

    if (deliverViaWss) {
      oneC = { status: 200, via: 'wss' };
      await fastify.pool.query(
        `UPDATE customs_request_messages
         SET delivery_status='delivered',
             delivered_to_1c_at=NOW(3),
             last_1c_error=NULL
         WHERE id=? AND deleted_at IS NULL`,
        [messageId],
      );
      messageRow = await loadMessageRow(fastify.pool, messageId);
    } else {
      try {
        const { json } = await sendUserMessageTo1C(fastify, {
          external1cId: reqRow.external_1c_id,
          clientMessageId: cid,
          text: bodyText,
          attachmentsJson: atts,
          senderName: parties.clientName,
          recipientName: parties.managerName,
        });
        oneC = { status: 200, via: 'http', json };
        const externalMessageId = json && (json.oneCMessageId || json.message1cId || json.id_1c)
          ? String(json.oneCMessageId || json.message1cId || json.id_1c)
          : null;
        await fastify.pool.query(
          `UPDATE customs_request_messages
           SET delivery_status='delivered',
               delivered_to_1c_at=NOW(3),
               last_1c_error=NULL
           WHERE id=? AND deleted_at IS NULL`,
          [messageId],
        );
        if (externalMessageId) {
          await fastify.pool.query(
            `UPDATE customs_request_messages SET message_1c_id=COALESCE(message_1c_id, ?) WHERE id=? AND deleted_at IS NULL`,
            [externalMessageId, messageId],
          );
        }
        messageRow = await loadMessageRow(fastify.pool, messageId);
      } catch (e) {
        oneC = { error: e.message, body: e.body || null, via: 'http' };
        await fastify.pool.query(
          `UPDATE customs_request_messages
           SET delivery_status='failed', last_1c_error=?
           WHERE id=? AND deleted_at IS NULL`,
          [String(e.message || 'ONE_C_ERROR').slice(0, 1000), messageId],
        );
        messageRow = await loadMessageRow(fastify.pool, messageId);
      }
    }
  }

  const dto = messageDto(messageRow, reqRow.external_1c_id, parties, base);
  let wssBroadcast = null;
  if (fastify.chatWss) {
    try {
      wssBroadcast = await fastify.chatWss.broadcast(id, {
        type: 'message_created',
        requestId: id,
        external1cId: reqRow.external_1c_id || null,
        message: dto,
        oneC: oneC && oneC.status === 200
          ? { ok: true, via: oneC.via || null, response: oneC.json || null }
          : { ok: false, error: oneC?.error || oneC },
      });
    } catch (e) {
      fastify.log.error(e, 'chat broadcast failed (outgoing user message)');
    }
  }

  if (
    oneC &&
    oneC.via === 'wss' &&
    !isDemoExternal1cId(reqRow.external_1c_id) &&
    Number(wssBroadcast?.integrationDelivered || 0) === 0
  ) {
    try {
      const { json } = await sendUserMessageTo1C(fastify, {
        external1cId: reqRow.external_1c_id,
        clientMessageId: cid,
        text: bodyText,
        attachmentsJson: atts,
        senderName: parties.clientName,
        recipientName: parties.managerName,
      });
      oneC = { status: 200, via: 'http', fallbackFromWss: true, json };
      await fastify.pool.query(
        `UPDATE customs_request_messages
         SET delivery_status='delivered',
             delivered_to_1c_at=NOW(3),
             last_1c_error=NULL
         WHERE id=? AND deleted_at IS NULL`,
        [messageId],
      );
      messageRow = await loadMessageRow(fastify.pool, messageId);
    } catch (e) {
      oneC = { error: e.message, body: e.body || null, via: 'http', fallbackFromWss: true };
      await fastify.pool.query(
        `UPDATE customs_request_messages
         SET delivery_status='failed', last_1c_error=?
         WHERE id=? AND deleted_at IS NULL`,
        [String(e.message || 'ONE_C_ERROR').slice(0, 1000), messageId],
      );
      messageRow = await loadMessageRow(fastify.pool, messageId);
    }
  }

  return {
    ok: true,
    dedup: false,
    id: messageId,
    requestId: id,
    message: messageDto(messageRow, reqRow.external_1c_id, parties, base),
    oneC,
  };
}

async function markReadByUser(fastify, { requestId, upToMessageId }) {
  const upTo = Number(upToMessageId);
  if (!Number.isFinite(upTo) || upTo <= 0) {
    const e = new Error('VALIDATION_ERROR');
    e.code = 'VALIDATION_ERROR';
    e.messageRu = 'Некорректный upToMessageId';
    throw e;
  }
  const [r] = await fastify.pool.query(
    `UPDATE customs_request_messages
     SET read_by_user_at=NOW(3)
     WHERE request_id=?
       AND id<=?
       AND direction='from_1c'
       AND read_by_user_at IS NULL
       AND deleted_at IS NULL`,
    [requestId, upTo],
  );
  const updated = r.affectedRows || 0;
  if (fastify.chatWss) {
    try {
      await fastify.chatWss.broadcast(requestId, {
        type: 'read',
        requestId,
        upToMessageId: upTo,
        by: 'user',
        updated,
      });
    } catch (e) {
      fastify.log.error(e, 'chat broadcast failed (read by user)');
    }
  }
  return { ok: true, updated, upToMessageId: upTo, by: 'user' };
}

async function markReadBy1c(fastify, { requestId, upToMessageId }) {
  const upTo = Number(upToMessageId);
  if (!Number.isFinite(upTo) || upTo <= 0) {
    const e = new Error('VALIDATION_ERROR');
    e.code = 'VALIDATION_ERROR';
    e.messageRu = 'Некорректный upToMessageId';
    throw e;
  }
  const [r] = await fastify.pool.query(
    `UPDATE customs_request_messages
     SET read_by_1c_at=NOW(3)
     WHERE request_id=?
       AND id<=?
       AND direction='to_1c'
       AND read_by_1c_at IS NULL
       AND deleted_at IS NULL`,
    [requestId, upTo],
  );
  const updated = r.affectedRows || 0;
  if (fastify.chatWss) {
    try {
      await fastify.chatWss.broadcast(requestId, {
        type: 'read',
        requestId,
        upToMessageId: upTo,
        by: '1c',
        updated,
      });
    } catch (e) {
      fastify.log.error(e, 'chat broadcast failed (read by 1c)');
    }
  }
  return { ok: true, updated, upToMessageId: upTo, by: '1c' };
}

module.exports = {
  MAX_TEXT,
  normalize,
  clipText,
  absolutizeAttachments,
  publicBaseFromFastify,
  jsonAttachmentsOrNull,
  parseRowAttachments,
  splitAttachmentsPayload,
  resolveChatPartyNames,
  messageDto,
  listMessageDtos,
  findRequestByExternal1cId,
  findRequestById,
  listMessagesAsc,
  createMessageFrom1c,
  createMessageFromUser,
  markReadByUser,
  markReadBy1c,
};
