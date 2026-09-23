/**
 * Тестовый push на организацию по login (email).
 * На VPS из каталога приложения:
 *   node scripts/send-test-push.js user@example.com
 */
require('dotenv').config();
const mysql = require('mysql2/promise');
const config = require('../src/config');
const { sendPushToOrganization } = require('../src/services/pushNotifications');

async function main() {
  const login = String(process.argv[2] || '').trim().toLowerCase();
  if (!login) {
    process.stderr.write('Usage: node scripts/send-test-push.js <login-email>\n');
    process.exit(1);
  }

  const pool = await mysql.createPool({
    host: process.env.MYSQL_HOST || '127.0.0.1',
    port: Number(process.env.MYSQL_PORT || 3306),
    user: process.env.MYSQL_USER,
    password: process.env.MYSQL_PASSWORD,
    database: process.env.MYSQL_DATABASE,
  });

  const [orgRows] = await pool.query(
    `SELECT id, login, role FROM organizations
     WHERE LOWER(login) = ? AND deleted_at IS NULL LIMIT 1`,
    [login],
  );
  if (!orgRows.length) {
    await pool.end();
    process.stderr.write(`ORG_NOT_FOUND login=${login}\n`);
    process.exit(2);
  }
  const org = orgRows[0];
  const orgId = Number(org.id);

  const [tokRows] = await pool.query(
    `SELECT id, platform, app_version, LEFT(token, 16) AS token_prefix, created_at, updated_at
     FROM user_push_tokens
     WHERE org_id = ? AND deleted_at IS NULL
     ORDER BY updated_at DESC`,
    [orgId],
  );

  process.stdout.write(
    JSON.stringify(
      {
        orgId,
        login: org.login,
        role: org.role,
        tokens: tokRows,
      },
      null,
      2,
    ) + '\n',
  );

  const fastify = {
    pool,
    config,
    log: {
      info: (...a) => console.log('[log]', ...a),
      warn: (...a) => console.warn('[warn]', ...a),
      error: (...a) => console.error('[error]', ...a),
    },
  };

  const result = await sendPushToOrganization(fastify, orgId, {
    title: 'Тест push — Импорт Сервис',
    body: `Проверка уведомлений iOS ${new Date().toISOString()}`,
    data: {
      type: 'test_push',
      requestId: '0',
    },
  });

  process.stdout.write(`PUSH_RESULT ${JSON.stringify(result)}\n`);
  await pool.end();
  if (!result.ok) process.exit(3);
}

main().catch((e) => {
  process.stderr.write(`${e.stack || e}\n`);
  process.exit(1);
});
