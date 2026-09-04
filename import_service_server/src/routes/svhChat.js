const {
  mpOrganizationId,
  isSvhManagerRequest,
  denyUnlessOwnsRequest,
} = require('../util/requestOrganizationAccess');
const { integrationFileUploadPayload } = require('../util/integrationFileUrl');
const {
  ensureChatUploadDir,
  saveChatAttachment,
} = require('../services/chatAttachmentStorage');
const { parseChatAttachmentJsonBody } = require('../util/uploadBase64');
const {
  listSvhMessages,
  createSvhMessage,
  markSvhRead,
  assertRequestExists,
} = require('../services/svhChatOps');

module.exports = async function svhChatRoutes(fastify) {
  await ensureChatUploadDir();

  fastify.get(
    '/customs-requests/:id/svh-messages',
    { onRequest: [fastify.authenticate] },
    async (request, reply) => {
      const id = Number(request.params.id);
      if (!Number.isFinite(id) || id <= 0) {
        return reply.code(400).send({ error: 'VALIDATION_ERROR', message: 'Некорректный id' });
      }
      const reqRow = await assertRequestExists(fastify.pool, id);
      if (!reqRow || !denyUnlessOwnsRequest(request, reply, reqRow)) {
        if (!reqRow) return reply.code(404).send({ error: 'NOT_FOUND' });
        return;
      }

      const svh = isSvhManagerRequest(request);
      let svhManagerId;
      if (svh) {
        svhManagerId = mpOrganizationId(request);
      } else {
        svhManagerId = Number(request.query.svhManagerId);
        if (!Number.isFinite(svhManagerId) || svhManagerId <= 0) {
          return reply.code(400).send({
            error: 'VALIDATION_ERROR',
            message: 'Нужен svhManagerId',
          });
        }
      }

      const limit = Math.min(Math.max(Number(request.query.limit) || 50, 1), 200);
      const beforeId = request.query.beforeId ? Number(request.query.beforeId) : 0;
      const items = await listSvhMessages(fastify.pool, {
        requestId: id,
        svhManagerId,
        limit,
        beforeId,
        viewerIsSvh: svh,
      });
      return reply.send({
        items,
        limit,
        beforeId: beforeId || null,
        svhManagerId,
        kind: 'svh',
      });
    },
  );

  fastify.post(
    '/customs-requests/:id/svh-messages',
    {
      onRequest: [fastify.authenticate],
      schema: {
        body: {
          type: 'object',
          properties: {
            text: { type: 'string', maxLength: 5000 },
            clientMessageId: { type: 'string', minLength: 32, maxLength: 40 },
            svhManagerId: { type: 'integer', minimum: 1 },
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
      const reqRow = await assertRequestExists(fastify.pool, id);
      if (!reqRow || !denyUnlessOwnsRequest(request, reply, reqRow)) {
        if (!reqRow) return reply.code(404).send({ error: 'NOT_FOUND' });
        return;
      }

      const orgId = mpOrganizationId(request);
      const svh = isSvhManagerRequest(request);
      let svhManagerId;
      let authorType;
      if (svh) {
        svhManagerId = orgId;
        authorType = 'svh_manager';
      } else {
        svhManagerId = Number(request.body?.svhManagerId || request.query.svhManagerId);
        if (!Number.isFinite(svhManagerId) || svhManagerId <= 0) {
          return reply.code(400).send({
            error: 'VALIDATION_ERROR',
            message: 'Нужен svhManagerId',
          });
        }
        authorType = 'app_user';
      }

      try {
        const result = await createSvhMessage(fastify, {
          requestId: id,
          svhManagerId,
          authorType,
          authorOrgId: orgId,
          text: request.body?.text,
          attachments: Array.isArray(request.body?.attachments)
            ? request.body.attachments
            : [],
          clientMessageId: request.body?.clientMessageId,
        });
        return reply.send({
          ...(result.message || {}),
          id: result.id,
          dedup: result.dedup || false,
        });
      } catch (e) {
        if (e.code === 'VALIDATION_ERROR') {
          return reply.code(400).send({
            error: 'VALIDATION_ERROR',
            message: e.messageRu || e.message,
          });
        }
        if (e.code === 'NOT_FOUND') {
          return reply.code(404).send({ error: 'NOT_FOUND' });
        }
        throw e;
      }
    },
  );

  fastify.post(
    '/customs-requests/:id/svh-messages/read',
    {
      onRequest: [fastify.authenticate],
      schema: {
        body: {
          type: 'object',
          required: ['upToMessageId'],
          properties: {
            upToMessageId: { type: 'integer', minimum: 1 },
            svhManagerId: { type: 'integer', minimum: 1 },
          },
        },
      },
    },
    async (request, reply) => {
      const id = Number(request.params.id);
      if (!Number.isFinite(id) || id <= 0) {
        return reply.code(400).send({ error: 'VALIDATION_ERROR', message: 'Некорректный id' });
      }
      const reqRow = await assertRequestExists(fastify.pool, id);
      if (!reqRow || !denyUnlessOwnsRequest(request, reply, reqRow)) {
        if (!reqRow) return reply.code(404).send({ error: 'NOT_FOUND' });
        return;
      }

      const svh = isSvhManagerRequest(request);
      let svhManagerId;
      if (svh) {
        svhManagerId = mpOrganizationId(request);
      } else {
        svhManagerId = Number(request.body?.svhManagerId);
        if (!Number.isFinite(svhManagerId) || svhManagerId <= 0) {
          return reply.code(400).send({
            error: 'VALIDATION_ERROR',
            message: 'Нужен svhManagerId',
          });
        }
      }

      try {
        const result = await markSvhRead(fastify.pool, {
          requestId: id,
          svhManagerId,
          upToMessageId: request.body.upToMessageId,
          asRole: svh ? 'svh' : 'client',
        });
        return reply.send(result);
      } catch (e) {
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

  async function handleSvhAttachmentUpload(request, reply, requestId, jsonBody = null) {
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
      return reply.code(201).send(integrationFileUploadPayload(saved));
    } catch (e) {
      return reply.code(400).send({
        error: 'VALIDATION_ERROR',
        message: e.message || 'Ошибка загрузки',
      });
    }
  }

  fastify.post(
    '/customs-requests/:id/svh-messages/attachments',
    { onRequest: [fastify.authenticate] },
    async (request, reply) => {
      const id = Number(request.params.id);
      if (!Number.isFinite(id) || id <= 0) {
        return reply.code(400).send({ error: 'VALIDATION_ERROR', message: 'Некорректный id' });
      }
      const reqRow = await assertRequestExists(fastify.pool, id);
      if (!reqRow || !denyUnlessOwnsRequest(request, reply, reqRow)) {
        if (!reqRow) return reply.code(404).send({ error: 'NOT_FOUND' });
        return;
      }
      const contentType = String(request.headers['content-type'] || '').toLowerCase();
      if (contentType.includes('application/json')) {
        let parsed;
        try {
          parsed = parseChatAttachmentJsonBody(request.body);
        } catch (e) {
          return reply.code(400).send({
            error: 'VALIDATION_ERROR',
            message: e.message || 'Некорректный JSON',
          });
        }
        return handleSvhAttachmentUpload(request, reply, id, parsed);
      }
      return handleSvhAttachmentUpload(request, reply, id);
    },
  );
};
