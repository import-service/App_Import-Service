function normalize(v) {
  return String(v ?? '').trim();
}

module.exports = async function pushRoutes(fastify) {
  fastify.post(
    '/push/tokens',
    {
      onRequest: [fastify.authenticate],
      schema: {
        body: {
          type: 'object',
          required: ['token'],
          properties: {
            token: { type: 'string', minLength: 16, maxLength: 768 },
            platform: { type: 'string', enum: ['android', 'ios', 'web'] },
            appVersion: { type: 'string', maxLength: 64 },
          },
        },
      },
    },
    async (request, reply) => {
      const orgId = Number(request.user.sub);
      const token = normalize(request.body.token);
      const platform = normalize(request.body.platform) || null;
      const appVersion = normalize(request.body.appVersion) || null;
      try {
        const [res] = await fastify.pool.query(
          `INSERT INTO user_push_tokens (org_id, token, platform, app_version, deleted_at)
           VALUES (?, ?, ?, ?, NULL)
           ON DUPLICATE KEY UPDATE
             org_id = VALUES(org_id),
             platform = VALUES(platform),
             app_version = VALUES(app_version),
             deleted_at = NULL,
             updated_at = CURRENT_TIMESTAMP(3)`,
          [orgId, token, platform, appVersion],
        );
        return reply.code(201).send({ ok: true, id: res.insertId || null });
      } catch (e) {
        if (e && e.code === 'ER_NO_SUCH_TABLE') {
          return reply.code(503).send({ error: 'PUSH_STORAGE_NOT_READY' });
        }
        throw e;
      }
    },
  );

  fastify.delete(
    '/push/tokens',
    {
      onRequest: [fastify.authenticate],
      schema: {
        body: {
          type: 'object',
          required: ['token'],
          properties: {
            token: { type: 'string', minLength: 16, maxLength: 768 },
          },
        },
      },
    },
    async (request, reply) => {
      const orgId = Number(request.user.sub);
      const token = normalize(request.body.token);
      try {
        const [res] = await fastify.pool.query(
          `UPDATE user_push_tokens
           SET deleted_at = CURRENT_TIMESTAMP(3), updated_at = CURRENT_TIMESTAMP(3)
           WHERE org_id = ? AND token = ? AND deleted_at IS NULL`,
          [orgId, token],
        );
        return reply.send({ ok: true, updated: Number(res.affectedRows || 0) });
      } catch (e) {
        if (e && e.code === 'ER_NO_SUCH_TABLE') {
          return reply.code(503).send({ error: 'PUSH_STORAGE_NOT_READY' });
        }
        throw e;
      }
    },
  );
};
