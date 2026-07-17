const fs = require('fs');
const fsPromises = require('fs/promises');
const path = require('path');

const MIME = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'application/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.gif': 'image/gif',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
  '.wasm': 'application/wasm',
  '.woff': 'font/woff',
  '.woff2': 'font/woff2',
  '.ttf': 'font/ttf',
};

function safeJoin(root, rel) {
  const normalized = path.normalize(rel).replace(/^(\.\.(\/|\\|$))+/, '');
  const full = path.join(root, normalized);
  if (!full.startsWith(root)) {
    return null;
  }
  return full;
}

module.exports = async function adminWebRoutes(fastify) {
  const root = fastify.config.adminWebRoot;

  if (!fs.existsSync(root)) {
    fs.mkdirSync(root, { recursive: true });
  }

  async function sendAdminFile(rel, reply, fallbackIndex) {
    const filePath = safeJoin(root, rel);
    if (filePath && fs.existsSync(filePath) && fs.statSync(filePath).isFile()) {
      const ext = path.extname(filePath).toLowerCase();
      const body = await fsPromises.readFile(filePath);
      return reply.type(MIME[ext] || 'application/octet-stream').send(body);
    }
    if (fallbackIndex) {
      const indexPath = path.join(root, 'index.html');
      if (fs.existsSync(indexPath)) {
        const html = await fsPromises.readFile(indexPath, 'utf8');
        return reply.type('text/html; charset=utf-8').send(html);
      }
    }
    return reply.code(404).send({ error: 'NOT_FOUND' });
  }

  fastify.get('/admin', async (_request, reply) => reply.redirect('/admin/'));

  fastify.get('/admin/', async (_request, reply) => sendAdminFile('index.html', reply, false));

  fastify.get('/admin/*', async (request, reply) => {
    const rel = request.params['*'] || '';
    return sendAdminFile(rel, reply, true);
  });
};
