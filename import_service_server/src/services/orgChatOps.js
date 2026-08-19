const { v4: uuidv4 } = require('uuid');
const {
  MAX_TEXT,
  normalize,
  clipText,
  normalizeMessageAttachments,
  jsonAttachmentsOrNull,
  parseRowAttachments,
  splitAttachmentsPayload,
  messageDto,
} = require('./chatMessageOps');
const { notifyOrgMessageFrom1C } = require('./pushNotifications');
const { sendOrgUserMessageTo1C } = require('./oneCChatOut');

const ORG_CHAT_LIST_ID = 'org';
const MESSAGE_SELECT = `id, organization_id, author_type, user_id, direction, client_message_id, message_1c_id,
                text_content, attachments_json, delivery_status, delivered_to_1c_at, last_1c_error,
                read_by_user_at, read_by_1c_at, created_at, updated_at`;

function orgRoomId(organizationId) {
  return `org:${Number(organizationId)}`;
}

function toIsoDate(value) {
  if (!value) return null;
  try {
    return new Date(value).toISOString();
  } catch {
    return null;
  }
}

function clipPreview(text) {
  const s = String(text ?? '').replace(/\s+/g, ' ').trim();
  if (!s) return '';
  if (s.length <= 80) return s;
  return `${s.slice(0, 80)}…`;
}

function lastPreview(textContent, attachmentsJson) {
  const fromText = clipPreview(textContent);
  if (fromText) return fromText;
  const parsed = parseRowAttachments(attachmentsJson);
  const { attachments } = splitAttachmentsPayload(parsed);
  if (!attachments.length) return '';
  return normalize(attachments[0]?.fileName) || '';
}

async function findOrganizationById(pool, organizationId) {
  const id = Number(organizationId);
  if (!Number.isFinite(id) || id <= 0) return null;
  const [rows] = await pool.query(
    `SELECT id, id_1c, company_name, login, deleted_at
     FROM organizations
     WHERE id = ? AND deleted_at IS NULL
     LIMIT 1`,
    [id],
  );
  return rows[0] || null;
}

async function findOrganizationById1c(pool, id1c) {
  const key = normalize(id1c);
  if (!key) return null;
  const [rows] = await pool.query(
    `SELECT id, id_1c, company_name, login, deleted_at
     FROM organizations
     WHERE id_1c = ? AND deleted_at IS NULL
     LIMIT 1`,
    [key],
  );
  return rows[0] || null;
}

async function resolveOrgChatParties(pool, organizationId) {
  const org = await findOrganizationById(pool, organizationId);
  const clientName = normalize(org?.company_name) || normalize(org?.login) || 'Клиент';
  return { clientName, managerName: 'Менеджер' };
}

function orgMessageDto(row, id1c, parties = null) {
  const base = messageDto(
    { ...row, request_id: row.organization_id },
    id1c || null,
    parties,
  );
  return {
    ...base,
    requestId: null,
    organizationId: Number(row.organization_id),
    id1c: id1c || null,
    chatKind: 'org',
  };
}

async function loadOrgMessageRow(pool, messageId) {
  const [rows] = await pool.query(
    `SELECT ${MESSAGE_SELECT}
     FROM organization_messages
     WHERE id = ?
     LIMIT 1`,
    [messageId],
  );
  return rows[0] || null;
}

async function listOrgMessageDtos(pool, organizationId, id1c) {
  const parties = await resolveOrgChatParties(pool, organizationId);
  const [rows] = await pool.query(
    `SELECT ${MESSAGE_SELECT}
     FROM organization_messages
     WHERE organization_id = ? AND deleted_at IS NULL
     ORDER BY id ASC`,
    [organizationId],
  );
  return rows.map((r) => orgMessageDto(r, id1c, parties));
}

async function getOrgChatListPreview(pool, organizationId) {
  const orgId = Number(organizationId);
  if (!Number.isFinite(orgId) || orgId <= 0) return null;
  const [lastRows] = await pool.query(
    `SELECT text_content, created_at, attachments_json
     FROM organization_messages
     WHERE organization_id = ? AND deleted_at IS NULL
     ORDER BY id DESC
     LIMIT 1`,
    [orgId],
  );
  const [unreadRows] = await pool.query(
    `SELECT COUNT(*) AS unread_count
     FROM organization_messages
     WHERE organization_id = ?
       AND deleted_at IS NULL
       AND direction = 'from_1c'
       AND read_by_user_at IS NULL`,
    [orgId],
  );
  const last = lastRows[0];
  const unreadCount = Number(unreadRows[0]?.unread_count) || 0;
  return {
    kind: 'org',
    requestId: ORG_CHAT_LIST_ID,
    organizationId: orgId,
    carMake: '',
    carModel: '',
    vin: '',
    managerFullName: null,
    external1cId: null,
    lastText: last ? lastPreview(last.text_content, last.attachments_json) || null : null,
    lastAt: last ? toIsoDate(last.created_at) : null,
    unread: unreadCount > 0,
    unreadCount,
  };
}

async function createOrgMessageFrom1c(fastify, {
  id1c,
  message1cId,
  text,
  attachments = [],
  sender1cId,
  senderName,
}) {
  const orgKey = normalize(id1c);
  const msgId = normalize(message1cId);
  const bodyText = clipText(text || '');
  const atts = Array.isArray(attachments) ? attachments : [];
  if (!orgKey || !msgId) {
    const e = new Error('VALIDATION_ERROR');
    e.code = 'VALIDATION_ERROR';
    e.messageRu = 'id_1c и message1cId обязательны';
    throw e;
  }
  if (!bodyText && !atts.length) {
    const e = new Error('VALIDATION_ERROR');
    e.code = 'VALIDATION_ERROR';
    e.messageRu = 'Пустое сообщение';
    throw e;
  }

  const org = await findOrganizationById1c(fastify.pool, orgKey);
  if (!org) {
    const e = new Error('NOT_FOUND');
    e.code = 'NOT_FOUND';
    throw e;
  }
  const organizationId = Number(org.id);
  const parties = await resolveOrgChatParties(fastify.pool, organizationId);
  const attsNorm = normalizeMessageAttachments(atts);

  const [ex] = await fastify.pool.query(
    `SELECT id FROM organization_messages WHERE message_1c_id=? AND deleted_at IS NULL LIMIT 1`,
    [msgId],
  );
  if (ex.length) {
    const existingRow = await loadOrgMessageRow(fastify.pool, ex[0].id);
    return {
      ok: true,
      dedup: true,
      id: ex[0].id,
      organizationId,
      id1c: orgKey,
      message: existingRow ? orgMessageDto(existingRow, orgKey, parties) : null,
    };
  }

  const meta = {
    sender1cId: normalize(sender1cId) || null,
    senderName: normalize(senderName) || parties.managerName,
    recipientName: parties.clientName,
  };
  const [ins] = await fastify.pool.query(
    `INSERT INTO organization_messages
      (organization_id, author_type, user_id, direction, message_1c_id, text_content, attachments_json, delivery_status)
     VALUES
      (?, 'manager_1c', NULL, 'from_1c', ?, ?, ?, NULL)`,
    [organizationId, msgId, bodyText, jsonAttachmentsOrNull({ attachments: attsNorm, meta })],
  );

  const newId = ins.insertId;
  const messageRow = await loadOrgMessageRow(fastify.pool, newId);
  const dto = orgMessageDto(messageRow, orgKey, parties);
  const roomId = orgRoomId(organizationId);

  if (fastify.chatWss) {
    try {
      await fastify.chatWss.broadcast(roomId, {
        type: 'message_created',
        chatKind: 'org',
        organizationId,
        id1c: orgKey,
        message: dto,
      });
    } catch (e) {
      fastify.log.error(e, 'org chat broadcast failed (incoming 1C message)');
    }
  }

  notifyOrgMessageFrom1C(fastify, {
    organizationId,
    messageId: newId,
    text: bodyText,
  }).catch((e) => {
    fastify.log.warn({ organizationId, err: e.message }, 'push notify org 1c message failed');
  });

  return {
    ok: true,
    dedup: false,
    id: newId,
    organizationId,
    id1c: orgKey,
    message: dto,
  };
}

async function createOrgMessageFromUser(fastify, {
  organizationId,
  userId,
  text,
  attachments = [],
  clientMessageId,
}) {
  const orgId = Number(organizationId);
  const org = await findOrganizationById(fastify.pool, orgId);
  if (!org) {
    const e = new Error('NOT_FOUND');
    e.code = 'NOT_FOUND';
    throw e;
  }

  const bodyText = clipText(text || '');
  const atts = normalizeMessageAttachments(Array.isArray(attachments) ? attachments : []);
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
     FROM organization_messages
     WHERE client_message_id = ? AND deleted_at IS NULL
     LIMIT 1`,
    [cid],
  );
  const parties = await resolveOrgChatParties(fastify.pool, orgId);
  const id1c = org.id_1c || null;
  if (existing.length) {
    return {
      ok: true,
      dedup: true,
      id: existing[0].id,
      organizationId: orgId,
      message: orgMessageDto(existing[0], id1c, parties),
      oneC: { status: 200, via: 'dedup' },
    };
  }

  const meta = {
    sender1cId: null,
    senderName: parties.clientName,
    recipientName: parties.managerName,
  };
  const [ins] = await fastify.pool.query(
    `INSERT INTO organization_messages
       (organization_id, author_type, user_id, direction, client_message_id, text_content, attachments_json,
        delivery_status)
     VALUES (?, 'app_user', ?, 'to_1c', ?, ?, ?, 'pending')`,
    [orgId, userId, cid, bodyText, jsonAttachmentsOrNull({ attachments: atts, meta })],
  );

  const messageId = ins.insertId;
  let messageRow = await loadOrgMessageRow(fastify.pool, messageId);
  let oneC;
  const roomId = orgRoomId(orgId);

  let deliverViaWss = false;
  if (fastify.chatWss) {
    try {
      const stats = await fastify.chatWss.roomStats(roomId);
      deliverViaWss = Number(stats.integrationSubscribers || 0) > 0;
    } catch (e) {
      fastify.log.warn({ err: e.message, organizationId: orgId }, 'org chat roomStats failed; fallback HTTP→1С');
    }
  }

  if (deliverViaWss) {
    oneC = { status: 200, via: 'wss' };
    await fastify.pool.query(
      `UPDATE organization_messages
       SET delivery_status='delivered', delivered_to_1c_at=NOW(3), last_1c_error=NULL
       WHERE id=? AND deleted_at IS NULL`,
      [messageId],
    );
    messageRow = await loadOrgMessageRow(fastify.pool, messageId);
  } else {
    try {
      const { json } = await sendOrgUserMessageTo1C(fastify, {
        id1c,
        organizationId: orgId,
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
        `UPDATE organization_messages
         SET delivery_status='delivered', delivered_to_1c_at=NOW(3), last_1c_error=NULL
         WHERE id=? AND deleted_at IS NULL`,
        [messageId],
      );
      if (externalMessageId) {
        await fastify.pool.query(
          `UPDATE organization_messages SET message_1c_id=COALESCE(message_1c_id, ?) WHERE id=? AND deleted_at IS NULL`,
          [externalMessageId, messageId],
        );
      }
      messageRow = await loadOrgMessageRow(fastify.pool, messageId);
    } catch (e) {
      oneC = { error: e.message, body: e.body || null, via: 'http' };
      await fastify.pool.query(
        `UPDATE organization_messages SET delivery_status='failed', last_1c_error=? WHERE id=? AND deleted_at IS NULL`,
        [String(e.message || 'ONE_C_ERROR').slice(0, 1000), messageId],
      );
      messageRow = await loadOrgMessageRow(fastify.pool, messageId);
    }
  }

  const dto = orgMessageDto(messageRow, id1c, parties);
  let wssBroadcast = null;
  if (fastify.chatWss) {
    try {
      wssBroadcast = await fastify.chatWss.broadcast(roomId, {
        type: 'message_created',
        chatKind: 'org',
        organizationId: orgId,
        id1c,
        message: dto,
        oneC: oneC && oneC.status === 200
          ? { ok: true, via: oneC.via || null, response: oneC.json || null }
          : { ok: false, error: oneC?.error || oneC },
      });
    } catch (e) {
      fastify.log.error(e, 'org chat broadcast failed (outgoing user message)');
    }
  }

  if (oneC && oneC.via === 'wss' && Number(wssBroadcast?.integrationDelivered || 0) === 0) {
    try {
      const { json } = await sendOrgUserMessageTo1C(fastify, {
        id1c,
        organizationId: orgId,
        clientMessageId: cid,
        text: bodyText,
        attachmentsJson: atts,
        senderName: parties.clientName,
        recipientName: parties.managerName,
      });
      oneC = { status: 200, via: 'http', fallbackFromWss: true, json };
      await fastify.pool.query(
        `UPDATE organization_messages
         SET delivery_status='delivered', delivered_to_1c_at=NOW(3), last_1c_error=NULL
         WHERE id=? AND deleted_at IS NULL`,
        [messageId],
      );
      messageRow = await loadOrgMessageRow(fastify.pool, messageId);
    } catch (e) {
      oneC = { error: e.message, body: e.body || null, via: 'http', fallbackFromWss: true };
      await fastify.pool.query(
        `UPDATE organization_messages SET delivery_status='failed', last_1c_error=? WHERE id=? AND deleted_at IS NULL`,
        [String(e.message || 'ONE_C_ERROR').slice(0, 1000), messageId],
      );
      messageRow = await loadOrgMessageRow(fastify.pool, messageId);
    }
  }

  return {
    ok: true,
    dedup: false,
    id: messageId,
    organizationId: orgId,
    message: orgMessageDto(messageRow, id1c, parties),
    oneC,
  };
}

async function markOrgReadByUser(fastify, { organizationId, upToMessageId }) {
  const upTo = Number(upToMessageId);
  if (!Number.isFinite(upTo) || upTo <= 0) {
    const e = new Error('VALIDATION_ERROR');
    e.code = 'VALIDATION_ERROR';
    e.messageRu = 'Некорректный upToMessageId';
    throw e;
  }
  const orgId = Number(organizationId);
  const [r] = await fastify.pool.query(
    `UPDATE organization_messages
     SET read_by_user_at=NOW(3)
     WHERE organization_id=?
       AND id<=?
       AND direction='from_1c'
       AND read_by_user_at IS NULL
       AND deleted_at IS NULL`,
    [orgId, upTo],
  );
  const updated = r.affectedRows || 0;
  if (fastify.chatWss) {
    try {
      await fastify.chatWss.broadcast(orgRoomId(orgId), {
        type: 'read',
        chatKind: 'org',
        organizationId: orgId,
        upToMessageId: upTo,
        by: 'user',
        updated,
      });
    } catch (e) {
      fastify.log.error(e, 'org chat broadcast failed (read by user)');
    }
  }
  return { ok: true, updated, upToMessageId: upTo, by: 'user' };
}

async function markOrgReadBy1c(fastify, { organizationId, upToMessageId }) {
  const upTo = Number(upToMessageId);
  if (!Number.isFinite(upTo) || upTo <= 0) {
    const e = new Error('VALIDATION_ERROR');
    e.code = 'VALIDATION_ERROR';
    e.messageRu = 'Некорректный upToMessageId';
    throw e;
  }
  const orgId = Number(organizationId);
  const [r] = await fastify.pool.query(
    `UPDATE organization_messages
     SET read_by_1c_at=NOW(3)
     WHERE organization_id=?
       AND id<=?
       AND direction='to_1c'
       AND read_by_1c_at IS NULL
       AND deleted_at IS NULL`,
    [orgId, upTo],
  );
  const updated = r.affectedRows || 0;
  if (fastify.chatWss) {
    try {
      await fastify.chatWss.broadcast(orgRoomId(orgId), {
        type: 'read',
        chatKind: 'org',
        organizationId: orgId,
        upToMessageId: upTo,
        by: '1c',
        updated,
      });
    } catch (e) {
      fastify.log.error(e, 'org chat broadcast failed (read by 1c)');
    }
  }
  return { ok: true, updated, upToMessageId: upTo, by: '1c' };
}

module.exports = {
  ORG_CHAT_LIST_ID,
  orgRoomId,
  findOrganizationById,
  findOrganizationById1c,
  orgMessageDto,
  listOrgMessageDtos,
  getOrgChatListPreview,
  resolveOrgChatParties,
  createOrgMessageFrom1c,
  createOrgMessageFromUser,
  markOrgReadByUser,
  markOrgReadBy1c,
  MAX_TEXT,
};
