const { notifyMessageFrom1C } = require('./pushNotifications');

const MAX_TEXT = 2000;

function normalize(v) {
  return String(v ?? '').trim();
}

function clipText(text) {
  const s = String(text ?? '');
  if (s.length <= MAX_TEXT) return s;
  return s.slice(0, MAX_TEXT);
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

function messageDto(row, external1cId) {
  const parsed = parseRowAttachments(row.attachments_json);
  return {
    id: row.id,
    requestId: row.request_id,
    external1cId: external1cId || null,
    authorType: row.author_type,
    direction: row.direction,
    clientMessageId: row.client_message_id,
    message1cId: row.message_1c_id,
    text: row.text_content,
    attachments: parsed,
    deliveryStatus: row.delivery_status,
    deliveredTo1cAt: row.delivered_to_1c_at,
    last1cError: row.last_1c_error,
    readByUserAt: row.read_by_user_at,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
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

async function listMessagesAsc(pool, requestId) {
  const [rows] = await pool.query(
    `SELECT id, request_id, author_type, user_id, direction, client_message_id, message_1c_id,
            text_content, attachments_json, delivery_status, delivered_to_1c_at, last_1c_error,
            read_by_user_at, created_at, updated_at
     FROM customs_request_messages
     WHERE request_id = ? AND deleted_at IS NULL
     ORDER BY id ASC`,
    [requestId],
  );
  return rows;
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

  const [ex] = await fastify.pool.query(
    `SELECT id FROM customs_request_messages WHERE message_1c_id=? AND deleted_at IS NULL LIMIT 1`,
    [msgId],
  );
  if (ex.length) {
    return { ok: true, dedup: true, id: ex[0].id, requestId, external1cId: extId };
  }

  const meta = {
    sender1cId: sender1cId || null,
    senderName: senderName || null,
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
      jsonAttachmentsOrNull(atts.length ? { attachments: atts, meta } : { attachments: [], meta }),
    ],
  );

  const newId = ins.insertId;
  const [rowRows] = await fastify.pool.query(
    `SELECT id, request_id, author_type, user_id, direction, client_message_id, message_1c_id,
            text_content, attachments_json, delivery_status, delivered_to_1c_at, last_1c_error,
            read_by_user_at, created_at, updated_at
     FROM customs_request_messages
     WHERE id=?
     LIMIT 1`,
    [newId],
  );
  const messageRow = rowRows[0];
  const dto = messageDto(messageRow, extId);

  if (fastify.chatWss) {
    try {
      await fastify.chatWss.broadcast(requestId, {
        type: 'message_incoming',
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

module.exports = {
  MAX_TEXT,
  normalize,
  clipText,
  jsonAttachmentsOrNull,
  parseRowAttachments,
  messageDto,
  findRequestByExternal1cId,
  listMessagesAsc,
  createMessageFrom1c,
};
