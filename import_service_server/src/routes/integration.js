const bcrypt = require('bcrypt');
const { randomUUID } = require('crypto');
const { verifyIntegrationBearer } = require('../util/integrationAuth');

function normalize(v) {
  return String(v ?? '').trim();
}

function parseRole(v) {
  const s = normalize(v).toLowerCase();
  return s === 'admin' ? 'admin' : 'user';
}

function parseOrgType(v) {
  const s = normalize(v);
  if (s !== 'ИП' && s !== 'ООО') {
    throw new Error('VALIDATION_ERROR: orgType должен быть "ИП" или "ООО"');
  }
  return s;
}

function normalizeOrgPayload(raw) {
  const id1c = normalize(raw.id_1c ?? raw.id1c ?? raw['id_1C'] ?? raw.id);
  const login = normalize(raw.login);
  const password = String(raw.password ?? '');
  const role = parseRole(raw.role);
  const orgType = parseOrgType(raw.orgType);
  const companyName = normalize(raw.companyName);
  const inn = normalize(raw.inn);
  const phone = normalize(raw.phone);

  if (!id1c) throw new Error('VALIDATION_ERROR: id_1c обязателен');
  if (!login) throw new Error('VALIDATION_ERROR: login обязателен');
  if (!password) throw new Error('VALIDATION_ERROR: password обязателен');
  if (!companyName) throw new Error('VALIDATION_ERROR: companyName обязателен');
  if (!inn) throw new Error('VALIDATION_ERROR: inn обязателен');
  if (!phone) throw new Error('VALIDATION_ERROR: phone обязателен');

  return { id1c, login, password, role, orgType, companyName, inn, phone };
}

async function writeIntegrationLog(fastify, payload) {
  try {
    await fastify.pool.query(
      `INSERT INTO integration_logs
       (request_id, source, endpoint, status, http_code, rows_received, rows_unique, rows_upserted, rows_soft_deleted, error_message)
       VALUES (?, '1c', '/api/integration/organizations', ?, ?, ?, ?, ?, ?, ?)`,
      [
        payload.requestId,
        payload.status,
        payload.httpCode,
        payload.rowsReceived || 0,
        payload.rowsUnique || 0,
        payload.rowsUpserted || 0,
        payload.rowsSoftDeleted || 0,
        payload.errorMessage || null,
      ],
    );
  } catch (e) {
    fastify.log.error(e, 'Не удалось записать integration_logs');
  }
}

module.exports = async function integrationRoutes(fastify) {
  fastify.post(
    '/integration/organizations',
    {
      preHandler: verifyIntegrationBearer,
      schema: {
        body: {
          type: 'object',
          required: ['id_1c', 'login', 'password', 'role', 'orgType', 'companyName', 'inn', 'phone'],
          properties: {
            id_1c: { type: 'string', minLength: 1, maxLength: 255 },
            login: { type: 'string', minLength: 1, maxLength: 255 },
            password: { type: 'string', minLength: 1 },
            role: { type: 'string', enum: ['admin', 'user', 'ADMIN', 'USER'] },
            orgType: { type: 'string', enum: ['ИП', 'ООО'] },
            companyName: { type: 'string', minLength: 1, maxLength: 255 },
            inn: { type: 'string', minLength: 1, maxLength: 32 },
            phone: { type: 'string', minLength: 1, maxLength: 30 },
          },
        },
      },
    },
    async (request, reply) => {
      const requestId = randomUUID();
      let payload;
      try {
        payload = normalizeOrgPayload(request.body);
      } catch (e) {
        await writeIntegrationLog(fastify, {
          requestId,
          status: 'error',
          httpCode: 400,
          rowsReceived: 1,
          rowsUnique: 0,
          errorMessage: e.message,
        });
        return reply.code(400).send({ error: 'VALIDATION_ERROR', message: e.message });
      }

      try {
        const passwordHash = await bcrypt.hash(payload.password, 10);
        await fastify.pool.query(
          `INSERT INTO organizations
             (id_1c, login, role, password_hash, org_type, company_name, inn, phone, deleted_at)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, NULL)
           ON DUPLICATE KEY UPDATE
             login = VALUES(login),
             role = VALUES(role),
             password_hash = VALUES(password_hash),
             org_type = VALUES(org_type),
             company_name = VALUES(company_name),
             inn = VALUES(inn),
             phone = VALUES(phone),
             deleted_at = NULL`,
          [
            payload.id1c,
            payload.login,
            payload.role,
            passwordHash,
            payload.orgType,
            payload.companyName,
            payload.inn,
            payload.phone,
          ],
        );

        const [rows] = await fastify.pool.query(
          `SELECT id, id_1c, login, role, org_type, company_name, inn, phone, created_at, updated_at, deleted_at
           FROM organizations WHERE id_1c = ? LIMIT 1`,
          [payload.id1c],
        );

        const o = rows[0];
        await writeIntegrationLog(fastify, {
          requestId,
          status: 'success',
          httpCode: 200,
          rowsReceived: 1,
          rowsUnique: 1,
          rowsUpserted: 1,
          rowsSoftDeleted: 0,
        });

        return reply.send({
          ok: true,
          item: {
            id: o.id,
            id_1c: o.id_1c,
            login: o.login,
            role: o.role,
            orgType: o.org_type,
            companyName: o.company_name,
            inn: o.inn,
            phone: o.phone,
            created_at: o.created_at,
            updated_at: o.updated_at,
            deleted_at: o.deleted_at,
          },
        });
      } catch (e) {
        fastify.log.error(e);
        await writeIntegrationLog(fastify, {
          requestId,
          status: 'error',
          httpCode: 500,
          rowsReceived: 1,
          rowsUnique: 1,
          errorMessage: e.message || 'INTERNAL_ERROR',
        });
        return reply.code(500).send({ error: 'INTERNAL_ERROR' });
      }
    },
  );
};
