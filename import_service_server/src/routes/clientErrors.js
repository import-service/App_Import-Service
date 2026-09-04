const crypto = require('crypto');
const { CLIENT_ERRORS_RETENTION_DAYS } = require('../services/clientErrorsRetention');

const MESSAGE_MAX = 1024;
const STACK_MAX = 16_000;
const TAG_MAX = 64;
const DEVICE_MAX = 256;
const LIST_DEFAULT_LIMIT = 50;
const LIST_MAX_LIMIT = 200;
const RETENTION_DAYS = CLIENT_ERRORS_RETENTION_DAYS;

function normalize(value, max) {
  const s = String(value ?? '').trim();
  if (!s) return null;
  return s.length > max ? s.slice(0, max) : s;
}

function fingerprintOf(message, stack, tag) {
  const raw = `${tag || ''}|${message || ''}|${(stack || '').slice(0, 500)}`;
  return crypto.createHash('sha1').update(raw).digest('hex');
}

async function tryResolveOrg(fastify, request) {
  try {
    await request.jwtVerify();
  } catch {
    return null;
  }
  if (request.user?.aud === 'admin') return null;
  const sub = Number(request.user?.sub);
  if (!Number.isFinite(sub) || sub <= 0) return null;

  const [rows] = await fastify.pool.query(
    `SELECT id, login, role FROM organizations
     WHERE id = ? AND deleted_at IS NULL LIMIT 1`,
    [sub],
  );
  return rows[0] || null;
}

function mapRow(row) {
  return {
    id: row.id,
    createdAt: row.created_at,
    organizationId: row.organization_id,
    login: row.login,
    role: row.role,
    platform: row.platform,
    appVersion: row.app_version,
    buildNumber: row.build_number,
    tag: row.tag,
    message: row.message,
    stack: row.stack_text,
    fatal: Boolean(row.fatal),
    deviceInfo: row.device_info,
    fingerprint: row.fingerprint,
  };
}

module.exports = async function clientErrorRoutes(fastify) {
  fastify.post(
    '/client-errors',
    {
      schema: {
        body: {
          type: 'object',
          required: ['message'],
          additionalProperties: false,
          properties: {
            message: { type: 'string', minLength: 1, maxLength: MESSAGE_MAX },
            stack: { type: 'string', maxLength: STACK_MAX },
            tag: { type: 'string', maxLength: TAG_MAX },
            platform: { type: 'string', maxLength: 32 },
            appVersion: { type: 'string', maxLength: 64 },
            buildNumber: { type: 'string', maxLength: 32 },
            fatal: { type: 'boolean' },
            deviceInfo: { type: 'string', maxLength: DEVICE_MAX },
          },
        },
      },
    },
    async (request, reply) => {
      const message = normalize(request.body.message, MESSAGE_MAX);
      if (!message) {
        return reply.code(400).send({ error: 'VALIDATION_ERROR', message: 'message required' });
      }

      const stack = normalize(request.body.stack, STACK_MAX);
      const tag = normalize(request.body.tag, TAG_MAX);
      const platform = normalize(request.body.platform, 32);
      const appVersion = normalize(request.body.appVersion, 64);
      const buildNumber = normalize(request.body.buildNumber, 32);
      const deviceInfo = normalize(request.body.deviceInfo, DEVICE_MAX);
      const fatal = Boolean(request.body.fatal);
      const fp = fingerprintOf(message, stack, tag);

      const org = await tryResolveOrg(fastify, request);

      try {
        const [result] = await fastify.pool.query(
          `INSERT INTO client_errors
            (organization_id, login, role, platform, app_version, build_number,
             tag, message, stack_text, fatal, device_info, fingerprint)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
          [
            org?.id ?? null,
            org?.login ?? null,
            org?.role ?? null,
            platform,
            appVersion,
            buildNumber,
            tag,
            message,
            stack,
            fatal ? 1 : 0,
            deviceInfo,
            fp,
          ],
        );
        return reply.code(201).send({ ok: true, id: result.insertId });
      } catch (e) {
        if (e && e.code === 'ER_NO_SUCH_TABLE') {
          return reply.code(503).send({ error: 'CLIENT_ERRORS_STORAGE_NOT_READY' });
        }
        throw e;
      }
    },
  );

  fastify.get(
    '/admin/client-errors',
    { onRequest: [fastify.authenticateAdmin] },
    async (request, reply) => {
      const limitRaw = Number(request.query?.limit);
      const offsetRaw = Number(request.query?.offset);
      const limit = Number.isFinite(limitRaw)
        ? Math.min(LIST_MAX_LIMIT, Math.max(1, Math.trunc(limitRaw)))
        : LIST_DEFAULT_LIMIT;
      const offset = Number.isFinite(offsetRaw) && offsetRaw > 0
        ? Math.trunc(offsetRaw)
        : 0;

      try {
        const [countRows] = await fastify.pool.query(
          `SELECT COUNT(*) AS total FROM client_errors
           WHERE created_at >= (NOW(3) - INTERVAL ? DAY)`,
          [RETENTION_DAYS],
        );
        const [rows] = await fastify.pool.query(
          `SELECT id, created_at, organization_id, login, role, platform,
                  app_version, build_number, tag, message, stack_text, fatal,
                  device_info, fingerprint
           FROM client_errors
           WHERE created_at >= (NOW(3) - INTERVAL ? DAY)
           ORDER BY id DESC
           LIMIT ? OFFSET ?`,
          [RETENTION_DAYS, limit, offset],
        );
        return reply.send({
          total: Number(countRows[0]?.total || 0),
          limit,
          offset,
          retentionDays: RETENTION_DAYS,
          items: rows.map(mapRow),
        });
      } catch (e) {
        if (e && e.code === 'ER_NO_SUCH_TABLE') {
          return reply.code(503).send({ error: 'CLIENT_ERRORS_STORAGE_NOT_READY' });
        }
        throw e;
      }
    },
  );
};
