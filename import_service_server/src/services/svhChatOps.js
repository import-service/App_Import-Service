const { randomUUID } = require('crypto');
const { notifySvhChatMessage } = require('./pushNotifications');

const MAX_TEXT = 2000;

function normalize(v) {
  return String(v ?? '').trim();
}

function clipText(text) {
  const s = normalize(text);
  if (s.length <= MAX_TEXT) return s;
  return s.slice(0, MAX_TEXT);
}

function toIsoDate(v) {
  if (!v) return null;
  const d = v instanceof Date ? v : new Date(v);
  if (Number.isNaN(d.getTime())) return null;
  return d.toISOString();
}

function normalizeMessageAttachments(list) {
  if (!Array.isArray(list)) return [];
  return list
    .map((a) => {
      if (!a || typeof a !== 'object') return null;
      const fileUrl = normalize(a.fileUrl || a.file_url);
      if (!fileUrl) return null;
      return {
        fileUrl,
        fileName: normalize(a.fileName || a.file_name) || null,
        mimeType: normalize(a.mimeType || a.mime_type) || null,
      };
    })
    .filter(Boolean)
    .slice(0, 10);
}

function jsonAttachmentsOrNull(atts) {
  if (!atts || !atts.length) return null;
  return JSON.stringify(atts);
}

function parseRowAttachments(raw) {
  if (raw == null) return [];
  let parsed = raw;
  if (typeof raw === 'string') {
    try {
      parsed = JSON.parse(raw);
    } catch {
      return [];
    }
  }
  if (Array.isArray(parsed)) {
    return normalizeMessageAttachments(parsed);
  }
  if (parsed && Array.isArray(parsed.attachments)) {
    return normalizeMessageAttachments(parsed.attachments);
  }
  return [];
}

function lastMessagePreviewText(text, attachmentsJson) {
  const t = normalize(text);
  if (t) return t.length > 120 ? `${t.slice(0, 119)}…` : t;
  const atts = parseRowAttachments(attachmentsJson);
  if (atts.length) return 'Вложение';
  return '';
}

const MESSAGE_SELECT = `
  id, request_id, svh_manager_id, author_type, author_org_id, client_message_id,
  text_content, attachments_json, read_by_client_at, read_by_svh_at,
  created_at, updated_at
`;

function messageDto(row, names = {}, { viewerIsSvh = false } = {}) {
  const authorType = String(row.author_type || '');
  const fromSvh = authorType === 'svh_manager';
  // isFrom1c в МП = «входящее для текущего зрителя» (переиспользуем UI пузырей).
  const isIncoming = viewerIsSvh ? !fromSvh : fromSvh;
  return {
    id: Number(row.id),
    requestId: Number(row.request_id),
    svhManagerId: Number(row.svh_manager_id),
    authorType,
    direction: fromSvh ? 'from_svh' : 'to_svh',
    clientMessageId: row.client_message_id || null,
    text: row.text_content != null ? String(row.text_content) : '',
    attachments: parseRowAttachments(row.attachments_json),
    readByClient: Boolean(row.read_by_client_at),
    readBySvh: Boolean(row.read_by_svh_at),
    isFrom1c: isIncoming,
    createdAt: toIsoDate(row.created_at),
    senderName: fromSvh ? names.svhName || null : names.clientName || null,
    kind: 'svh',
  };
}

async function loadMessageRow(pool, id) {
  const [rows] = await pool.query(
    `SELECT ${MESSAGE_SELECT}
     FROM svh_request_messages
     WHERE id = ? AND deleted_at IS NULL
     LIMIT 1`,
    [id],
  );
  return rows[0] || null;
}

async function resolveSvhChatNames(pool, requestId, svhManagerId) {
  const [reqRows] = await pool.query(
    `SELECT individual_full_name, legal_entity_name, organization_id
     FROM customs_requests
     WHERE id = ? AND deleted_at IS NULL
     LIMIT 1`,
    [requestId],
  );
  const [svhRows] = await pool.query(
    `SELECT company_name
     FROM organizations
     WHERE id = ? AND deleted_at IS NULL
     LIMIT 1`,
    [svhManagerId],
  );
  const r = reqRows[0];
  const s = svhRows[0];
  const clientName =
    normalize(r?.individual_full_name) ||
    normalize(r?.legal_entity_name) ||
    null;
  const svhName = normalize(s?.company_name) || 'Менеджер СВХ';
  return {
    clientName,
    svhName,
    organizationId: r ? Number(r.organization_id) : null,
  };
}

async function assertRequestExists(pool, requestId) {
  const [rows] = await pool.query(
    `SELECT id, organization_id, deleted_at, car_make, car_model, vin,
            individual_full_name, legal_entity_name
     FROM customs_requests
     WHERE id = ?
     LIMIT 1`,
    [requestId],
  );
  if (!rows.length || rows[0].deleted_at) {
    return null;
  }
  return rows[0];
}

/**
 * @param {'svh'|'client'} asRole
 */
async function listSvhMessages(pool, {
  requestId,
  svhManagerId,
  limit = 50,
  beforeId = 0,
  viewerIsSvh = false,
}) {
  const args = [requestId, svhManagerId];
  let where =
    'request_id = ? AND svh_manager_id = ? AND deleted_at IS NULL';
  if (beforeId > 0) {
    where += ' AND id < ?';
    args.push(beforeId);
  }
  args.push(limit);
  const [rows] = await pool.query(
    `SELECT ${MESSAGE_SELECT}
     FROM svh_request_messages
     WHERE ${where}
     ORDER BY id DESC
     LIMIT ?`,
    args,
  );
  const names = await resolveSvhChatNames(pool, requestId, svhManagerId);
  return rows.map((r) => messageDto(r, names, { viewerIsSvh }));
}

async function createSvhMessage(fastify, {
  requestId,
  svhManagerId,
  authorType,
  authorOrgId,
  text,
  attachments = [],
  clientMessageId,
}) {
  const id = Number(requestId);
  const managerId = Number(svhManagerId);
  const reqRow = await assertRequestExists(fastify.pool, id);
  if (!reqRow) {
    const e = new Error('NOT_FOUND');
    e.code = 'NOT_FOUND';
    throw e;
  }
  if (!Number.isFinite(managerId) || managerId <= 0) {
    const e = new Error('VALIDATION_ERROR');
    e.code = 'VALIDATION_ERROR';
    e.messageRu = 'Некорректный svhManagerId';
    throw e;
  }

  const bodyText = clipText(text || '');
  const atts = normalizeMessageAttachments(attachments);
  if (!bodyText && !atts.length) {
    const e = new Error('VALIDATION_ERROR');
    e.code = 'VALIDATION_ERROR';
    e.messageRu = 'Пустое сообщение';
    throw e;
  }

  const cid = normalize(clientMessageId) || randomUUID();
  const [existing] = await fastify.pool.query(
    `SELECT ${MESSAGE_SELECT}
     FROM svh_request_messages
     WHERE client_message_id = ? AND deleted_at IS NULL
     LIMIT 1`,
    [cid],
  );
  if (existing.length) {
    const names = await resolveSvhChatNames(fastify.pool, id, managerId);
    return {
      ok: true,
      dedup: true,
      id: existing[0].id,
      message: messageDto(existing[0], names, {
        viewerIsSvh: authorType === 'svh_manager',
      }),
    };
  }

  const [ins] = await fastify.pool.query(
    `INSERT INTO svh_request_messages
       (request_id, svh_manager_id, author_type, author_org_id, client_message_id,
        text_content, attachments_json,
        read_by_client_at, read_by_svh_at)
     VALUES (?, ?, ?, ?, ?, ?, ?,
             ${authorType === 'app_user' ? 'NOW(3)' : 'NULL'},
             ${authorType === 'svh_manager' ? 'NOW(3)' : 'NULL'})`,
    [
      id,
      managerId,
      authorType,
      authorOrgId || null,
      cid,
      bodyText,
      jsonAttachmentsOrNull(atts),
    ],
  );

  const row = await loadMessageRow(fastify.pool, ins.insertId);
  const names = await resolveSvhChatNames(fastify.pool, id, managerId);
  const dto = messageDto(row, names, {
    viewerIsSvh: authorType === 'svh_manager',
  });

  try {
    await notifySvhChatMessage(fastify, {
      requestId: id,
      svhManagerId: managerId,
      clientOrgId: Number(reqRow.organization_id),
      fromSvh: authorType === 'svh_manager',
      text: bodyText,
      messageId: dto.id,
      carMake: reqRow.car_make,
      carModel: reqRow.car_model,
    });
  } catch (e) {
    fastify.log.error(e, 'svh chat push failed');
  }

  return { ok: true, id: dto.id, message: dto };
}

async function markSvhRead(pool, {
  requestId,
  svhManagerId,
  upToMessageId,
  asRole,
}) {
  const upTo = Number(upToMessageId);
  if (!Number.isFinite(upTo) || upTo <= 0) {
    const e = new Error('VALIDATION_ERROR');
    e.code = 'VALIDATION_ERROR';
    e.messageRu = 'Некорректный upToMessageId';
    throw e;
  }
  if (asRole === 'client') {
    await pool.query(
      `UPDATE svh_request_messages
       SET read_by_client_at = NOW(3)
       WHERE request_id = ?
         AND svh_manager_id = ?
         AND id <= ?
         AND author_type = 'svh_manager'
         AND read_by_client_at IS NULL
         AND deleted_at IS NULL`,
      [requestId, svhManagerId, upTo],
    );
  } else {
    await pool.query(
      `UPDATE svh_request_messages
       SET read_by_svh_at = NOW(3)
       WHERE request_id = ?
         AND svh_manager_id = ?
         AND id <= ?
         AND author_type = 'app_user'
         AND read_by_svh_at IS NULL
         AND deleted_at IS NULL`,
      [requestId, svhManagerId, upTo],
    );
  }
  return { ok: true };
}

/**
 * Список чатов СВХ для менеджера (только его) или для клиента (его заявки).
 * @param {'svh'|'client'} asRole
 */
async function listSvhChats(pool, { asRole, svhManagerId = null, clientOrgId = null }) {
  const args = [];
  let filter = '';
  if (asRole === 'svh') {
    const mid = Number(svhManagerId);
    if (!Number.isFinite(mid) || mid <= 0) return [];
    filter = 'AND m.svh_manager_id = ?';
    args.push(mid);
  } else {
    const oid = Number(clientOrgId);
    if (!Number.isFinite(oid) || oid <= 0) return [];
    filter = 'AND r.organization_id = ?';
    args.push(oid);
  }

  const [rows] = await pool.query(
    `SELECT
       r.id AS request_id,
       r.car_make,
       r.car_model,
       r.vin,
       r.individual_full_name,
       r.legal_entity_name,
       m.svh_manager_id,
       o.company_name AS svh_company_name,
       lm.id AS last_message_id,
       lm.text_content AS last_text,
       lm.created_at AS last_at,
       lm.attachments_json AS last_attachments_json,
       COALESCE(u.unread_count, 0) AS unread_count
     FROM (
       SELECT DISTINCT request_id, svh_manager_id
       FROM svh_request_messages
       WHERE deleted_at IS NULL
     ) m
     INNER JOIN customs_requests r
       ON r.id = m.request_id AND r.deleted_at IS NULL
     LEFT JOIN organizations o
       ON o.id = m.svh_manager_id AND o.deleted_at IS NULL
     LEFT JOIN svh_request_messages lm
       ON lm.id = (
         SELECT x.id FROM svh_request_messages x
         WHERE x.request_id = m.request_id
           AND x.svh_manager_id = m.svh_manager_id
           AND x.deleted_at IS NULL
         ORDER BY x.id DESC
         LIMIT 1
       )
     LEFT JOIN (
       SELECT request_id, svh_manager_id, COUNT(*) AS unread_count
       FROM svh_request_messages
       WHERE deleted_at IS NULL
         AND author_type = ${asRole === 'svh' ? "'app_user'" : "'svh_manager'"}
         AND ${asRole === 'svh' ? 'read_by_svh_at' : 'read_by_client_at'} IS NULL
       GROUP BY request_id, svh_manager_id
     ) u ON u.request_id = m.request_id AND u.svh_manager_id = m.svh_manager_id
     WHERE 1=1
       ${filter}
     ORDER BY COALESCE(lm.id, 0) DESC, r.id DESC`,
    args,
  );

  return rows.map((row) => {
    const unreadCount = Number(row.unread_count) || 0;
    const svhName = normalize(row.svh_company_name) || 'СВХ';
    const clientName =
      normalize(row.individual_full_name) ||
      normalize(row.legal_entity_name) ||
      'Клиент';
    // В списке — ФИО собеседника: для СВХ клиент, для клиента — СВХ.
    const counterpartName = asRole === 'svh' ? clientName : svhName;
    return {
      requestId: Number(row.request_id),
      svhManagerId: Number(row.svh_manager_id),
      carMake: row.car_make != null ? String(row.car_make) : '',
      carModel: row.car_model != null ? String(row.car_model) : '',
      vin: row.vin != null ? String(row.vin) : '',
      managerFullName: counterpartName,
      external1cId: null,
      lastText: lastMessagePreviewText(row.last_text, row.last_attachments_json) || null,
      lastAt: toIsoDate(row.last_at),
      unread: unreadCount > 0,
      unreadCount,
      kind: 'svh',
    };
  });
}

module.exports = {
  listSvhMessages,
  createSvhMessage,
  markSvhRead,
  listSvhChats,
  assertRequestExists,
  resolveSvhChatNames,
  messageDto,
};
