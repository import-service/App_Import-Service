const fs = require('fs');
const { verifyIntegrationBearer, isIntegrationBearerRequest } = require('../util/integrationAuth');
const { mpOrganizationId } = require('../util/requestOrganizationAccess');
const {
  createMessageFrom1c,
  createMessageFromUser,
  markReadByUser,
  listMessageDtos,
  messageDto,
  resolveChatPartyNames,
  findRequestByExternal1cId,
  normalize,
} = require('../services/chatMessageOps');
const {
  ensureChatUploadDir,
  saveChatAttachment,
  chatAttachmentDiskPath,
  requestIdFromChatStoredName,
} = require('../services/chatAttachmentStorage');
const { parseChatAttachmentJsonBody } = require('../util/uploadBase64');

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
                read_by_user_at, read_by_1c_at, created_at, updated_at
         FROM customs_request_messages
         WHERE ${where}
         ORDER BY id DESC
         LIMIT ?`,
        args,
      );

      const parties = await resolveChatPartyNames(fastify.pool, id);
      const items = rows.map((r) => messageDto(r, ar.row.external_1c_id, parties));

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

      try {
        const result = await createMessageFromUser(fastify, {
          requestId: id,
          userId: Number(request.user.sub),
          text: request.body.text,
          attachments: Array.isArray(request.body.attachments) ? request.body.attachments : [],
          clientMessageId: request.body.clientMessageId,
        });
        const msg = result.message || {};
        return reply.send({
          ...msg,
          id: result.id,
          oneC: result.oneC,
        });
      } catch (e) {
        if (e.code === 'CHAT_NOT_AVAILABLE') {
          return reply.code(409).send({ error: 'CHAT_NOT_AVAILABLE' });
        }
        if (e.code === 'VALIDATION_ERROR') {
          return reply.code(400).send({ error: 'VALIDATION_ERROR', message: e.messageRu || e.message });
        }
        if (e.code === 'NOT_FOUND') {
          return reply.code(404).send({ error: 'NOT_FOUND' });
        }
        throw e;
      }
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

      try {
        const result = await markReadByUser(fastify, {
          requestId: id,
          upToMessageId: request.body.upToMessageId,
        });
        return reply.send(result);
      } catch (e) {
        if (e.code === 'VALIDATION_ERROR') {
          return reply.code(400).send({ error: 'VALIDATION_ERROR', message: e.messageRu || e.message });
        }
        throw e;
      }
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
      const items = await listMessageDtos(fastify.pool, requestId, external1cId);
      return reply.send({
        items,
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

  async function handleChatAttachmentUpload(request, reply, requestId, jsonBody = null) {
    let buf;
    let clientFileName;
    let mimeType;

    if (jsonBody) {
      buf = jsonBody.buffer;
      clientFileName = jsonBody.fileName;
      mimeType = jsonBody.mimeType;
    } else {
      const mp = await request.file();
      if (!mp) {
        return reply.code(400).send({
          error: 'VALIDATION_ERROR',
          message: 'Нужен multipart: file или JSON с fileBase64',
        });
      }
      const chunks = [];
      for await (const chunk of mp.file) {
        chunks.push(chunk);
      }
      buf = Buffer.concat(chunks);
      clientFileName = mp.filename;
      mimeType = mp.mimetype;
    }

    try {
      const saved = await saveChatAttachment(fastify, {
        requestId,
        buffer: buf,
        clientFileName,
        mimeType,
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
      const contentType = String(request.headers['content-type'] || '').toLowerCase();

      if (contentType.includes('application/json')) {
        let parsed;
        try {
          parsed = parseChatAttachmentJsonBody(request.body || {});
        } catch (e) {
          return reply.code(400).send({
            error: 'VALIDATION_ERROR',
            message: e.message || 'Некорректное тело JSON',
          });
        }
        const reqRow = await findRequestByExternal1cId(fastify.pool, parsed.external1cId);
        if (!reqRow) {
          return reply.code(404).send({ error: 'NOT_FOUND' });
        }
        return handleChatAttachmentUpload(request, reply, reqRow.id, parsed);
      }

      const external1cId = normalize(
        request.query.external1cId
          || request.headers['x-external-1c-id']
          || (request.body && request.body.external1cId),
      );
      if (!external1cId) {
        return reply.code(400).send({
          error: 'VALIDATION_ERROR',
          message: 'Нужен query/body external1cId',
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
