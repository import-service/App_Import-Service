const crypto = require('crypto');
const fs = require('fs');
const path = require('path');

const AUTH_URL = 'https://public-api.rustore.ru/public/auth/';

/** @type {{ token: string|null, expiresAt: number }} */
let tokenCache = { token: null, expiresAt: 0 };

function formatRuStoreTimestamp(date = new Date()) {
  const pad = (n, w = 2) => String(n).padStart(w, '0');
  const ms = pad(date.getMilliseconds(), 3);
  const offsetMin = -date.getTimezoneOffset();
  const sign = offsetMin >= 0 ? '+' : '-';
  const abs = Math.abs(offsetMin);
  const oh = pad(Math.floor(abs / 60));
  const om = pad(abs % 60);
  return (
    `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}` +
    `T${pad(date.getHours())}:${pad(date.getMinutes())}:${pad(date.getSeconds())}.${ms}` +
    `${sign}${oh}:${om}`
  );
}

function resolvePrivateKeyPath(cfg, serverRoot) {
  const rawPath = String(cfg.rustorePrivateKeyPath || '').trim();
  if (!rawPath) return null;
  if (path.isAbsolute(rawPath)) return rawPath;
  return path.join(serverRoot || process.cwd(), rawPath);
}

function loadPrivateKeyBase64(cfg, serverRoot) {
  const keyPath = resolvePrivateKeyPath(cfg, serverRoot);
  if (!keyPath) {
    throw new Error('RuStore private key path is not configured');
  }
  const raw = fs.readFileSync(keyPath, 'utf8').trim();
  if (!raw) {
    throw new Error('RuStore private key file is empty');
  }
  if (raw.includes('BEGIN PRIVATE KEY')) {
    return crypto.createPrivateKey(raw);
  }
  const der = Buffer.from(raw.replace(/\s+/g, ''), 'base64');
  return crypto.createPrivateKey({ key: der, format: 'der', type: 'pkcs8' });
}

function buildAuthSignature(keyId, timestamp, privateKey) {
  const message = `${keyId}${timestamp}`;
  const signer = crypto.createSign('RSA-SHA512');
  signer.update(message, 'utf8');
  signer.end();
  return signer.sign(privateKey, 'base64');
}

async function fetchRuStorePublicToken(cfg, serverRoot) {
  const keyId = String(cfg.rustoreKeyId || '').trim();
  if (!keyId) {
    throw new Error('RuStore keyId is not configured');
  }

  const privateKey = loadPrivateKeyBase64(cfg, serverRoot);
  const timestamp = formatRuStoreTimestamp();
  const signature = buildAuthSignature(keyId, timestamp, privateKey);

  const res = await fetch(AUTH_URL, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Accept: 'application/json' },
    body: JSON.stringify({ keyId, timestamp, signature }),
  });

  const data = await res.json().catch(() => ({}));
  const code = String(data?.code || '').trim();
  if (!res.ok || (code && code !== 'OK')) {
    const message = data?.message || res.statusText || 'auth failed';
    throw new Error(`RuStore auth: ${message}`);
  }

  const jwe = data?.body?.jwe;
  const ttl = Number(data?.body?.ttl || 900);
  if (!jwe) {
    throw new Error('RuStore auth: jwe missing in response');
  }

  tokenCache = {
    token: jwe,
    expiresAt: Date.now() + Math.max(60, ttl) * 1000,
  };
  return jwe;
}

async function getRuStorePublicToken(cfg, serverRoot) {
  if (tokenCache.token && Date.now() < tokenCache.expiresAt - 30_000) {
    return tokenCache.token;
  }
  return fetchRuStorePublicToken(cfg, serverRoot);
}

function clearRuStoreTokenCache() {
  tokenCache = { token: null, expiresAt: 0 };
}

module.exports = {
  getRuStorePublicToken,
  fetchRuStorePublicToken,
  clearRuStoreTokenCache,
  formatRuStoreTimestamp,
  buildAuthSignature,
};
