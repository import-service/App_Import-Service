const fs = require('fs/promises');
const { statfs } = require('fs/promises');
const path = require('path');
const { getAppSettings } = require('./appSettings');
const { pushCustomsRequestCreateTo1C } = require('./oneCCreateSync');
const { pushCustomsRequestUpdateTo1C } = require('./oneCUpdateSync');
const { purgeExpiredClosedRequests, DEFAULT_UPLOAD_ROOT } = require('./requestDeletion');

const HOUR_MS = 60 * 60 * 1000;
const DAY_MS = 24 * HOUR_MS;
const { hoursSince } = require('../util/time');

async function fetchRetryableCreateRows(pool) {
  const [rows] = await pool.query(
    `SELECT id, one_c_create_last_attempt_at
     FROM customs_requests
     WHERE deleted_at IS NULL
       AND one_c_create_pending = 1
       AND status = 'new'
       AND (external_1c_id IS NULL OR external_1c_id = '')
       AND (
         one_c_create_last_attempt_at IS NULL
         OR one_c_create_last_attempt_at < DATE_SUB(NOW(3), INTERVAL 1 HOUR)
       )
     ORDER BY one_c_create_first_failed_at ASC
     LIMIT 20`,
  );
  return rows;
}

async function fetchRetryableUpdateRows(pool) {
  const [rows] = await pool.query(
    `SELECT id, one_c_update_last_attempt_at
     FROM customs_requests
     WHERE deleted_at IS NULL
       AND one_c_update_pending = 1
       AND external_1c_id IS NOT NULL
       AND external_1c_id != ''
       AND (
         one_c_update_last_attempt_at IS NULL
         OR one_c_update_last_attempt_at < DATE_SUB(NOW(3), INTERVAL 1 HOUR)
       )
     ORDER BY COALESCE(one_c_update_first_failed_at, one_c_update_last_attempt_at) ASC
     LIMIT 20`,
  );
  return rows;
}

async function runHourlyOneCRetry(fastify) {
  const createRows = await fetchRetryableCreateRows(fastify.pool);
  for (const row of createRows) {
    try {
      await pushCustomsRequestCreateTo1C(fastify, row.id);
    } catch (e) {
      fastify.log.error({ requestId: row.id, err: e.message }, 'hourly create retry failed');
    }
  }

  const updateRows = await fetchRetryableUpdateRows(fastify.pool);
  for (const row of updateRows) {
    try {
      await pushCustomsRequestUpdateTo1C(fastify, row.id, { resendAllClientFiles: true });
    } catch (e) {
      fastify.log.error({ requestId: row.id, err: e.message }, 'hourly update retry failed');
    }
  }

  return { createRetries: createRows.length, updateRetries: updateRows.length };
}

async function fetchStaleOutbound(pool) {
  const [rows] = await pool.query(
    `SELECT id, status, external_1c_id,
            one_c_create_pending, one_c_create_first_failed_at,
            one_c_update_pending, one_c_update_first_failed_at, one_c_update_last_attempt_at
     FROM customs_requests
     WHERE deleted_at IS NULL
       AND (
         (one_c_create_pending = 1 AND one_c_create_first_failed_at < DATE_SUB(NOW(3), INTERVAL 24 HOUR))
         OR (one_c_update_pending = 1 AND COALESCE(one_c_update_first_failed_at, one_c_update_last_attempt_at)
             < DATE_SUB(NOW(3), INTERVAL 24 HOUR))
       )
     ORDER BY id ASC
     LIMIT 100`,
  );
  return rows.map((r) => ({
    requestId: r.id,
    status: r.status,
    external1cId: r.external_1c_id,
    createPending: Number(r.one_c_create_pending) === 1,
    updatePending: Number(r.one_c_update_pending) === 1,
    createHours: hoursSince(r.one_c_create_first_failed_at),
    updateHours: hoursSince(r.one_c_update_first_failed_at || r.one_c_update_last_attempt_at),
  }));
}

async function runDailyOutboundAlert(fastify) {
  const stale = await fetchStaleOutbound(fastify.pool);
  if (!stale.length) {
    return { alerted: false, count: 0 };
  }

  const today = new Date().toISOString().slice(0, 10);
  const payload = { date: today, stale };

  try {
    await fastify.pool.query(
      `INSERT INTO one_c_outbound_daily_alerts (alert_date, payload_json)
       VALUES (?, ?)
       ON DUPLICATE KEY UPDATE payload_json = VALUES(payload_json)`,
      [today, JSON.stringify(payload)],
    );
  } catch (e) {
    if (e.code !== 'ER_NO_SUCH_TABLE') throw e;
  }

  await fastify.pool.query(
    `UPDATE app_settings SET one_c_outbound_alert_last_at = CURRENT_TIMESTAMP(3) WHERE id = 1`,
  );

  fastify.log.warn({ count: stale.length, stale }, 'ONE_C_OUTBOUND_STALE_24H');
  return { alerted: true, count: stale.length, stale };
}

async function runDailyRetentionPurge(fastify) {
  const settings = await getAppSettings(fastify.pool);
  return purgeExpiredClosedRequests(
    fastify.pool,
    settings.retentionMonths,
    DEFAULT_UPLOAD_ROOT,
  );
}

async function dirSizeBytes(dirPath) {
  let total = 0;
  let entries;
  try {
    entries = await fs.readdir(dirPath, { withFileTypes: true });
  } catch (e) {
    if (e.code === 'ENOENT') return 0;
    throw e;
  }
  for (const ent of entries) {
    const full = path.join(dirPath, ent.name);
    if (ent.isDirectory()) {
      total += await dirSizeBytes(full);
    } else if (ent.isFile()) {
      const st = await fs.stat(full);
      total += st.size;
    }
  }
  return total;
}

async function getStorageStats(uploadRoot = DEFAULT_UPLOAD_ROOT) {
  const uploadsBytes = await dirSizeBytes(uploadRoot);

  let diskTotal = null;
  let diskFree = null;
  try {
    const st = await statfs(path.dirname(uploadRoot));
    diskTotal = Number(st.bsize) * Number(st.blocks);
    diskFree = Number(st.bsize) * Number(st.bavail);
  } catch {
    // statfs недоступен — только uploads
  }

  return {
    uploadsBytes,
    uploadsPath: uploadRoot,
    diskTotalBytes: diskTotal,
    diskFreeBytes: diskFree,
    diskUsedBytes: diskTotal != null && diskFree != null ? diskTotal - diskFree : null,
  };
}

function startBackgroundJobs(fastify) {
  const runHourly = async () => {
    try {
      const r = await runHourlyOneCRetry(fastify);
      if (r.createRetries || r.updateRetries) {
        fastify.log.info(r, 'hourly 1C retry tick');
      }
    } catch (e) {
      fastify.log.error({ err: e.message }, 'hourly 1C retry job failed');
    }
  };

  const runDaily = async () => {
    try {
      await runDailyOutboundAlert(fastify);
      const purge = await runDailyRetentionPurge(fastify);
      if (purge.deleted) {
        fastify.log.info(purge, 'retention purge');
      }
    } catch (e) {
      fastify.log.error({ err: e.message }, 'daily background job failed');
    }
  };

  setTimeout(runHourly, 30_000);
  setInterval(runHourly, HOUR_MS);

  const msUntilMidnight = () => {
    const now = new Date();
    const next = new Date(now);
    next.setHours(24, 5, 0, 0);
    return next.getTime() - now.getTime();
  };
  setTimeout(() => {
    runDaily();
    setInterval(runDaily, DAY_MS);
  }, msUntilMidnight());

  fastify.log.info('background jobs: hourly 1C retry, daily retention + outbound alert');
}

module.exports = {
  startBackgroundJobs,
  runHourlyOneCRetry,
  runDailyOutboundAlert,
  runDailyRetentionPurge,
  getStorageStats,
  fetchStaleOutbound,
};
