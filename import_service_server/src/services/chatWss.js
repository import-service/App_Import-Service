const http = require('http');
const { URL } = require('url');
const { WebSocketServer } = require('ws');
const { timingSafeEqualString } = require('../util/security');

/**
 * WSS: `/ws/{requestId}/?token=<accessToken>` (так удобно в браузере) или
 *      `Authorization: Bearer <accessToken>`.
 * Локальный `POST /broadcast` на 127.0.0.1 c `X-Broadcast-Secret` — для пуша событий из API.
 */
function startChatWss(fastify) {
  if (fastify.__chatWssInited) {
    return fastify.__chatWss;
  }
  const cfg = fastify.config.chat;
  if (!cfg?.broadcastPort) {
    fastify.log.warn('CHAT_BROADCAST_PORT не задан, realtime чат отключен');
    return null;
  }

  const wss = new WebSocketServer({ noServer: true });
  const rooms = new Map();

  function getRoomSet(roomId) {
    if (!rooms.has(roomId)) {
      rooms.set(roomId, new Set());
    }
    return rooms.get(roomId);
  }

  function parseRoomId(req) {
    const u = new URL(req.url, `http://${req.headers.host || 'localhost'}`);
    const m = u.pathname.match(/^\/ws\/([0-9]+)\/?$/);
    return m ? Number(m[1]) : 0;
  }

  function parseToken(req) {
    const u = new URL(req.url, `http://${req.headers.host || 'localhost'}`);
    const fromHeader = (() => {
      const m = String(req.headers.authorization || '').match(/^Bearer\s+(.+)$/i);
      return m ? m[1].trim() : '';
    })();
    const fromQuery = String(u.searchParams.get('token') || '').trim();
    return fromHeader || fromQuery;
  }

  const server = http.createServer((req, res) => {
    if (req.method === 'GET' && req.url === '/healthz') {
      res.writeHead(200, { 'content-type': 'text/plain; charset=utf-8' });
      res.end('ok');
      return;
    }

    if (req.method === 'POST' && req.url === '/broadcast') {
      if (!['127.0.0.1', '::1', '::ffff:127.0.0.1'].includes(String(req.socket.remoteAddress || ''))) {
        res.writeHead(403, { 'content-type': 'application/json; charset=utf-8' });
        res.end(JSON.stringify({ error: 'FORBIDDEN' }));
        return;
      }
      const provided = String(req.headers['x-broadcast-secret'] || '');
      if (!timingSafeEqualString(provided, String(cfg.broadcastSecret || ''))) {
        res.writeHead(401, { 'content-type': 'application/json; charset=utf-8' });
        res.end(JSON.stringify({ error: 'UNAUTHORIZED' }));
        return;
      }
      const chunks = [];
      req.on('data', (c) => chunks.push(c));
      req.on('end', () => {
        const raw = Buffer.concat(chunks).toString('utf8');
        let body;
        try {
          body = raw ? JSON.parse(raw) : {};
        } catch {
          res.writeHead(400, { 'content-type': 'application/json; charset=utf-8' });
          res.end(JSON.stringify({ error: 'BAD_JSON' }));
          return;
        }
        const requestId = Number(body.requestId);
        if (!requestId) {
          res.writeHead(400, { 'content-type': 'application/json; charset=utf-8' });
          res.end(JSON.stringify({ error: 'BAD_ROOM' }));
          return;
        }
        const payload = JSON.stringify(body.event || {});
        const set = getRoomSet(requestId);
        let delivered = 0;
        for (const client of set) {
          if (client.readyState === 1) {
            client.send(payload);
            delivered += 1;
          }
        }
        res.writeHead(200, { 'content-type': 'application/json; charset=utf-8' });
        res.end(JSON.stringify({ ok: true, delivered, subscribers: set.size }));
      });
      return;
    }

    res.writeHead(404, { 'content-type': 'application/json; charset=utf-8' });
    res.end(JSON.stringify({ error: 'NOT_FOUND' }));
  });

  wss.on('connection', (socket) => {
    // room id выставим до emit в upgrade
  });

  server.on('upgrade', (req, socket, head) => {
    if (!String(req.url || '').startsWith('/ws/')) {
      socket.destroy();
      return;
    }
    const roomId = parseRoomId(req);
    if (!roomId) {
      socket.destroy();
      return;
    }
    const token = parseToken(req);
    (async () => {
      if (!token) {
        socket.destroy();
        return;
      }
      try {
        await fastify.jwt.verify(token, { onlyCookie: false });
      } catch {
        socket.destroy();
        return;
      }
      wss.handleUpgrade(req, socket, head, (ws) => {
        ws.__roomId = roomId;
        getRoomSet(roomId).add(ws);
        ws.on('close', () => {
          getRoomSet(roomId).delete(ws);
        });
        wss.emit('connection', ws, req);
        try {
          ws.send(
            JSON.stringify({ type: 'ready', requestId: roomId, ts: new Date().toISOString() }),
          );
        } catch {
          // ignore
        }
      });
    })();
  });

  server.listen(cfg.broadcastPort, '0.0.0.0', () => {
    fastify.log.info({ port: cfg.broadcastPort }, 'Chat WSS (rooms) listening');
  });

  const api = {
    async broadcast(requestId, event) {
      const res = await fetch(`http://127.0.0.1:${cfg.broadcastPort}/broadcast`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'X-Broadcast-Secret': String(cfg.broadcastSecret),
        },
        body: JSON.stringify({ requestId, event }),
      });
      if (!res.ok) {
        const t = await res.text();
        throw new Error(`BROADCAST_FAILED: ${res.status} ${t}`);
      }
    },
  };

  fastify.__chatWssInited = true;
  fastify.__chatWss = api;
  return api;
}

module.exports = { startChatWss };
