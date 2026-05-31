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
      if (rel === 'index.html') {
        const html = body.toString('utf8');
        const injection = `
<script>
(function () {
  if (window.__demoResetBtnMounted) return;
  window.__demoResetBtnMounted = true;
  function ensureBtn() {
    if (document.getElementById('demo-reset-latest-btn')) return;
    const btn = document.createElement('button');
    btn.id = 'demo-reset-latest-btn';
    btn.textContent = 'TEMP: Сброс demo заявки';
    btn.style.position = 'fixed';
    btn.style.right = '16px';
    btn.style.bottom = '16px';
    btn.style.zIndex = '2147483647';
    btn.style.padding = '10px 12px';
    btn.style.borderRadius = '10px';
    btn.style.border = '1px solid #ef4444';
    btn.style.background = '#b91c1c';
    btn.style.color = '#fff';
    btn.style.fontWeight = '700';
    btn.style.cursor = 'pointer';
    btn.style.boxShadow = '0 4px 14px rgba(0,0,0,.25)';
    btn.onclick = async function () {
      if (!confirm('Удалить последнюю demo-заявку (Тестов Тест Тестович)?')) return;
      btn.disabled = true;
      const prev = btn.textContent;
      btn.textContent = 'Сброс...';
      try {
        const res = await fetch('/api/admin/customs-requests/demo-reset-latest', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ confirm: 'demo-reset' }),
        });
        const json = await res.json().catch(function () { return null; });
        if (!res.ok) {
          alert('Ошибка: ' + res.status + '\\n' + JSON.stringify(json || {}));
        } else if (json && json.deleted) {
          alert('Удалено. requestId=' + json.requestId);
          try { location.reload(); } catch (_) {}
        } else {
          alert('Активной demo-заявки нет.');
        }
      } catch (e) {
        alert('Сеть/сервер: ' + (e && e.message ? e.message : e));
      } finally {
        btn.disabled = false;
        btn.textContent = prev;
      }
    };
    document.body.appendChild(btn);
  }
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', ensureBtn);
  } else {
    ensureBtn();
  }
})();
</script>`;
        const patched = html.includes('</body>')
          ? html.replace('</body>', `${injection}\n</body>`)
          : `${html}\n${injection}`;
        return reply.type('text/html; charset=utf-8').send(patched);
      }
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
