const { v4: uuidv4 } = require('uuid');
const { verifyIntegrationBearer } = require('../util/integrationAuth');
const { sendUserMessageTo1C } = require('../services/oneCChatOut');

const MAX_TEXT = 2000;

function normalize(v) {
  return String(v ?? '').trim();
}

function clipText(text) {
  const s = String(text ?? '');
  if (s.length <= MAX_TEXT) {
    return s;
  }
  return s.slice(0, MAX_TEXT);
}

function jsonAttachmentsOrNull(attachments) {
  if (!attachments) {
    return null;
  }
  return JSON.stringify(attachments);
}

function parseRowAttachments(value) {
  if (value == null) {
    return null;
  }
  if (typeof value === 'string') {
    try {
      return JSON.parse(value);
    } catch {
      return { raw: value };
    }
  }
  return value;
}

async function assertRequestChatAvailable(pool, requestId) {
  const [rows] = await pool.query(
    `SELECT id, external_1c_id, deleted_at
     FROM customs_requests
     WHERE id = ?
     LIMIT 1`,
    [requestId],
  );
  if (!rows.length || rows[0].deleted_at) {
    return { ok: false, error: 'NOT_FOUND' };
  }
  if (!rows[0].external_1c_id) {
    return { ok: false, error: 'CHAT_NOT_AVAILABLE' };
  }
  return { ok: true, row: rows[0] };
}

module.exports = async function customsRequestChatRoutes(fastify) {
  fastify.get(
    '/customs-requests/:id/messages',
    { onRequest: [fastify.authenticate] },
    async (request, reply) => {
      const id = Number(request.params.id);
      if (!Number.isFinite(id) || id <= 0) {
        return reply.code(400).send({ error: 'VALIDATION_ERROR', message: 'Некорректный id' });
      }

      const ar = await assertRequestChatAvailable(fastify.pool, id);
      if (!ar.ok) {
        if (ar.error === 'CHAT_NOT_AVAILABLE') {
          return reply.code(409).send({ error: 'CHAT_NOT_AVAILABLE' });
        }
        return reply.code(404).send({ error: 'NOT_FOUND' });
      }

      const limit = Math.min(Math.max(Number(request.query.limit) || 50, 1), 200);
      const beforeId = request.query.beforeId ? Number(request.query.beforeId) : 0;
      const args = [id];
      let where = 'request_id = ? AND deleted_at IS NULL';
      if (beforeId > 0) {
        where += ' AND id < ?';
        args.push(beforeId);
      }
      args.push(limit);

      const [rows] = await fastify.pool.query(
        `SELECT id, request_id, author_type, user_id, direction, client_message_id, message_1c_id,
                text_content, attachments_json, delivery_status, delivered_to_1c_at, last_1c_error,
                read_by_user_at, created_at, updated_at
         FROM customs_request_messages
         WHERE ${where}
         ORDER BY id DESC
         LIMIT ?`,
        args,
      );

      const items = rows.map((r) => {
        const parsed = parseRowAttachments(r.attachments_json);
        return {
          ...r,
          attachments: parsed,
          attachments_json: undefined,
        };
      });

      return reply.send({ items, limit, beforeId: beforeId || null });
    },
  );

  fastify.post(
    '/customs-requests/:id/messages',
    {
      onRequest: [fastify.authenticate],
      schema: {
        body: {
          type: 'object',
          properties: {
            text: { type: 'string', maxLength: 5000 },
            clientMessageId: { type: 'string', minLength: 32, maxLength: 40 },
            attachments: {
              type: 'array',
              maxItems: 10,
              items: {
                type: 'object',
                required: ['fileUrl'],
                properties: {
                  fileUrl: { type: 'string', minLength: 1, maxLength: 1024 },
                  fileName: { type: 'string', maxLength: 255 },
                  mimeType: { type: 'string', maxLength: 128 },
                },
              },
            },
          },
        },
      },
    },
    async (request, reply) => {
      const id = Number(request.params.id);
      if (!Number.isFinite(id) || id <= 0) {
        return reply.code(400).send({ error: 'VALIDATION_ERROR', message: 'Некорректный id' });
      }

      const ar = await assertRequestChatAvailable(fastify.pool, id);
      if (!ar.ok) {
        if (ar.error === 'CHAT_NOT_AVAILABLE') {
          return reply.code(409).send({ error: 'CHAT_NOT_AVAILABLE' });
        }
        return reply.code(404).send({ error: 'NOT_FOUND' });
      }

      const sub = Number(request.user.sub);
      const text = clipText(request.body.text || '');
      const attachments = Array.isArray(request.body.attachments) ? request.body.attachments : [];
      if (!text && !attachments.length) {
        return reply.code(400).send({ error: 'VALIDATION_ERROR', message: 'Пустое сообщение' });
      }
      for (const a of attachments) {
        if (!normalize(a.fileUrl)) {
          return reply.code(400).send({ error: 'VALIDATION_ERROR', message: 'fileUrl обязателен' });
        }
      }

      const clientMessageId = normalize(request.body.clientMessageId) || uuidv4();

      const [existing] = await fastify.pool.query(
        `SELECT id, request_id, author_type, user_id, direction, client_message_id, message_1c_id,
                text_content, attachments_json, delivery_status, delivered_to_1c_at, last_1c_error,
                read_by_user_at, created_at, updated_at
         FROM customs_request_messages
         WHERE client_message_id = ? AND deleted_at IS NULL
         LIMIT 1`,
        [clientMessageId],
      );
      if (existing.length) {
        const r = existing[0];
        return reply.send({
          ...r,
          attachments: parseRowAttachments(r.attachments_json),
        });
      }

      const payloadJson = attachments.length ? { attachments } : null;
      const [ins] = await fastify.pool.query(
        `INSERT INTO customs_request_messages
           (request_id, author_type, user_id, direction, client_message_id, text_content, attachments_json,
            delivery_status)
         VALUES (?, 'app_user', ?, 'to_1c', ?, ?, ?, 'pending')`,
        [id, sub, clientMessageId, text, jsonAttachmentsOrNull(payloadJson)],
      );

      const messageId = ins.insertId;
      const [rowRows] = await fastify.pool.query(
        `SELECT id, request_id, author_type, user_id, direction, client_message_id, message_1c_id,
                text_content, attachments_json, delivery_status, delivered_to_1c_at, last_1c_error,
                read_by_user_at, created_at, updated_at
         FROM customs_request_messages
         WHERE id = ?
         LIMIT 1`,
        [messageId],
      );
      const messageRow = rowRows[0];

      let oneC;
      if (!fastify.config.chat?.oneC?.url) {
        oneC = { status: 0, error: { code: 'ONE_C_CHAT_URL_NOT_SET' } };
        await fastify.pool.query(
          `UPDATE customs_request_messages
           SET delivery_status='failed', last_1c_error=?
           WHERE id=? AND deleted_at IS NULL`,
          ['ONE_C_CHAT_URL_NOT_SET', messageId],
        );
        messageRow.delivery_status = 'failed';
        messageRow.last_1c_error = 'ONE_C_CHAT_URL_NOT_SET';
      } else {
        try {
          const { json } = await sendUserMessageTo1C(fastify, {
            external1cId: ar.row.external_1c_id,
            clientMessageId,
            text,
            attachmentsJson: attachments || [],
          });
          oneC = { status: 200, json };
          const externalMessageId = json && (json.oneCMessageId || json.message1cId || json.id_1c) ? String(json.oneCMessageId || json.message1cId || json.id_1c) : null;
          await fastify.pool.query(
            `UPDATE customs_request_messages
             SET delivery_status='delivered',
                 delivered_to_1c_at=NOW(3),
                 last_1c_error=NULL
             WHERE id=? AND deleted_at IS NULL`,
            [messageId],
          );
          messageRow.delivery_status = 'delivered';
          messageRow.delivered_to_1c_at = new Date();
          if (externalMessageId) {
            // если 1С вдруг вернул id, сохраняем (не обязательно уникально, но удобно)
            await fastify.pool.query(
              `UPDATE customs_request_messages SET message_1c_id=COALESCE(message_1c_id, ?) WHERE id=? AND deleted_at IS NULL`,
              [externalMessageId, messageId],
            );
            messageRow.message_1c_id = messageRow.message_1c_id || externalMessageId;
          }
        } catch (e) {
          oneC = { error: e.message, body: e.body || null };
          await fastify.pool.query(
            `UPDATE customs_request_messages
             SET delivery_status='failed', last_1c_error=?
             WHERE id=? AND deleted_at IS NULL`,
            [String(e.message || 'ONE_C_ERROR').slice(0, 1000), messageId],
          );
          messageRow.delivery_status = 'failed';
          messageRow.last_1c_error = String(e.message || 'ONE_C_ERROR');
        }
      }

      if (request.server.chatWss) {
        try {
          await request.server.chatWss.broadcast(id, {
            type: 'message_created',
            requestId: id,
            message: {
              ...messageRow,
              attachments: parseRowAttachments(messageRow.attachments_json),
            },
            oneC: oneC && oneC.json ? { ok: true, response: oneC.json } : { ok: false, error: oneC?.error },
          });
        } catch (e) {
          fastify.log.error(e, 'chat broadcast failed (outgoing user message)');
        }
      }

      return reply.send({
        ...messageRow,
        attachments: parseRowAttachments(messageRow.attachments_json),
        attachments_json: undefined,
        oneC,
      });
    },
  );

  fastify.post(
    '/customs-requests/:id/messages/read',
    {
      onRequest: [fastify.authenticate],
      schema: {
        body: {
          type: 'object',
          required: ['upToMessageId'],
          properties: {
            upToMessageId: { type: 'integer', minimum: 1 },
          },
        },
      },
    },
    async (request, reply) => {
      const id = Number(request.params.id);
      if (!Number.isFinite(id) || id <= 0) {
        return reply.code(400).send({ error: 'VALIDATION_ERROR', message: 'Некорректный id' });
      }

      const ar = await assertRequestChatAvailable(fastify.pool, id);
      if (!ar.ok) {
        if (ar.error === 'CHAT_NOT_AVAILABLE') {
          return reply.code(409).send({ error: 'CHAT_NOT_AVAILABLE' });
        }
        return reply.code(404).send({ error: 'NOT_FOUND' });
      }

      const upTo = Number(request.body.upToMessageId);
      if (!Number.isFinite(upTo) || upTo <= 0) {
        return reply.code(400).send({ error: 'VALIDATION_ERROR', message: 'Некорректный upToMessageId' });
      }

      const [r] = await fastify.pool.query(
        `UPDATE customs_request_messages
         SET read_by_user_at=NOW(3)
         WHERE request_id=?
           AND id<=?
           AND direction='from_1c'
           AND read_by_user_at IS NULL
           AND deleted_at IS NULL`,
        [id, upTo],
      );

      if (request.server.chatWss) {
        try {
          await request.server.chatWss.broadcast(id, { type: 'read', requestId: id, upToMessageId: upTo, updated: r.affectedRows || 0 });
        } catch (e) {
          fastify.log.error(e, 'chat broadcast failed (read receipt)');
        }
      }

      return reply.send({ ok: true, updated: r.affectedRows || 0, upToMessageId: upTo });
    },
  );

  fastify.post(
    '/integration/customs-request-messages',
    {
      preHandler: verifyIntegrationBearer,
      schema: {
        body: {
          type: 'object',
          required: ['external1cId', 'message1cId'],
          properties: {
            external1cId: { type: 'string', minLength: 1, maxLength: 255 },
            message1cId: { type: 'string', minLength: 1, maxLength: 255 },
            text: { type: 'string', maxLength: 5000 },
            sender1cId: { type: 'string', maxLength: 255 },
            senderName: { type: 'string', maxLength: 255 },
            attachments: {
              type: 'array',
              maxItems: 10,
              items: {
                type: 'object',
                required: ['fileUrl'],
                properties: {
                  fileUrl: { type: 'string', minLength: 1, maxLength: 1024 },
                  fileName: { type: 'string', maxLength: 255 },
                  mimeType: { type: 'string', maxLength: 128 },
                },
              },
            },
          },
        },
      },
    },
    async (request, reply) => {
      const external1cId = normalize(request.body.external1cId);
      const message1cId = normalize(request.body.message1cId);
      const text = clipText(request.body.text || '');
      const attachments = Array.isArray(request.body.attachments) ? request.body.attachments : [];
      if (!text && !attachments.length) {
        return reply.code(400).send({ error: 'VALIDATION_ERROR', message: 'Пустое сообщение' });
      }

      const [reqRows] = await fastify.pool.query(
        `SELECT id, external_1c_id, deleted_at
         FROM customs_requests
         WHERE external_1c_id = ? AND deleted_at IS NULL
         LIMIT 1`,
        [external1cId],
      );
      if (!reqRows.length) {
        return reply.code(404).send({ error: 'NOT_FOUND' });
      }
      const requestId = reqRows[0].id;

      // Дедуп по message_1c_id
      const [ex] = await fastify.pool.query(
        `SELECT id FROM customs_request_messages WHERE message_1c_id=? AND deleted_at IS NULL LIMIT 1`,
        [message1cId],
      );
      if (ex.length) {
        return reply.send({ ok: true, dedup: true, id: ex[0].id, requestId });
      }

      const meta = {
        sender1cId: request.body.sender1cId || null,
        senderName: request.body.senderName || null,
      };

      const [ins] = await fastify.pool.query(
        `INSERT INTO customs_request_messages
          (request_id, author_type, user_id, direction, message_1c_id, text_content, attachments_json, delivery_status)
         VALUES
          (?, 'manager_1c', NULL, 'from_1c', ?, ?, ?, NULL)`,
        [
          requestId,
          message1cId,
          text,
          jsonAttachmentsOrNull(attachments.length ? { attachments, meta } : { attachments: [], meta }),
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

      if (request.server.chatWss) {
        try {
          await request.server.chatWss.broadcast(requestId, {
            type: 'message_incoming',
            requestId,
            message: {
              ...messageRow,
              attachments: parseRowAttachments(messageRow.attachments_json),
            },
          });
        } catch (e) {
          fastify.log.error(e, 'chat broadcast failed (incoming 1C message)');
        }
      }

      return reply.send({
        ok: true,
        id: newId,
        requestId,
        message: {
          ...messageRow,
          attachments: parseRowAttachments(messageRow.attachments_json),
          attachments_json: undefined,
        },
      });
    },
  );
};
