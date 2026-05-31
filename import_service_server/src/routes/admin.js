const bcrypt = require('bcrypt');
const { v4: uuidv4 } = require('uuid');
const { expiresInToMs } = require('../util/time');
const { getAppSettings, updateOneCRequestCreateSettings } = require('../services/appSettings');
const { submitCustomsRequestTo1CFromDb } = require('../services/oneCRequestCreate');
const { pushCustomsRequestUpdateTo1C } = require('../services/oneCUpdateSync');
const { CUSTOMS_REQUEST_SELECT, toCustomsRequestDto } = require('../util/customsRequestDto');
const { toOrganizationDto } = require('../util/organizationDto');

const ORGANIZATION_SELECT =
  'id, id_1c, login, role, org_type, company_name, inn, phone, created_at, updated_at, deleted_at';

const detailDtoOptions = { includeFiles: true, mergeVehicleFiles: true };

function maskToken(token) {
  const t = String(token || '').trim();
  if (!t) return null;
  if (t.length <= 4) return '****';
  return `…${t.slice(-4)}`;
}

module.exports = async function adminRoutes(fastify) {
  fastify.post(
    '/admin/auth/login',
    {
      schema: {
        body: {
          type: 'object',
          required: ['login', 'password'],
          properties: {
            login: { type: 'string', minLength: 1 },
            password: { type: 'string' },
          },
        },
      },
    },
    async (request, reply) => {
      const login = String(request.body.login || '').trim();
      const password = request.body.password;

      const [rows] = await fastify.pool.query(
        'SELECT id, password_hash FROM admin_users WHERE login = ? LIMIT 1',
        [login],
      );
      if (!rows.length) {
        return reply.code(401).send({ error: 'INVALID_CREDENTIALS' });
      }

      const user = rows[0];
      const match = await bcrypt.compare(password, user.password_hash);
      if (!match) {
        return reply.code(401).send({ error: 'INVALID_CREDENTIALS' });
      }

      const adminUserId = user.id;
      await fastify.pool.query(
        'UPDATE admin_sessions SET revoked_at = CURRENT_TIMESTAMP(3) WHERE admin_user_id = ? AND revoked_at IS NULL',
        [adminUserId],
      );

      const jti = uuidv4();
      const ms = expiresInToMs(fastify.config.jwtExpiresIn);
      const expiresAt = new Date(Date.now() + ms);

      await fastify.pool.query(
        'INSERT INTO admin_sessions (admin_user_id, jti, expires_at) VALUES (?, ?, ?)',
        [adminUserId, jti, expiresAt],
      );

      const token = fastify.jwt.sign(
        { sub: String(adminUserId), jti, aud: 'admin' },
        { expiresIn: fastify.config.jwtExpiresIn },
      );

      return reply.send({
        accessToken: token,
        tokenType: 'Bearer',
        expiresAt: expiresAt.toISOString(),
        login,
      });
    },
  );

  fastify.post('/admin/auth/logout', { onRequest: [fastify.authenticateAdmin] }, async (request, reply) => {
    const sub = request.user.sub;
    const jti = request.user.jti;
    await fastify.pool.query(
      'UPDATE admin_sessions SET revoked_at = CURRENT_TIMESTAMP(3) WHERE admin_user_id = ? AND jti = ? AND revoked_at IS NULL',
      [Number(sub), jti],
    );
    return reply.send({ ok: true });
  });

  fastify.get('/admin/auth/me', { onRequest: [fastify.authenticateAdmin] }, async (request, reply) => {
    const sub = Number(request.user.sub);
    const [rows] = await fastify.pool.query(
      'SELECT id, login, created_at FROM admin_users WHERE id = ? LIMIT 1',
      [sub],
    );
    if (!rows.length) {
      return reply.code(401).send({ error: 'UNAUTHORIZED' });
    }
    const u = rows[0];
    return reply.send({
      id: u.id,
      login: u.login,
      createdAt: u.created_at,
    });
  });

  fastify.get(
    '/admin/organizations',
    { onRequest: [fastify.authenticateAdmin] },
    async (request, reply) => {
      const limit = Math.min(Math.max(Number(request.query.limit) || 50, 1), 200);
      const offset = Math.max(Number(request.query.offset) || 0, 0);
      const includeDeleted =
        String(request.query.includeDeleted || '')
          .trim()
          .toLowerCase() === 'true' ||
        String(request.query.includeDeleted || '').trim() === '1';
      const q = String(request.query.q || '').trim();

      const where = [];
      const args = [];
      if (!includeDeleted) {
        where.push('deleted_at IS NULL');
      }
      if (q) {
        where.push(
          '(login LIKE ? OR company_name LIKE ? OR inn LIKE ? OR id_1c LIKE ? OR phone LIKE ?)',
        );
        const like = `%${q}%`;
        args.push(like, like, like, like, like);
      }

      const whereSql = where.length ? `WHERE ${where.join(' AND ')}` : '';

      const [countRows] = await fastify.pool.query(
        `SELECT COUNT(*) AS total FROM organizations ${whereSql}`,
        args,
      );
      const total = Number(countRows[0]?.total || 0);

      const [rows] = await fastify.pool.query(
        `SELECT ${ORGANIZATION_SELECT}
         FROM organizations
         ${whereSql}
         ORDER BY id DESC
         LIMIT ? OFFSET ?`,
        [...args, limit, offset],
      );

      return reply.send({
        items: rows.map(toOrganizationDto),
        total,
        limit,
        offset,
      });
    },
  );

  fastify.get(
    '/admin/organizations/:id',
    { onRequest: [fastify.authenticateAdmin] },
    async (request, reply) => {
      const id = Number(request.params.id);
      if (!Number.isFinite(id) || id <= 0) {
        return reply.code(400).send({ error: 'VALIDATION_ERROR', message: 'Некорректный id' });
      }

      const [rows] = await fastify.pool.query(
        `SELECT ${ORGANIZATION_SELECT} FROM organizations WHERE id = ? LIMIT 1`,
        [id],
      );
      if (!rows.length) {
        return reply.code(404).send({ error: 'NOT_FOUND' });
      }

      return reply.send({ item: toOrganizationDto(rows[0]) });
    },
  );

  fastify.get(
    '/admin/settings/one-c-request-create',
    { onRequest: [fastify.authenticateAdmin] },
    async (_request, reply) => {
      const settings = await getAppSettings(fastify.pool);
      return reply.send({
        oneCRequestCreateUrl: settings.oneCRequestCreateUrl || null,
        oneCRequestCreateBearerTokenMasked: maskToken(settings.oneCRequestCreateBearerToken),
        hasBearerToken: Boolean(settings.oneCRequestCreateBearerToken),
        updatedAt: settings.updatedAt,
      });
    },
  );

  fastify.put(
    '/admin/settings/one-c-request-create',
    {
      onRequest: [fastify.authenticateAdmin],
      schema: {
        body: {
          type: 'object',
          required: ['oneCRequestCreateUrl', 'oneCRequestCreateBearerToken'],
          properties: {
            oneCRequestCreateUrl: { type: 'string', minLength: 1, maxLength: 2048 },
            oneCRequestCreateBearerToken: { type: 'string', minLength: 1, maxLength: 512 },
          },
        },
      },
    },
    async (request, reply) => {
      const url = String(request.body.oneCRequestCreateUrl || '').trim();
      const bearerToken = String(request.body.oneCRequestCreateBearerToken || '').trim();
      if (!url || !/^https?:\/\//i.test(url)) {
        return reply.code(400).send({
          error: 'VALIDATION_ERROR',
          message: 'oneCRequestCreateUrl должен быть http(s) URL',
        });
      }
      if (/[^\x00-\x7F]/.test(bearerToken)) {
        return reply.code(400).send({
          error: 'VALIDATION_ERROR',
          message:
            'oneCRequestCreateBearerToken: только латиница, цифры и ASCII-символы (кириллица недопустима)',
        });
      }
      const updated = await updateOneCRequestCreateSettings(fastify.pool, {
        url,
        bearerToken,
      });
      return reply.send({
        ok: true,
        oneCRequestCreateUrl: updated.oneCRequestCreateUrl,
        oneCRequestCreateBearerTokenMasked: maskToken(updated.oneCRequestCreateBearerToken),
        hasBearerToken: Boolean(updated.oneCRequestCreateBearerToken),
        updatedAt: updated.updatedAt,
      });
    },
  );

  const listDtoOptions = { includeFiles: false, mergeVehicleFiles: false };

  fastify.get(
    '/admin/customs-requests',
    { onRequest: [fastify.authenticateAdmin] },
    async (request, reply) => {
      const limit = Math.min(Math.max(Number(request.query.limit) || 50, 1), 200);
      const offset = Math.max(Number(request.query.offset) || 0, 0);
      const status = String(request.query.status || '').trim();
      const isTestQ = String(request.query.isTest || '').trim().toLowerCase();

      const where = ['deleted_at IS NULL'];
      const args = [];
      if (status) {
        where.push('status = ?');
        args.push(status);
      }
      if (isTestQ === 'true' || isTestQ === '1') {
        where.push('is_test = 1');
      } else if (isTestQ === 'false' || isTestQ === '0') {
        where.push('is_test = 0');
      }

      const whereSql = where.join(' AND ');

      const [countRows] = await fastify.pool.query(
        `SELECT COUNT(*) AS total FROM customs_requests WHERE ${whereSql}`,
        args,
      );
      const total = Number(countRows[0]?.total || 0);

      const [rows] = await fastify.pool.query(
        `SELECT ${CUSTOMS_REQUEST_SELECT}
         FROM customs_requests
         WHERE ${whereSql}
         ORDER BY (status = 'new') DESC, one_c_update_pending DESC, id DESC
         LIMIT ? OFFSET ?`,
        [...args, limit, offset],
      );

      const items = rows.map((row) =>
        toCustomsRequestDto(fastify, request, row, [], listDtoOptions),
      );
      return reply.send({ items, total, limit, offset });
    },
  );

  fastify.get(
    '/admin/customs-requests/:id',
    { onRequest: [fastify.authenticateAdmin] },
    async (request, reply) => {
      const id = Number(request.params.id);
      if (!Number.isFinite(id) || id <= 0) {
        return reply.code(400).send({ error: 'VALIDATION_ERROR', message: 'Некорректный id' });
      }

      const [rows] = await fastify.pool.query(
        `SELECT ${CUSTOMS_REQUEST_SELECT} FROM customs_requests WHERE id = ? AND deleted_at IS NULL LIMIT 1`,
        [id],
      );
      if (!rows.length) {
        return reply.code(404).send({ error: 'NOT_FOUND' });
      }

      const [fileRows] = await fastify.pool.query(
        `SELECT id, doc_type, original_name, stored_name, mime_type, file_size_bytes, file_url, created_at, updated_at
         FROM customs_request_files WHERE request_id = ? AND deleted_at IS NULL ORDER BY id ASC`,
        [id],
      );

      return reply.send(
        toCustomsRequestDto(fastify, request, rows[0], fileRows, detailDtoOptions),
      );
    },
  );

  fastify.post(
    '/admin/customs-requests/:id/resend-to-1c',
    { onRequest: [fastify.authenticateAdmin] },
    async (request, reply) => {
      const id = Number(request.params.id);
      if (!Number.isFinite(id) || id <= 0) {
        return reply.code(400).send({ error: 'VALIDATION_ERROR', message: 'Некорректный id' });
      }

      const [rows] = await fastify.pool.query(
        `SELECT id, status, external_1c_id FROM customs_requests WHERE id = ? AND deleted_at IS NULL LIMIT 1`,
        [id],
      );
      if (!rows.length) {
        return reply.code(404).send({ error: 'NOT_FOUND' });
      }
      const row = rows[0];
      if (row.status !== 'new') {
        return reply.code(409).send({
          error: 'CONFLICT',
          message: 'Повторная отправка доступна только для заявок в статусе new',
        });
      }
      if (row.external_1c_id) {
        return reply.code(409).send({
          error: 'CONFLICT',
          message: 'Заявка уже привязана к 1С',
        });
      }

      const result = await submitCustomsRequestTo1CFromDb(fastify, id);
      if (result.skipped) {
        return reply.code(503).send({
          error: 'ONE_C_URL_NOT_CONFIGURED',
          message: 'URL создания заявки в 1С не задан в настройках админки',
        });
      }
      if (!result.ok) {
        if (result.error === 'NOT_FOUND') {
          return reply.code(404).send({ error: 'NOT_FOUND' });
        }
        return reply.code(502).send({
          error: 'ONE_C_CREATE_FAILED',
          message: result.message || result.error || 'Ошибка при отправке в 1С',
          oneC: result.oneC || null,
        });
      }

      const [updatedRows] = await fastify.pool.query(
        `SELECT ${CUSTOMS_REQUEST_SELECT} FROM customs_requests WHERE id = ? LIMIT 1`,
        [id],
      );
      const [fileRows] = await fastify.pool.query(
        `SELECT id, doc_type, original_name, stored_name, mime_type, file_size_bytes, file_url, created_at, updated_at
         FROM customs_request_files WHERE request_id = ? AND deleted_at IS NULL ORDER BY id ASC`,
        [id],
      );

      return reply.send({
        ok: true,
        oneC: {
          updated: Boolean(result.updated),
          link: result.link || null,
          response: result.oneCResponse || null,
        },
        item: toCustomsRequestDto(fastify, request, updatedRows[0], fileRows, detailDtoOptions),
      });
    },
  );

  fastify.post(
    '/admin/customs-requests/:id/resend-update-to-1c',
    { onRequest: [fastify.authenticateAdmin] },
    async (request, reply) => {
      const id = Number(request.params.id);
      if (!Number.isFinite(id) || id <= 0) {
        return reply.code(400).send({ error: 'VALIDATION_ERROR', message: 'Некорректный id' });
      }

      const [rows] = await fastify.pool.query(
        `SELECT id, status, external_1c_id, one_c_update_pending
         FROM customs_requests WHERE id = ? AND deleted_at IS NULL LIMIT 1`,
        [id],
      );
      if (!rows.length) {
        return reply.code(404).send({ error: 'NOT_FOUND' });
      }
      const row = rows[0];
      if (!row.external_1c_id) {
        return reply.code(409).send({
          error: 'CONFLICT',
          message: 'Заявка ещё не привязана к 1С (нет external1cId)',
        });
      }
      if (Number(row.one_c_update_pending) !== 1) {
        return reply.code(409).send({
          error: 'CONFLICT',
          message: 'Нет неотправленных изменений для повторной доставки в 1С',
        });
      }

      const result = await pushCustomsRequestUpdateTo1C(fastify, id, { resendAllClientFiles: true });
      if (result.skipped) {
        return reply.code(503).send({
          error: 'ONE_C_URL_NOT_CONFIGURED',
          message: 'URL исходящих вызовов в 1С не задан в настройках админки',
        });
      }
      if (!result.ok) {
        return reply.code(502).send({
          error: 'ONE_C_UPDATE_FAILED',
          message: result.message || result.error || 'Ошибка при отправке update в 1С',
          oneC: result.oneC || null,
        });
      }

      const [updatedRows] = await fastify.pool.query(
        `SELECT ${CUSTOMS_REQUEST_SELECT} FROM customs_requests WHERE id = ? LIMIT 1`,
        [id],
      );
      const [fileRows] = await fastify.pool.query(
        `SELECT id, doc_type, original_name, stored_name, mime_type, file_size_bytes, file_url, created_at, updated_at
         FROM customs_request_files WHERE request_id = ? AND deleted_at IS NULL ORDER BY id ASC`,
        [id],
      );

      return reply.send({
        ok: true,
        oneC: {
          response: result.oneCResponse || null,
        },
        item: toCustomsRequestDto(fastify, request, updatedRows[0], fileRows, detailDtoOptions),
      });
    },
  );

  // Временный endpoint для быстрого сброса последней demo-заявки из админки.
  fastify.post(
    '/admin/customs-requests/demo-reset-latest',
    {
      // Временный тех-метод для текущего тестового цикла.
      // После завершения тестов удалить endpoint.
      schema: {
        body: {
          type: 'object',
          properties: {
            confirm: { type: 'string', const: 'demo-reset' },
          },
        },
      },
    },
    async (_request, reply) => {
      if (!fastify.config.demoFlow?.enabled) {
        return reply.code(409).send({ error: 'DEMO_FLOW_DISABLED' });
      }
      const [rows] = await fastify.pool.query(
        `SELECT id
         FROM customs_requests
         WHERE is_test = 1
           AND (
             individual_full_name = 'Тестов Тест Тестович'
             OR individual_full_name LIKE 'Тестов Тест Тестович%'
           )
           AND deleted_at IS NULL
         ORDER BY id DESC
         LIMIT 1`,
      );
      if (!rows.length) {
        return reply.send({ ok: true, deleted: false, reason: 'NO_ACTIVE_DEMO_REQUEST' });
      }
      const id = Number(rows[0].id);
      await fastify.pool.query(
        `UPDATE customs_requests
         SET deleted_at = CURRENT_TIMESTAMP(3), updated_at = CURRENT_TIMESTAMP(3)
         WHERE id = ? AND deleted_at IS NULL`,
        [id],
      );
      return reply.send({ ok: true, deleted: true, requestId: id });
    },
  );

};
