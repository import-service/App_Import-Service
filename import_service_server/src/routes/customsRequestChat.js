const { v4: uuidv4 } = require('uuid');
const fs = require('fs');
const { verifyIntegrationBearer, isIntegrationBearerRequest } = require('../util/integrationAuth');
const { sendUserMessageTo1C } = require('../services/oneCChatOut');
const { handleDemoUserChatMessage, isDemoExternal1cId } = require('../services/demoFlow');
const { mpOrganizationId } = require('../util/requestOrganizationAccess');
const {
  createMessageFrom1c,
  listMessagesAsc,
  messageDto,
  findRequestByExternal1cId,
  normalize,
  clipText,
  jsonAttachmentsOrNull,
  parseRowAttachments,
} = require('../services/chatMessageOps');
const {
  ensureChatUploadDir,
  saveChatAttachment,
  chatAttachmentDiskPath,
  requestIdFromChatStoredName,
} = require('../services/chatAttachmentStorage');

async function assertRequestChatAvailable(pool, requestId, orgId = null) {
  const [rows] = await pool.query(
    `SELECT id, external_1c_id, deleted_at, organization_id
     FROM customs_requests
     WHERE id = ?
     LIMIT 1`,
    [requestId],
  );
  if (!rows.length || rows[0].deleted_at) {
    return { ok: false, error: 'NOT_FOUND' };
  }
  if (orgId != null && Number(rows[0].organization_id) !== orgId) {
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

      const orgId = mpOrganizationId(request);
      const ar = await assertRequestChatAvailable(fastify.pool, id, orgId);
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

      const orgId = mpOrganizationId(request);
      const ar = await assertRequestChatAvailable(fastify.pool, id, orgId);
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
      if (!ar.row.external_1c_id) {
        oneC = { status: 0, error: { code: 'MISSING_EXTERNAL_1C_ID' } };
        await fastify.pool.query(
          `UPDATE customs_request_messages
           SET delivery_status='failed', last_1c_error=?
           WHERE id=? AND deleted_at IS NULL`,
          ['MISSING_EXTERNAL_1C_ID', messageId],
        );
        messageRow.delivery_status = 'failed';
        messageRow.last_1c_error = 'MISSING_EXTERNAL_1C_ID';
      } else if (isDemoExternal1cId(ar.row.external_1c_id)) {
        oneC = { status: 200, demo: true };
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
        handleDemoUserChatMessage(fastify, id, text).catch((e) => {
          fastify.log.warn({ requestId: id, err: e.message }, 'demo chat reply failed');
        });
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
            external1cId: ar.row.external_1c_id || null,
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

      const orgId = mpOrganizationId(request);
      const ar = await assertRequestChatAvailable(fastify.pool, id, orgId);
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

  fastify.get(
    '/integration/customs-request-messages',
    {
      preHandler: verifyIntegrationBearer,
      schema: {
        querystring: {
          type: 'object',
          required: ['external1cId'],
          properties: {
            external1cId: { type: 'string', minLength: 1, maxLength: 255 },
          },
        },
      },
    },
    async (request, reply) => {
      const external1cId = normalize(request.query.external1cId);
      const reqRow = await findRequestByExternal1cId(fastify.pool, external1cId);
      if (!reqRow) {
        return reply.code(404).send({ error: 'NOT_FOUND' });
      }
      const requestId = reqRow.id;
      const rows = await listMessagesAsc(fastify.pool, requestId);
      return reply.send({
        items: rows.map((r) => messageDto(r, external1cId)),
        requestId,
        external1cId,
      });
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
      try {
        const result = await createMessageFrom1c(fastify, {
          external1cId: request.body.external1cId,
          message1cId: request.body.message1cId,
          text: request.body.text,
          attachments: request.body.attachments,
          sender1cId: request.body.sender1cId,
          senderName: request.body.senderName,
        });
        if (result.dedup) {
          return reply.send({
            ok: true,
            dedup: true,
            id: result.id,
            requestId: result.requestId,
          });
        }
        return reply.send({
          ok: true,
          id: result.id,
          requestId: result.requestId,
          message: result.message,
        });
      } catch (e) {
        if (e.code === 'NOT_FOUND') {
          return reply.code(404).send({ error: 'NOT_FOUND' });
        }
        if (e.code === 'VALIDATION_ERROR') {
          return reply.code(400).send({
            error: 'VALIDATION_ERROR',
            message: e.messageRu || e.message,
          });
        }
        throw e;
      }
    },
  );

  await ensureChatUploadDir();

  async function handleChatAttachmentUpload(request, reply, requestId) {
    const mp = await request.file();
    if (!mp) {
      return reply.code(400).send({ error: 'VALIDATION_ERROR', message: 'Нужен multipart: file' });
    }
    const chunks = [];
    for await (const chunk of mp.file) {
      chunks.push(chunk);
    }
    const buf = Buffer.concat(chunks);
    try {
      const saved = await saveChatAttachment(fastify, {
        requestId,
        buffer: buf,
        clientFileName: mp.filename,
        mimeType: mp.mimetype,
      });
      return reply.send({
        fileUrl: saved.absoluteFileUrl || saved.fileUrl,
        fileName: saved.fileName,
        mimeType: saved.mimeType,
        fileSizeBytes: saved.fileSizeBytes,
      });
    } catch (e) {
      return reply.code(400).send({
        error: 'VALIDATION_ERROR',
        message: e.message || 'Ошибка загрузки',
      });
    }
  }

  fastify.post(
    '/customs-requests/:id/messages/attachments',
    { onRequest: [fastify.authenticate] },
    async (request, reply) => {
      const id = Number(request.params.id);
      if (!Number.isFinite(id) || id <= 0) {
        return reply.code(400).send({ error: 'VALIDATION_ERROR', message: 'Некорректный id' });
      }
      const orgId = mpOrganizationId(request);
      const ar = await assertRequestChatAvailable(fastify.pool, id, orgId);
      if (!ar.ok) {
        if (ar.error === 'CHAT_NOT_AVAILABLE') {
          return reply.code(409).send({ error: 'CHAT_NOT_AVAILABLE' });
        }
        return reply.code(404).send({ error: 'NOT_FOUND' });
      }
      return handleChatAttachmentUpload(request, reply, id);
    },
  );

  fastify.post(
    '/integration/customs-request-messages/attachments',
    { preHandler: verifyIntegrationBearer },
    async (request, reply) => {
      const external1cId = normalize(
        request.query.external1cId || request.headers['x-external-1c-id'],
      );
      if (!external1cId) {
        return reply.code(400).send({
          error: 'VALIDATION_ERROR',
          message: 'Нужен query external1cId',
        });
      }
      const reqRow = await findRequestByExternal1cId(fastify.pool, external1cId);
      if (!reqRow) {
        return reply.code(404).send({ error: 'NOT_FOUND' });
      }
      return handleChatAttachmentUpload(request, reply, reqRow.id);
    },
  );

  fastify.get(
    '/chat-attachments/:storedName',
    {
      onRequest: [
        async function authChatFile(request, reply) {
          if (isIntegrationBearerRequest(request)) return;
          try {
            await request.jwtVerify();
          } catch {
            return reply.code(401).send({ error: 'UNAUTHORIZED' });
          }
        },
      ],
    },
    async (request, reply) => {
      const storedName = normalize(request.params.storedName);
      const diskPath = chatAttachmentDiskPath(storedName);
      if (!diskPath || !fs.existsSync(diskPath)) {
        return reply.code(404).send({ error: 'NOT_FOUND' });
      }
      const requestId = requestIdFromChatStoredName(storedName);
      if (!isIntegrationBearerRequest(request)) {
        const orgId = mpOrganizationId(request);
        if (requestId > 0 && orgId != null) {
          const ar = await assertRequestChatAvailable(fastify.pool, requestId, orgId);
          if (!ar.ok) {
            return reply.code(404).send({ error: 'NOT_FOUND' });
          }
        }
      }
      const stream = fs.createReadStream(diskPath);
      const ext = storedName.toLowerCase();
      let contentType = 'application/octet-stream';
      if (ext.endsWith('.pdf')) contentType = 'application/pdf';
      else if (ext.endsWith('.png')) contentType = 'image/png';
      else if (ext.endsWith('.jpg') || ext.endsWith('.jpeg')) contentType = 'image/jpeg';
      else if (ext.endsWith('.webp')) contentType = 'image/webp';
      else if (ext.endsWith('.gif')) contentType = 'image/gif';
      return reply.type(contentType).send(stream);
    },
  );
};
