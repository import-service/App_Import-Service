const http = require('http');
const { URL } = require('url');
const { WebSocketServer } = require('ws');
const { timingSafeEqualString } = require('../util/security');
const {
  findRequestByExternal1cId,
  findRequestById,
  listMessageDtos,
  createMessageFrom1c,
  createMessageFromUser,
  markReadByUser,
  markReadBy1c,
  messageDto,
  normalize,
} = require('./chatMessageOps');

/**
 * WSS комнаты чата — единый дуплекс для МП и 1С.
 *
 * МП:  `/ws/{requestId}/?token=<JWT>` — history / send / read
 * 1С:  `/ws/1c/?external1cId=…&token=<INTEGRATION_BEARER>` — history / send / read
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
      if (decoded?.aud === 'admin') return null;
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

    const requestId = ws.__roomId;
    const external1cId = ws.__external1cId;
    const authKind = ws.__authKind;

    if (type === 'history') {
      const items = await listMessageDtos(
        fastify.pool,
        requestId,
        external1cId || null,
      );
      sendJson(ws, {
        type: 'history',
        requestId,
        external1cId: external1cId || null,
        items,
      });
      return;
    }

    if (type === 'send') {
      try {
        let result;
        if (authKind === 'integration') {
          result = await createMessageFrom1c(fastify, {
            external1cId,
            message1cId: body.message1cId,
            text: body.text,
            attachments: body.attachments,
            sender1cId: body.sender1cId,
            senderName: body.senderName,
          });
        } else {
          result = await createMessageFromUser(fastify, {
            requestId,
            userId: ws.__userId,
            text: body.text,
            attachments: body.attachments,
            clientMessageId: body.clientMessageId,
          });
        }
        sendJson(ws, {
          type: 'send_ack',
          ok: true,
          dedup: Boolean(result.dedup),
          id: result.id,
          requestId: result.requestId,
          message: result.message || null,
          oneC: result.oneC || null,
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

    if (type === 'read') {
      try {
        const result = authKind === 'integration'
          ? await markReadBy1c(fastify, { requestId, upToMessageId: body.upToMessageId })
          : await markReadByUser(fastify, { requestId, upToMessageId: body.upToMessageId });
        sendJson(ws, { type: 'read_ack', ...result });
      } catch (e) {
        sendJson(ws, {
          type: 'read_ack',
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

    if (req.method === 'GET' && String(req.url || '').startsWith('/room-stats')) {
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
      let u;
      try {
        u = new URL(req.url, 'http://localhost');
      } catch {
        res.writeHead(400, { 'content-type': 'application/json; charset=utf-8' });
        res.end(JSON.stringify({ error: 'BAD_URL' }));
        return;
      }
      if (u.pathname !== '/room-stats') {
        res.writeHead(404, { 'content-type': 'application/json; charset=utf-8' });
        res.end(JSON.stringify({ error: 'NOT_FOUND' }));
        return;
      }
      const requestId = Number(u.searchParams.get('requestId'));
      if (!requestId) {
        res.writeHead(400, { 'content-type': 'application/json; charset=utf-8' });
        res.end(JSON.stringify({ error: 'BAD_ROOM' }));
        return;
      }
      const set = getRoomSet(requestId);
      let subscribers = 0;
      let integrationSubscribers = 0;
      let jwtSubscribers = 0;
      for (const client of set) {
        if (client.readyState !== 1) continue;
        subscribers += 1;
        if (client.__authKind === 'integration') integrationSubscribers += 1;
        if (client.__authKind === 'jwt') jwtSubscribers += 1;
      }
      res.writeHead(200, { 'content-type': 'application/json; charset=utf-8' });
      res.end(JSON.stringify({
        ok: true,
        requestId,
        subscribers,
        integrationSubscribers,
        jwtSubscribers,
      }));
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
        let integrationDelivered = 0;
        let jwtDelivered = 0;
        for (const client of set) {
          if (client.readyState === 1) {
            client.send(payload);
            delivered += 1;
            if (client.__authKind === 'integration') integrationDelivered += 1;
            if (client.__authKind === 'jwt') jwtDelivered += 1;
          }
        }
        res.writeHead(200, { 'content-type': 'application/json; charset=utf-8' });
        res.end(JSON.stringify({
          ok: true,
          delivered,
          integrationDelivered,
          jwtDelivered,
          subscribers: set.size,
        }));
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
      let userId = null;

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
        userId = Number(auth.decoded?.sub);
        if (!roomId || !userId) {
          socket.destroy();
          return;
        }
        const row = await findRequestById(fastify.pool, roomId);
        if (!row || Number(row.organization_id) !== userId) {
          socket.destroy();
          return;
        }
        external1cId = row.external_1c_id || '';
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
        ws.__userId = userId;
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
    async roomStats(requestId) {
      const res = await fetch(
        `http://127.0.0.1:${cfg.broadcastPort}/room-stats?requestId=${Number(requestId)}`,
        {
          method: 'GET',
          headers: {
            'X-Broadcast-Secret': String(cfg.broadcastSecret),
          },
        },
      );
      if (!res.ok) {
        const t = await res.text();
        throw new Error(`ROOM_STATS_FAILED: ${res.status} ${t}`);
      }
      return res.json();
    },

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
      return res.json();
    },
  };

  fastify.__chatWssInited = true;
  fastify.__chatWss = api;
  return api;
}

module.exports = { startChatWss };
