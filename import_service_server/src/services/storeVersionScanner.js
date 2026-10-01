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
    iosBundleId: String(appStores.iosBundleId || 'com.importservice.app').trim(),
    rustorePublicToken: String(appStores.rustorePublicToken || '').trim(),
    rustorePrivateKeyPath: String(appStores.rustorePrivateKeyPath || '').trim(),
    rustoreKeyId: String(appStores.rustoreKeyId || '').trim(),
    googlePlayServiceAccountPath: String(appStores.googlePlayServiceAccountPath || '').trim(),
  };
}

function successResult(store, versionName, versionCode, source) {
  return {
    store,
    versionName: versionName != null ? String(versionName).trim() : null,
    versionCode: versionCode != null && Number.isFinite(Number(versionCode))
      ? Number(versionCode)
      : null,
    status: 'ok',
    errorMessage: null,
    scanSource: source || null,
  };
}

function errorResult(store, message, source = null) {
  return {
    store,
    versionName: null,
    versionCode: null,
    status: 'error',
    errorMessage: String(message || 'scan failed').slice(0, 512),
    scanSource: source || null,
  };
}

/** Semver-ish compare: a>b → >0 */
function compareVersionNames(a, b) {
  const pa = String(a || '')
    .split(/[^\d]+/)
    .filter(Boolean)
    .map((n) => Number(n) || 0);
  const pb = String(b || '')
    .split(/[^\d]+/)
    .filter(Boolean)
    .map((n) => Number(n) || 0);
  const len = Math.max(pa.length, pb.length);
  for (let i = 0; i < len; i += 1) {
    const d = (pa[i] || 0) - (pb[i] || 0);
    if (d !== 0) return d;
  }
  return 0;
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

/**
 * Публичная витрина Apple (itunes lookup).
 * Connect «Ready» может опережать lookup до ~24ч — берём max по странам + cache-bust.
 */
async function scanAppStore(appStoreId, bundleId) {
  const id = String(appStoreId || '').trim();
  const bundle = String(bundleId || '').trim();
  const countries = ['ru', 'us'];
  const bust = Date.now();
  const candidates = [];
  const errors = [];

  for (const country of countries) {
    const urls = [];
    if (id) {
      urls.push(
        `https://itunes.apple.com/lookup?id=${encodeURIComponent(id)}&country=${country}&t=${bust}`,
      );
    }
    if (bundle) {
      urls.push(
        `https://itunes.apple.com/lookup?bundleId=${encodeURIComponent(bundle)}&country=${country}&t=${bust}`,
      );
    }
    for (const url of urls) {
      try {
        const data = await fetchJson(url);
        const results = Array.isArray(data?.results) ? data.results : [];
        const item = results[0];
        const versionName = item?.version != null ? String(item.version).trim() : '';
        if (versionName) {
          candidates.push({ versionName, country, url });
        }
      } catch (e) {
        errors.push(`${country}: ${e.message || e}`);
      }
    }
  }

  if (!candidates.length) {
    throw new Error(
      `App Store lookup empty (${errors.slice(0, 3).join('; ') || 'no results'})`,
    );
  }

  candidates.sort((a, b) => compareVersionNames(b.versionName, a.versionName));
  const best = candidates[0];
  return successResult(
    STORES.APP_STORE,
    best.versionName,
    null,
    `itunes_lookup:${best.country}`,
  );
}

async function scanGooglePlayViaApi(packageName, cfg, serverRoot) {
  const keyFilePath = resolveServiceAccountPath(cfg, serverRoot);
  if (!keyFilePath) {
    throw new Error('Google Play service account path is not configured');
  }
  const version = await fetchProductionVersion(packageName, keyFilePath);
  return successResult(
    STORES.GOOGLE_PLAY,
    version.versionName,
    version.versionCode,
    'google_play_api',
  );
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
    throw new Error('Google Play HTML: version not found');
  }

  return successResult(
    STORES.GOOGLE_PLAY,
    versionName,
    versionCode,
    'google_play_html',
  );
}

async function scanGooglePlay(packageName, cfg, serverRoot, log) {
  const keyFilePath = resolveServiceAccountPath(cfg, serverRoot);
  if (keyFilePath && fs.existsSync(keyFilePath)) {
    try {
      return await scanGooglePlayViaApi(packageName, cfg, serverRoot);
    } catch (e) {
      if (log) {
        log.warn(
          { err: e.message },
          'Google Play API scan failed, trying HTML fallback',
        );
      }
    }
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
  }

  if (!versionName && versionCode == null) {
    throw new Error('RuStore catalog HTML: version not found');
  }
  return successResult(STORES.RUSTORE, versionName, versionCode, 'rustore_html');
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
  return successResult(STORES.RUSTORE, versionName, versionCode, 'rustore_backapi');
}

async function scanRuStorePublicApi(packageName, publicToken) {
  const url = `https://public-api.rustore.ru/public/v1/application/${encodeURIComponent(packageName)}/version?versionStatuses=ACTIVE&page=0&size=5`;
  const data = await fetchJson(url, {
    'Public-Token': publicToken,
    accept: 'application/json',
  });

  const content = data?.body?.content || data?.content || [];
  if (!Array.isArray(content) || !content.length) {
    throw new Error('RuStore public API: no ACTIVE versions');
  }

  let best = content[0];
  for (const item of content) {
    const code = Number(item?.versionCode);
    const bestCode = Number(best?.versionCode);
    if (Number.isFinite(code) && (!Number.isFinite(bestCode) || code > bestCode)) {
      best = item;
    } else if (
      !Number.isFinite(code) &&
      compareVersionNames(item?.versionName, best?.versionName) > 0
    ) {
      best = item;
    }
  }

  return successResult(
    STORES.RUSTORE,
    best.versionName,
    best.versionCode,
    'rustore_public_api',
  );
}

async function scanRuStore(packageName, cfg, serverRoot, log) {
  const attempts = [];

  if (cfg.rustoreKeyId && cfg.rustorePrivateKeyPath) {
    try {
      const token = await getRuStorePublicToken(cfg, serverRoot);
      return await scanRuStorePublicApi(packageName, token);
    } catch (e) {
      attempts.push(`public_api(jwt): ${e.message || e}`);
      if (log) log.warn({ err: e.message }, 'RuStore public API (JWT) failed');
    }
  } else if (cfg.rustorePublicToken) {
    try {
      return await scanRuStorePublicApi(packageName, cfg.rustorePublicToken);
    } catch (e) {
      attempts.push(`public_api(token): ${e.message || e}`);
      if (log) log.warn({ err: e.message }, 'RuStore public API (token) failed');
    }
  } else {
    attempts.push('public_api: not configured');
  }

  try {
    return await scanRuStoreBackApi(packageName);
  } catch (e) {
    attempts.push(`backapi: ${e.message || e}`);
    if (log) log.warn({ err: e.message }, 'RuStore backapi failed');
  }

  try {
    return await scanRuStoreCatalogHtml(packageName);
  } catch (e) {
    attempts.push(`html: ${e.message || e}`);
    throw new Error(`RuStore all sources failed: ${attempts.join(' | ')}`);
  }
}

async function scanAllStores(config, log) {
  const cfg = normalizeStoreConfig(config);
  const serverRoot = config?.SERVER_ROOT || process.cwd();
  const tasks = [
    {
      store: STORES.APP_STORE,
      run: () => scanAppStore(cfg.iosAppStoreId, cfg.iosBundleId),
    },
    {
      store: STORES.GOOGLE_PLAY,
      run: () => scanGooglePlay(cfg.androidPackage, cfg, serverRoot, log),
    },
    {
      store: STORES.RUSTORE,
      run: () => scanRuStore(cfg.androidPackage, cfg, serverRoot, log),
    },
  ];

  const results = [];
  for (const task of tasks) {
    try {
      const result = await task.run();
      results.push(result);
      if (log) {
        log.info(
          {
            store: result.store,
            versionName: result.versionName,
            versionCode: result.versionCode,
            source: result.scanSource,
          },
          'store version scan ok',
        );
      }
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
       (store, version_name, version_code, status, error_message, scan_source, scanned_at)
     VALUES (?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP(3))
     ON DUPLICATE KEY UPDATE
       version_name = VALUES(version_name),
       version_code = VALUES(version_code),
       status = VALUES(status),
       error_message = VALUES(error_message),
       scan_source = VALUES(scan_source),
       scanned_at = CURRENT_TIMESTAMP(3),
       updated_at = CURRENT_TIMESTAMP(3)`,
    [
      result.store,
      result.versionName,
      result.versionCode,
      result.status,
      result.errorMessage,
      result.scanSource || null,
    ],
  );
}

async function insertScanLog(pool, result) {
  await pool.query(
    `INSERT INTO store_version_scan_log
       (store, version_name, version_code, status, error_message, scan_source, scanned_at)
     VALUES (?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP(3))`,
    [
      result.store,
      result.versionName,
      result.versionCode,
      result.status,
      result.errorMessage,
      result.scanSource || null,
    ],
  );
}

async function fetchLatestRows(pool) {
  const [rows] = await pool.query(
    `SELECT store, version_name, version_code, status, error_message, scan_source, scanned_at, updated_at
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
    scanSource: row.scan_source != null ? String(row.scan_source) : null,
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
      // Older schema without scan_source — retry without the column once.
      if (e.code === 'ER_BAD_FIELD_ERROR' && String(e.message || '').includes('scan_source')) {
        await fastify.pool.query(
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
        await fastify.pool.query(
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
        continue;
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
  compareVersionNames,
};
