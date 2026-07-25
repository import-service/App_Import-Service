const http = require('http');
const { URL } = require('url');
const { WebSocketServer } = require('ws');
const { timingSafeEqualString } = require('../util/security');
const {
  findRequestByExternal1cId,
  listMessagesAsc,
  createMessageFrom1c,
  messageDto,
  normalize,
} = require('./chatMessageOps');

/**
 * WSS комнаты чата.
 *
 * МП:  `/ws/{requestId}/?token=<JWT>` или Authorization Bearer JWT
 * 1С:  `/ws/1c/?external1cId=…&token=<INTEGRATION_BEARER>` (полный дуплекс)
 *
 * Локальный `POST /broadcast` на 127.0.0.1 — пуш из API.
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

  function parseToken(req, u) {
    const fromHeader = (() => {
      const m = String(req.headers.authorization || '').match(/^Bearer\s+(.+)$/i);
      return m ? m[1].trim() : '';
    })();
    const fromQuery = String(u.searchParams.get('token') || '').trim();
    return fromHeader || fromQuery;
  }

  async function authUpgrade(token) {
    const expected = String(fastify.config.integrationBearerToken || '').trim();
    if (expected && token && timingSafeEqualString(token, expected)) {
      return { kind: 'integration' };
    }
    try {
      const decoded = await fastify.jwt.verify(token);
      return { kind: 'jwt', decoded };
    } catch {
      return null;
    }
  }

  function sendJson(ws, payload) {
    if (ws.readyState !== 1) return;
    try {
      ws.send(JSON.stringify(payload));
    } catch {
      // ignore
    }
  }

  async function handleClientMessage(ws, raw) {
    let body;
    try {
      body = JSON.parse(String(raw || ''));
    } catch {
      sendJson(ws, { type: 'error', error: 'BAD_JSON' });
      return;
    }
    const type = normalize(body.type);
    if (type === 'ping') {
      sendJson(ws, { type: 'pong', ts: new Date().toISOString() });
      return;
    }

    if (ws.__authKind !== 'integration') {
      sendJson(ws, { type: 'error', error: 'FORBIDDEN', message: 'Только integration-сокет' });
      return;
    }

    const external1cId = ws.__external1cId;
    const requestId = ws.__roomId;

    if (type === 'history') {
      const rows = await listMessagesAsc(fastify.pool, requestId);
      sendJson(ws, {
        type: 'history',
        requestId,
        external1cId,
        items: rows.map((r) => messageDto(r, external1cId)),
      });
      return;
    }

    if (type === 'send') {
      try {
        const result = await createMessageFrom1c(fastify, {
          external1cId,
          message1cId: body.message1cId,
          text: body.text,
          attachments: body.attachments,
          sender1cId: body.sender1cId,
          senderName: body.senderName,
        });
        sendJson(ws, {
          type: 'send_ack',
          ok: true,
          dedup: Boolean(result.dedup),
          id: result.id,
          requestId: result.requestId,
          message: result.message || null,
        });
      } catch (e) {
        sendJson(ws, {
          type: 'send_ack',
          ok: false,
          error: e.code || 'INTERNAL_ERROR',
          message: e.messageRu || e.message || 'error',
        });
      }
      return;
    }

    sendJson(ws, { type: 'error', error: 'UNKNOWN_TYPE' });
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

  server.on('upgrade', (req, socket, head) => {
    const urlRaw = String(req.url || '');
    if (!urlRaw.startsWith('/ws/')) {
      socket.destroy();
      return;
    }

    let u;
    try {
      u = new URL(urlRaw, `http://${req.headers.host || 'localhost'}`);
    } catch {
      socket.destroy();
      return;
    }

    const token = parseToken(req, u);
    (async () => {
      if (!token) {
        socket.destroy();
        return;
      }
      const auth = await authUpgrade(token);
      if (!auth) {
        socket.destroy();
        return;
      }

      let roomId = 0;
      let external1cId = '';
      let authKind = auth.kind;

      const oneCMatch = u.pathname.match(/^\/ws\/1c\/?$/);
      const mpMatch = u.pathname.match(/^\/ws\/([0-9]+)\/?$/);

      if (oneCMatch) {
        if (auth.kind !== 'integration') {
          socket.destroy();
          return;
        }
        external1cId = normalize(u.searchParams.get('external1cId'));
        if (!external1cId) {
          socket.destroy();
          return;
        }
        const row = await findRequestByExternal1cId(fastify.pool, external1cId);
        if (!row) {
          socket.destroy();
          return;
        }
        roomId = Number(row.id);
      } else if (mpMatch) {
        if (auth.kind !== 'jwt') {
          socket.destroy();
          return;
        }
        roomId = Number(mpMatch[1]);
      } else {
        socket.destroy();
        return;
      }

      if (!roomId) {
        socket.destroy();
        return;
      }

      wss.handleUpgrade(req, socket, head, (ws) => {
        ws.__roomId = roomId;
        ws.__authKind = authKind;
        ws.__external1cId = external1cId || null;
        getRoomSet(roomId).add(ws);
        ws.on('close', () => {
          getRoomSet(roomId).delete(ws);
        });
        ws.on('message', (data) => {
          handleClientMessage(ws, data).catch((e) => {
            fastify.log.warn({ err: e.message }, 'chat wss client message failed');
            sendJson(ws, { type: 'error', error: 'INTERNAL_ERROR' });
          });
        });
        sendJson(ws, {
          type: 'ready',
          requestId: roomId,
          external1cId: external1cId || null,
          role: authKind === 'integration' ? '1c' : 'app',
          ts: new Date().toISOString(),
        });
      });
    })().catch(() => {
      try {
        socket.destroy();
      } catch {
        // ignore
      }
    });
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
