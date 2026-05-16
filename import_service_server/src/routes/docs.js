const fs = require('fs/promises');
const path = require('path');
const { URL } = require('url');
const registerAdminWebRoutes = require('./adminWeb');

const DOCS_HTML_PATH = path.join(__dirname, '..', 'docs', 'api.html');

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

  fastify.get('/docs', async (request, reply) => {
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
  });
};
