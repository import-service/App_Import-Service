const bcrypt = require('bcrypt');
const { v4: uuidv4 } = require('uuid');
const { expiresInToMs } = require('../util/time');

module.exports = async function authRoutes(fastify) {
  fastify.post(
    '/auth/login',
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
      const { login, password } = request.body;

      const [rows] = await fastify.pool.query(
        'SELECT id, role, password_hash FROM organizations WHERE login = ? AND deleted_at IS NULL LIMIT 1',
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

      const userId = user.id;
      const role = user.role || 'user';
      // Не отзываем другие активные сессии: повторный вход (другой телефон /
      // переустановка) не должен ломать ещё живой токен на устройстве.
      // Отзыв — только через POST /auth/logout по текущему jti или по expires_at.

      const jti = uuidv4();
      const ms = expiresInToMs(fastify.config.jwtExpiresIn);
      const expiresAt = new Date(Date.now() + ms);

      await fastify.pool.query(
        'INSERT INTO user_sessions (user_id, jti, expires_at) VALUES (?, ?, ?)',
        [userId, jti, expiresAt],
      );

      const token = fastify.jwt.sign(
        { sub: String(userId), jti, role },
        { expiresIn: fastify.config.jwtExpiresIn },
      );

      return reply.send({
        accessToken: token,
        tokenType: 'Bearer',
        expiresAt: expiresAt.toISOString(),
        role,
      });
    },
  );

  fastify.post('/auth/logout', { onRequest: [fastify.authenticate] }, async (request, reply) => {
    const sub = request.user.sub;
    const jti = request.user.jti;
    await fastify.pool.query(
      'UPDATE user_sessions SET revoked_at = CURRENT_TIMESTAMP(3) WHERE user_id = ? AND jti = ? AND revoked_at IS NULL',
      [Number(sub), jti],
    );
    return reply.send({ ok: true });
  });

  fastify.get('/auth/me', { onRequest: [fastify.authenticate] }, async (request, reply) => {
    const sub = request.user.sub;
    const [rows] = await fastify.pool.query(
      `SELECT id, id_1c, login, role, org_type, company_name, inn, phone, created_at, updated_at, deleted_at
       FROM organizations
       WHERE id = ? AND deleted_at IS NULL
       LIMIT 1`,
      [Number(sub)],
    );
    if (!rows.length) {
      return reply.code(401).send({ error: 'USER_NOT_FOUND' });
    }
    const u = rows[0];
    return reply.send({
      id: u.id,
      id_1c: u.id_1c,
      login: u.login,
      role: u.role,
      orgType: u.org_type,
      companyName: u.company_name,
      inn: u.inn,
      phone: u.phone,
      created_at: u.created_at,
      updated_at: u.updated_at,
      deleted_at: u.deleted_at,
    });
  });
};
