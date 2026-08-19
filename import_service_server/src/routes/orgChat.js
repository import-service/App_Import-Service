const { verifyIntegrationBearer } = require('../util/integrationAuth');
const { mpOrganizationId } = require('../util/requestOrganizationAccess');
const { integrationFileUploadPayload } = require('../util/integrationFileUrl');
const { parseChatAttachmentJsonBody } = require('../util/uploadBase64');
const {
  ensureChatUploadDir,
  saveChatAttachment,
} = require('../services/chatAttachmentStorage');
const {
  findOrganizationById,
  findOrganizationById1c,
  listOrgMessageDtos,
  orgMessageDto,
  createOrgMessageFrom1c,
  createOrgMessageFromUser,
  markOrgReadByUser,
  resolveOrgChatParties,
} = require('../services/orgChatOps');
const { normalize } = require('../services/chatMessageOps');

async function handleOrgAttachmentUpload(fastify, request, reply, organizationId, jsonBody = null) {
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
      organizationId,
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

function readId1c(request, parsed = null) {
  return normalize(
    (parsed && (parsed.id1c || parsed.id_1c || parsed.external1cId))
      || request.query.id1c
      || request.query.id_1c
      || request.headers['x-id-1c']
      || (request.body && (request.body.id1c || request.body.id_1c)),
  );
}

module.exports = async function orgChatRoutes(fastify) {
  await ensureChatUploadDir();

  fastify.get(
    '/org-chat/messages',
    { onRequest: [fastify.authenticate] },
    async (request, reply) => {
      const orgId = mpOrganizationId(request);
      if (!orgId) {
        return reply.code(401).send({ error: 'UNAUTHORIZED' });
      }
      const org = await findOrganizationById(fastify.pool, orgId);
      if (!org) {
        return reply.code(404).send({ error: 'NOT_FOUND' });
      }

      const limit = Math.min(Math.max(Number(request.query.limit) || 50, 1), 200);
      const beforeId = request.query.beforeId ? Number(request.query.beforeId) : 0;
      const args = [orgId];
      let where = 'organization_id = ? AND deleted_at IS NULL';
      if (beforeId > 0) {
        where += ' AND id < ?';
        args.push(beforeId);
      }
      args.push(limit);

      const [rows] = await fastify.pool.query(
        `SELECT id, organization_id, author_type, user_id, direction, client_message_id, message_1c_id,
                text_content, attachments_json, delivery_status, delivered_to_1c_at, last_1c_error,
                read_by_user_at, read_by_1c_at, created_at, updated_at
         FROM organization_messages
         WHERE ${where}
         ORDER BY id DESC
         LIMIT ?`,
        args,
      );
      const parties = await resolveOrgChatParties(fastify.pool, orgId);
      const items = rows.map((r) => orgMessageDto(r, org.id_1c, parties));
      return reply.send({ items, limit, beforeId: beforeId || null, chatKind: 'org' });
    },
  );

  fastify.post(
    '/org-chat/messages',
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
      const orgId = mpOrganizationId(request);
      if (!orgId) {
        return reply.code(401).send({ error: 'UNAUTHORIZED' });
      }
      try {
        const result = await createOrgMessageFromUser(fastify, {
          organizationId: orgId,
          userId: orgId,
          text: request.body?.text,
          attachments: request.body?.attachments,
          clientMessageId: request.body?.clientMessageId,
        });
        return reply.send({
          ...result.message,
          id: result.id,
          oneC: result.oneC,
        });
      } catch (e) {
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
    '/org-chat/messages/read',
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
      const orgId = mpOrganizationId(request);
      if (!orgId) {
        return reply.code(401).send({ error: 'UNAUTHORIZED' });
      }
      try {
        const result = await markOrgReadByUser(fastify, {
          organizationId: orgId,
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

  fastify.post(
    '/org-chat/messages/attachments',
    { onRequest: [fastify.authenticate] },
    async (request, reply) => {
      const orgId = mpOrganizationId(request);
      if (!orgId) {
        return reply.code(401).send({ error: 'UNAUTHORIZED' });
      }
      return handleOrgAttachmentUpload(fastify, request, reply, orgId);
    },
  );

  fastify.get(
    '/integration/organization-messages',
    {
      preHandler: verifyIntegrationBearer,
      schema: {
        querystring: {
          type: 'object',
          properties: {
            id_1c: { type: 'string', minLength: 1, maxLength: 255 },
            id1c: { type: 'string', minLength: 1, maxLength: 255 },
          },
        },
      },
    },
    async (request, reply) => {
      const id1c = normalize(request.query.id_1c || request.query.id1c);
      if (!id1c) {
        return reply.code(400).send({ error: 'VALIDATION_ERROR', message: 'Нужен query id_1c' });
      }
      const org = await findOrganizationById1c(fastify.pool, id1c);
      if (!org) {
        return reply.code(404).send({ error: 'NOT_FOUND' });
      }
      const items = await listOrgMessageDtos(fastify.pool, org.id, org.id_1c);
      return reply.send({
        items,
        organizationId: Number(org.id),
        id_1c: org.id_1c,
        chatKind: 'org',
      });
    },
  );

  fastify.post(
    '/integration/organization-messages',
    {
      preHandler: verifyIntegrationBearer,
      schema: {
        body: {
          type: 'object',
          required: ['message1cId'],
          properties: {
            id_1c: { type: 'string', minLength: 1, maxLength: 255 },
            id1c: { type: 'string', minLength: 1, maxLength: 255 },
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
        const id1c = normalize(request.body.id_1c || request.body.id1c);
        const result = await createOrgMessageFrom1c(fastify, {
          id1c,
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
            organizationId: result.organizationId,
          });
        }
        return reply.send({
          ok: true,
          id: result.id,
          organizationId: result.organizationId,
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

  fastify.post(
    '/integration/organization-messages/attachments',
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
        const id1c = readId1c(request, parsed);
        const org = await findOrganizationById1c(fastify.pool, id1c);
        if (!org) {
          return reply.code(404).send({ error: 'NOT_FOUND' });
        }
        return handleOrgAttachmentUpload(fastify, request, reply, org.id, parsed);
      }

      const id1c = readId1c(request);
      if (!id1c) {
        return reply.code(400).send({
          error: 'VALIDATION_ERROR',
          message: 'Нужен query/body id_1c',
        });
      }
      const org = await findOrganizationById1c(fastify.pool, id1c);
      if (!org) {
        return reply.code(404).send({ error: 'NOT_FOUND' });
      }
      return handleOrgAttachmentUpload(fastify, request, reply, org.id);
    },
  );
};
