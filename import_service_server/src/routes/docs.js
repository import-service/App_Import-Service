const fs = require('fs/promises');
const path = require('path');
const { URL } = require('url');
const registerAdminWebRoutes = require('./adminWeb');

const DOCS_HTML_PATH = path.join(__dirname, '..', 'docs', 'api.html');
const DOCS_FAVICON_PATH = path.join(__dirname, '..', 'docs', 'favicon.png');

function buildWsBaseUrl(apiBase) {
  try {
    const u = new URL(apiBase);
    const wsProto = u.protocol === 'https:' ? 'wss:' : 'ws:';
    return `${wsProto}//${u.host}`;
  } catch {
    return 'wss://localhost';
  }
}

module.exports = async function docsRoutes(fastify) {
  await registerAdminWebRoutes(fastify);

  fastify.get('/docs/favicon.png', async (_request, reply) => {
    const buf = await fs.readFile(DOCS_FAVICON_PATH);
    reply.header('Cache-Control', 'public, max-age=86400').type('image/png').send(buf);
  });

  async function sendDocsHtml(request, reply) {
    const proto = String(request.headers['x-forwarded-proto'] || '')
      .split(',')[0]
      .trim() || (request.protocol ? String(request.protocol).replace(':', '') : 'https');
    const host = String(request.headers['x-forwarded-host'] || '')
      .split(',')[0]
      .trim() || String(request.headers.host || 'localhost');
    const baseUrl = `${proto}://${host}/api`;
    const wsBaseUrl = buildWsBaseUrl(baseUrl);
    const htmlTemplate = await fs.readFile(DOCS_HTML_PATH, 'utf8');
    const html = htmlTemplate
      .replaceAll('{{BASE_URL}}', baseUrl)
      .replaceAll('{{WS_BASE_URL}}', wsBaseUrl);
    reply.type('text/html; charset=utf-8').send(html);
  }

  /** /docs → редирект на вкладку по умолчанию (можно делиться ссылкой на /docs/app и т.д.) */
  fastify.get('/docs', async (request, reply) => {
    reply.redirect('/docs/app', 302);
  });

  fastify.get('/docs/', async (request, reply) => {
    reply.redirect('/docs/app', 302);
  });

  fastify.get('/docs/:section', async (request, reply) => {
    const section = String(request.params.section || '').toLowerCase();
    const allowed = new Set(['app', 'integration', 'onec', 'catalogs', 'admin', 'tz']);
    if (!allowed.has(section)) {
      reply.redirect('/docs/app', 302);
      return;
    }
    await sendDocsHtml(request, reply);
  });
};
