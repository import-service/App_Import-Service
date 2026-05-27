const Fastify = require('fastify');
const config = require('./config');
const { pool } = require('./db');
const { startChatWss } = require('./services/chatWss');
const packageJson = require('../package.json');

async function buildApp() {
  const fastify = Fastify({
    logger: {
      level: process.env.LOG_LEVEL || 'info',
    },
  });

  const defaultJsonParser = fastify.getDefaultJsonParser('error', 'error');
  fastify.removeContentTypeParser('application/json');
  fastify.addContentTypeParser(
    'application/json',
    { parseAs: 'string', bodyLimit: fastify.initialConfig.bodyLimit },
    function parseJsonAllowEmpty(req, body, done) {
      if (body === '' || body == null) {
        done(null, {});
        return;
      }
      defaultJsonParser(req, body, done);
    },
  );

  fastify.decorate('config', config);
  fastify.decorate('pool', pool);

  await fastify.register(require('@fastify/cors'), {
    origin: (origin, callback) => {
      if (!origin) {
        callback(null, true);
        return;
      }
      const allowed = config.corsOrigins;
      if (allowed === '*') {
        callback(null, true);
        return;
      }
      if (Array.isArray(allowed) && allowed.includes(origin)) {
        callback(null, true);
        return;
      }
      if (config.isLocalDevOrigin(origin)) {
        callback(null, true);
        return;
      }
      const publicBase = config.publicBaseUrl;
      if (publicBase && origin === publicBase) {
        callback(null, true);
        return;
      }
      callback(null, false);
    },
    methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization', 'Accept'],
  });

  await fastify.register(require('@fastify/jwt'), {
    secret: config.jwtSecret,
  });
  await fastify.register(require('@fastify/multipart'), {
    limits: {
      fileSize: 25 * 1024 * 1024, // 25 MB на файл
      files: 1,
    },
  });

  fastify.decorate('authenticate', async function authenticate(request, reply) {
    try {
      await request.jwtVerify();
    } catch {
      return reply.code(401).send({ error: 'UNAUTHORIZED' });
    }

    const sub = request.user.sub;
    const jti = request.user.jti;
    if (!sub || !jti) {
      return reply.code(401).send({ error: 'INVALID_TOKEN' });
    }

    const [rows] = await fastify.pool.query(
      `SELECT id FROM user_sessions
       WHERE user_id = ? AND jti = ? AND revoked_at IS NULL AND expires_at > NOW(3)`,
      [Number(sub), jti],
    );

    if (!rows.length) {
      return reply.code(401).send({ error: 'SESSION_REVOKED_OR_EXPIRED' });
    }
  });

  fastify.decorate('authenticateAdmin', async function authenticateAdmin(request, reply) {
    try {
      await request.jwtVerify();
    } catch {
      return reply.code(401).send({ error: 'UNAUTHORIZED' });
    }

    if (request.user.aud !== 'admin') {
      return reply.code(401).send({ error: 'INVALID_TOKEN' });
    }

    const sub = request.user.sub;
    const jti = request.user.jti;
    if (!sub || !jti) {
      return reply.code(401).send({ error: 'INVALID_TOKEN' });
    }

    const [rows] = await fastify.pool.query(
      `SELECT id FROM admin_sessions
       WHERE admin_user_id = ? AND jti = ? AND revoked_at IS NULL AND expires_at > NOW(3)`,
      [Number(sub), jti],
    );

    if (!rows.length) {
      return reply.code(401).send({ error: 'SESSION_REVOKED_OR_EXPIRED' });
    }
  });

  await fastify.register(async function apiRoutes(instance) {
    await instance.register(require('./routes/integration'));
    await instance.register(require('./routes/auth'));
    await instance.register(require('./routes/admin'));
    await instance.register(require('./routes/registration'));
    await instance.register(require('./routes/customsRequests'));
    await instance.register(require('./routes/customsRequestChat'));
  }, { prefix: '/api' });
  await fastify.register(require('./routes/docs'));

  fastify.log.info({ adminWebRoot: config.adminWebRoot }, 'Админка: каталог статики');

  fastify.get('/health', async () => ({ ok: true }));
  fastify.get('/api/health', async () => ({ ok: true }));
  fastify.get('/api/version', async () => ({
    name: packageJson.name,
    version: packageJson.version,
    timestamp: new Date().toISOString(),
  }));

  return fastify;
}

async function main() {
  const app = await buildApp();
  const chatWss = startChatWss(app);
  app.decorate('chatWss', chatWss);
  try {
    await app.listen({ port: config.port, host: '0.0.0.0' });
    app.log.info(`Слушаю порт ${config.port}`);
  } catch (err) {
    app.log.error(err);
    process.exit(1);
  }
}

module.exports = { buildApp };

if (require.main === module) {
  main();
}
