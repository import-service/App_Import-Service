const fs = require('fs/promises');
const path = require('path');

const DOCS_HTML_PATH = path.join(__dirname, '..', 'docs', 'api.html');

module.exports = async function docsRoutes(fastify) {
  fastify.get('/docs', async (request, reply) => {
    const proto = request.headers['x-forwarded-proto'] || request.protocol || 'http';
    const host = request.headers.host || 'localhost';
    const baseUrl = `${proto}://${host}/api`;
    const integrationToken = request.server.config.integrationBearerToken || '';
    const htmlTemplate = await fs.readFile(DOCS_HTML_PATH, 'utf8');
    const html = htmlTemplate
      .replaceAll('{{BASE_URL}}', baseUrl)
      .replaceAll('{{INTEGRATION_BEARER_TOKEN}}', integrationToken);
    reply.type('text/html; charset=utf-8').send(html);
  });
};