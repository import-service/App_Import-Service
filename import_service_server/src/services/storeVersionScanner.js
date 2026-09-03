const fs = require('fs');
const path = require('path');
const { fetchProductionVersion, resolveServiceAccountPath } = require('./googlePlayAuth');
const { getRuStorePublicToken } = require('./rustoreAuth');

const STORES = {
  GOOGLE_PLAY: 'google_play',
  RUSTORE: 'rustore',
  APP_STORE: 'app_store',
};

const PLAY_USER_AGENT =
  'Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36';

function normalizeStoreConfig(config) {
  const appStores = config?.appStores || {};
  return {
    androidPackage: String(appStores.androidPackage || 'com.importservice.app').trim(),
    iosAppStoreId: String(appStores.iosAppStoreId || '6785875687').trim(),
    rustorePublicToken: String(appStores.rustorePublicToken || '').trim(),
    rustorePrivateKeyPath: String(appStores.rustorePrivateKeyPath || '').trim(),
    rustoreKeyId: String(appStores.rustoreKeyId || '').trim(),
    googlePlayServiceAccountPath: String(appStores.googlePlayServiceAccountPath || '').trim(),
  };
}

function successResult(store, versionName, versionCode) {
  return {
    store,
    versionName: versionName != null ? String(versionName).trim() : null,
    versionCode: versionCode != null && Number.isFinite(Number(versionCode))
      ? Number(versionCode)
      : null,
    status: 'ok',
    errorMessage: null,
  };
}

function errorResult(store, message) {
  return {
    store,
    versionName: null,
    versionCode: null,
    status: 'error',
    errorMessage: String(message || 'scan failed').slice(0, 512),
  };
}

async function fetchText(url, headers = {}, timeoutMs = 25000) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const res = await fetch(url, {
      headers: {
        Accept: 'application/json, text/html, */*',
        ...headers,
      },
      redirect: 'follow',
      signal: controller.signal,
    });
    if (!res.ok) {
      throw new Error(`HTTP ${res.status} for ${url}`);
    }
    return res.text();
  } finally {
    clearTimeout(timer);
  }
}

async function fetchJson(url, headers = {}) {
  const text = await fetchText(url, headers);
  return JSON.parse(text);
}

async function scanAppStore(appStoreId) {
  const url = `https://itunes.apple.com/lookup?id=${encodeURIComponent(appStoreId)}&country=ru`;
  const data = await fetchJson(url);
  const results = Array.isArray(data?.results) ? data.results : [];
  if (!results.length) {
    throw new Error('App Store lookup: empty results');
  }
  const item = results[0];
  const versionName = item?.version;
  if (!versionName) {
    throw new Error('App Store lookup: version missing');
  }
  return successResult(STORES.APP_STORE, versionName, null);
}

async function scanGooglePlayViaApi(packageName, cfg, serverRoot) {
  const keyFilePath = resolveServiceAccountPath(cfg, serverRoot);
  if (!keyFilePath) {
    throw new Error('Google Play service account path is not configured');
  }
  const version = await fetchProductionVersion(packageName, keyFilePath);
  return successResult(STORES.GOOGLE_PLAY, version.versionName, version.versionCode);
}

async function scanGooglePlayHtml(packageName) {
  const url = `https://play.google.com/store/apps/details?id=${encodeURIComponent(packageName)}&hl=ru`;
  const html = await fetchText(url, { 'User-Agent': PLAY_USER_AGENT });

  let versionName = null;
  let versionCode = null;

  const softwareVersion = html.match(/"softwareVersion"\s*:\s*"([^"]+)"/);
  if (softwareVersion) {
    versionName = softwareVersion[1];
  }
  if (!versionName) {
    const bracketVersion = html.match(/\[\[\["([0-9]+(?:\.[0-9]+)*)"\]\]/);
    if (bracketVersion) {
      versionName = bracketVersion[1];
    }
  }

  const versionCodeMatch = html.match(/"versionCode"\s*:\s*(\d+)/);
  if (versionCodeMatch) {
    versionCode = Number(versionCodeMatch[1]);
  }

  if (!versionName && versionCode == null) {
    throw new Error('Google Play: version not found in page');
  }

  return successResult(STORES.GOOGLE_PLAY, versionName, versionCode);
}

async function scanGooglePlay(packageName, cfg, serverRoot) {
  const keyFilePath = resolveServiceAccountPath(cfg, serverRoot);
  if (keyFilePath && fs.existsSync(keyFilePath)) {
    return scanGooglePlayViaApi(packageName, cfg, serverRoot);
  }
  return scanGooglePlayHtml(packageName);
}

async function scanRuStoreCatalogHtml(packageName) {
  const url = `https://www.rustore.ru/catalog/app/${encodeURIComponent(packageName)}`;
  const html = await fetchText(url, {
    'User-Agent': PLAY_USER_AGENT,
    Accept: 'text/html,application/xhtml+xml',
  });

  let versionName = null;
  const softwareVersion = html.match(/"softwareVersion"\s*:\s*"([^"]+)"/);
  if (softwareVersion) {
    versionName = softwareVersion[1];
  }

  let versionCode = null;
  const versionCodeMatch = html.match(/"versionCode"\s*:\s*(\d+)/);
  if (versionCodeMatch) {
    versionCode = Number(versionCodeMatch[1]);
  } else if (versionName) {
    const parts = versionName.split('.');
    const last = Number(parts[parts.length - 1]);
    if (Number.isFinite(last)) {
      versionCode = last;
    }
  }

  if (!versionName && versionCode == null) {
    throw new Error('RuStore catalog: version not found in page');
  }
  return successResult(STORES.RUSTORE, versionName, versionCode);
}

async function scanRuStoreBackApi(packageName) {
  const url = `https://backapi.rustore.ru/applicationData/overallInfo/${encodeURIComponent(packageName)}`;
  const data = await fetchJson(url, {
    'User-Agent': 'RuStore/com.importservice.app',
    'ruStore-Ver-Code': '200500',
  });

  const code = String(data?.code || '').trim();
  if (code && code !== 'OK') {
    throw new Error(`RuStore backapi: ${code}`);
  }

  const body = data?.body || data;
  const versionName = body?.versionName;
  const versionCode = body?.versionCode;
  if (!versionName && versionCode == null) {
    throw new Error('RuStore backapi: version missing');
  }
  return successResult(STORES.RUSTORE, versionName, versionCode);
}

async function scanRuStorePublicApi(packageName, publicToken) {
  const url = `https://public-api.rustore.ru/public/v1/application/${encodeURIComponent(packageName)}/version?versionStatuses=ACTIVE&page=0&size=1`;
  const data = await fetchJson(url, {
    'Public-Token': publicToken,
    accept: 'application/json',
  });

  const content = data?.body?.content || data?.content || [];
  const first = Array.isArray(content) ? content[0] : null;
  if (!first) {
    throw new Error('RuStore public API: no ACTIVE version');
  }
  return successResult(
    STORES.RUSTORE,
    first.versionName,
    first.versionCode,
  );
}

async function scanRuStore(packageName, cfg, serverRoot) {
  if (cfg.rustoreKeyId && cfg.rustorePrivateKeyPath) {
    try {
      const token = await getRuStorePublicToken(cfg, serverRoot);
      return await scanRuStorePublicApi(packageName, token);
    } catch (e) {
      // fallback to catalog HTML
    }
  } else if (cfg.rustorePublicToken) {
    try {
      return await scanRuStorePublicApi(packageName, cfg.rustorePublicToken);
    } catch (e) {
      // fallback
    }
  }
  try {
    return await scanRuStoreCatalogHtml(packageName);
  } catch (e) {
    return scanRuStoreBackApi(packageName);
  }
}

async function scanAllStores(config, log) {
  const cfg = normalizeStoreConfig(config);
  const serverRoot = config?.SERVER_ROOT || process.cwd();
  const tasks = [
    {
      store: STORES.APP_STORE,
      run: () => scanAppStore(cfg.iosAppStoreId),
    },
    {
      store: STORES.GOOGLE_PLAY,
      run: () => scanGooglePlay(cfg.androidPackage, cfg, serverRoot),
    },
    {
      store: STORES.RUSTORE,
      run: () => scanRuStore(cfg.androidPackage, cfg, serverRoot),
    },
  ];

  const results = [];
  for (const task of tasks) {
    try {
      const result = await task.run();
      results.push(result);
    } catch (e) {
      const err = errorResult(task.store, e.message);
      results.push(err);
      if (log) {
        log.warn({ store: task.store, err: e.message }, 'store version scan failed');
      }
    }
  }
  return results;
}

async function upsertLatest(pool, result) {
  await pool.query(
    `INSERT INTO store_version_latest
       (store, version_name, version_code, status, error_message, scanned_at)
     VALUES (?, ?, ?, ?, ?, CURRENT_TIMESTAMP(3))
     ON DUPLICATE KEY UPDATE
       version_name = VALUES(version_name),
       version_code = VALUES(version_code),
       status = VALUES(status),
       error_message = VALUES(error_message),
       scanned_at = CURRENT_TIMESTAMP(3),
       updated_at = CURRENT_TIMESTAMP(3)`,
    [
      result.store,
      result.versionName,
      result.versionCode,
      result.status,
      result.errorMessage,
    ],
  );
}

async function insertScanLog(pool, result) {
  await pool.query(
    `INSERT INTO store_version_scan_log
       (store, version_name, version_code, status, error_message, scanned_at)
     VALUES (?, ?, ?, ?, ?, CURRENT_TIMESTAMP(3))`,
    [
      result.store,
      result.versionName,
      result.versionCode,
      result.status,
      result.errorMessage,
    ],
  );
}

async function fetchLatestRows(pool) {
  const [rows] = await pool.query(
    `SELECT store, version_name, version_code, status, error_message, scanned_at, updated_at
     FROM store_version_latest
     ORDER BY store ASC`,
  );
  return rows;
}

function rowToDto(row) {
  return {
    store: String(row.store),
    versionName: row.version_name != null ? String(row.version_name) : null,
    versionCode: row.version_code != null ? Number(row.version_code) : null,
    status: String(row.status),
    errorMessage: row.error_message != null ? String(row.error_message) : null,
    scannedAt: row.scanned_at ? new Date(row.scanned_at).toISOString() : null,
    updatedAt: row.updated_at ? new Date(row.updated_at).toISOString() : null,
  };
}

async function getStoreVersionsDto(pool) {
  const rows = await fetchLatestRows(pool);
  return {
    stores: rows.map(rowToDto),
  };
}

async function runStoreVersionScan(fastify) {
  const results = await scanAllStores(fastify.config, fastify.log);
  for (const result of results) {
    try {
      await upsertLatest(fastify.pool, result);
      await insertScanLog(fastify.pool, result);
    } catch (e) {
      if (e.code === 'ER_NO_SUCH_TABLE') {
        return { ok: false, error: 'STORE_VERSION_TABLES_MISSING', results };
      }
      throw e;
    }
  }
  return { ok: true, results };
}

function readRustorePublicTokenFromEnv(config) {
  const direct = String(config?.appStores?.rustorePublicToken || '').trim();
  if (direct) return direct;

  const keyPath = String(config?.appStores?.rustorePrivateKeyPath || '').trim();
  if (!keyPath) return '';

  try {
    const abs = path.isAbsolute(keyPath)
      ? keyPath
      : path.join(config.SERVER_ROOT || process.cwd(), keyPath);
    const raw = fs.readFileSync(abs, 'utf8').trim();
    // rustore.txt may contain PEM-like private key — not a Public-Token; ignore unless short token.
    if (raw.length < 200 && !raw.includes('BEGIN')) {
      return raw;
    }
  } catch {
    // optional
  }
  return '';
}

module.exports = {
  STORES,
  scanAllStores,
  runStoreVersionScan,
  getStoreVersionsDto,
  readRustorePublicTokenFromEnv,
};
