const { normalizeDocType, REQUIRED_DOCUMENT_TYPES_ON_CREATE } = require('../constants/customsCatalog');
const { storageKeyForRequest, renameRequestFilesToExternal1cId } = require('../util/requestFileStorage');
const { submitCustomsRequestTo1CFromDb } = require('./oneCRequestCreate');
const { pushCustomsRequestUpdateTo1C } = require('./oneCUpdateSync');
const { notifyFilesChangedFrom1C } = require('./pushNotifications');
const { isDemoApplicantName, completeDemoCreateFromMpUpload, isDemoExternal1cId, tryAdvanceDemoFlow } = require('./demoFlow');

const UPLOAD_ROOT = require('path').join(process.cwd(), 'uploads', 'customs-requests');

function normalize(v) {
  return String(v ?? '').trim();
}

function parseBatchIndices(json) {
  if (!json) return {};
  if (typeof json === 'object' && !Buffer.isBuffer(json)) return json;
  try {
    return JSON.parse(String(json));
  } catch {
    return {};
  }
}

async function fetchRequestRow(pool, requestId) {
  const [rows] = await pool.query(
    `SELECT id, status, status_sub_type, external_1c_id, legal_email, individual_full_name
     FROM customs_requests
     WHERE id = ? AND deleted_at IS NULL
     LIMIT 1`,
    [requestId],
  );
  return rows[0] || null;
}

async function loadBatch(pool, requestId) {
  try {
    const [rows] = await pool.query(
      `SELECT upload_total, source, indices_json
       FROM customs_request_upload_batch
       WHERE request_id = ?`,
      [requestId],
    );
    return rows[0] || null;
  } catch (e) {
    if (e && e.code === 'ER_NO_SUCH_TABLE') return null;
    throw e;
  }
}

async function saveBatch(pool, requestId, uploadTotal, source, indices) {
  try {
    await pool.query(
    `INSERT INTO customs_request_upload_batch (request_id, upload_total, source, indices_json)
     VALUES (?, ?, ?, ?)
     ON DUPLICATE KEY UPDATE
       upload_total = VALUES(upload_total),
       source = VALUES(source),
       indices_json = VALUES(indices_json),
       updated_at = CURRENT_TIMESTAMP(3)`,
    [requestId, uploadTotal, source, JSON.stringify(indices)],
    );
  } catch (e) {
    if (e && e.code === 'ER_NO_SUCH_TABLE') return;
    throw e;
  }
}

async function clearBatch(pool, requestId) {
  try {
    await pool.query(`DELETE FROM customs_request_upload_batch WHERE request_id = ?`, [requestId]);
  } catch (e) {
    if (e && e.code === 'ER_NO_SUCH_TABLE') return;
    throw e;
  }
}

function batchIsComplete(indices, uploadTotal) {
  const total = Number(uploadTotal);
  if (!Number.isFinite(total) || total < 1) return false;
  for (let i = 1; i <= total; i += 1) {
    if (!indices[String(i)]) return false;
  }
  return true;
}

function collectChangedDocTypes(indices) {
  const set = new Set();
  for (const docType of Object.values(indices)) {
    const dt = normalizeDocType(docType);
    if (dt) set.add(dt);
  }
  return Array.from(set);
}

function validateCreateDocuments(pool, requestId) {
  return pool
    .query(
      `SELECT doc_type FROM customs_request_files
       WHERE request_id = ? AND deleted_at IS NULL`,
      [requestId],
    )
    .then(([rows]) => {
      const have = new Set(rows.map((r) => normalizeDocType(r.doc_type)));
      const missing = REQUIRED_DOCUMENT_TYPES_ON_CREATE.filter((t) => !have.has(t));
      if (missing.length) {
        throw new Error(
          `VALIDATION_ERROR: не загружены обязательные документы: ${missing.join(', ')}`,
        );
      }
    });
}

async function syncAfterBatchComplete(fastify, requestId, source, changedDocTypes, requestLike) {
  const row = await fetchRequestRow(fastify.pool, requestId);
  if (!row) return { ok: false, error: 'NOT_FOUND' };

  if (source === 'integration') {
    await notifyFilesChangedFrom1C(fastify, {
      requestId,
      external1cId: row.external_1c_id,
      status: row.status,
      changedDocTypes,
    }).catch((e) => {
      fastify.log.warn({ requestId, err: e.message }, 'push files changed failed');
    });
    return { ok: true, action: 'push_mp' };
  }

  // МП — завершение первичной пачки (create)
  if (row.status === 'new' && !row.external_1c_id) {
    await validateCreateDocuments(fastify.pool, requestId);

    if (
      fastify.config.demoFlow?.enabled &&
      isDemoApplicantName(row.individual_full_name)
    ) {
      const demoCreate = await completeDemoCreateFromMpUpload(fastify, requestId);
      return { ok: true, action: 'demo_create_linked', demoCreate };
    }

    const createResult = await submitCustomsRequestTo1CFromDb(fastify, requestId);
    if (!createResult.ok) {
      return { ok: false, error: createResult.error || 'ONE_C_CREATE_FAILED', createResult };
    }
    const updated = await fetchRequestRow(fastify.pool, requestId);
    if (updated?.external_1c_id) {
      await renameRequestFilesToExternal1cId(
        fastify.pool,
        UPLOAD_ROOT,
        requestId,
        updated.external_1c_id,
      );
      const allFiles = await fetchAllFilesForOneC(fastify.pool, requestId);
      const oneCUpdate = await pushCustomsRequestUpdateTo1C(fastify, requestId, {
        files: allFiles,
        requestLike,
      });
      return { ok: true, action: 'create_1c_and_update_urls', createResult, oneCUpdate };
    }
    return { ok: true, action: 'create_1c', createResult };
  }

  if (!row.external_1c_id) {
    fastify.log.warn({ requestId }, 'upload batch complete but no external1cId, skip 1C update');
    return { ok: true, action: 'skipped_no_external1cId' };
  }

  if (isDemoExternal1cId(row.external_1c_id)) {
    const demoAdvance = await tryAdvanceDemoFlow(fastify, requestId);
    return { ok: true, action: 'demo_upload', demoAdvance };
  }

  const fileRows = await fetchAllFilesForOneC(fastify.pool, requestId);
  const filesForUpdate = fileRows.filter((f) => changedDocTypes.includes(f.docType));

  const oneCUpdate = await pushCustomsRequestUpdateTo1C(fastify, requestId, {
    files: filesForUpdate,
    requestLike,
  });
  return { ok: true, action: 'update_1c', oneCUpdate };
}

async function fetchAllFilesForOneC(pool, requestId) {
  const [rows] = await pool.query(
    `SELECT doc_type, original_name, mime_type, file_url
     FROM customs_request_files
     WHERE request_id = ? AND deleted_at IS NULL`,
    [requestId],
  );
  return rows.map((r) => ({
    docType: normalizeDocType(r.doc_type),
    fileName: r.original_name,
    mimeType: r.mime_type,
    fileUrl: r.file_url,
  }));
}

/**
 * Учесть upload в батче; при завершении — sync MP↔1С.
 */
async function recordUploadAndMaybeSync(fastify, opts) {
  const requestId = Number(opts.requestId);
  const uploadIndex = Number(opts.uploadIndex);
  const uploadTotal = Number(opts.uploadTotal);
  const docType = normalizeDocType(opts.docType);
  const source = opts.source === 'integration' ? 'integration' : 'user';

  if (!Number.isFinite(requestId) || requestId <= 0) {
    throw new Error('VALIDATION_ERROR: requestId обязателен');
  }
  if (!docType) {
    throw new Error('VALIDATION_ERROR: docType обязателен');
  }
  if (!Number.isFinite(uploadIndex) || uploadIndex < 1 || uploadIndex > uploadTotal) {
    throw new Error('VALIDATION_ERROR: uploadIndex должен быть от 1 до uploadTotal');
  }
  if (!Number.isFinite(uploadTotal) || uploadTotal < 1 || uploadTotal > 64) {
    throw new Error('VALIDATION_ERROR: uploadTotal от 1 до 64');
  }

  const existing = await loadBatch(fastify.pool, requestId);
  let indices = {};
  if (existing && Number(existing.upload_total) === uploadTotal && existing.source === source) {
    indices = parseBatchIndices(existing.indices_json);
  }
  indices[String(uploadIndex)] = docType;
  await saveBatch(fastify.pool, requestId, uploadTotal, source, indices);

  const changedDocTypes = [docType];
  let syncResult = null;

  if (uploadTotal === 1 && uploadIndex === 1) {
    await clearBatch(fastify.pool, requestId);
    syncResult = await syncAfterBatchComplete(
      fastify,
      requestId,
      source,
      changedDocTypes,
      opts.requestLike,
    );
  } else if (batchIsComplete(indices, uploadTotal)) {
    const allChanged = collectChangedDocTypes(indices);
    await clearBatch(fastify.pool, requestId);
    syncResult = await syncAfterBatchComplete(
      fastify,
      requestId,
      source,
      allChanged,
      opts.requestLike,
    );
  }

  return {
    batchComplete: Boolean(syncResult),
    syncResult,
    uploadIndex,
    uploadTotal,
  };
}

module.exports = {
  recordUploadAndMaybeSync,
  syncAfterBatchComplete,
  validateCreateDocuments,
};
