const fs = require('fs/promises');
const path = require('path');
const { unlinkIfExists } = require('../util/imagePreview');

const DEFAULT_UPLOAD_ROOT = path.join(process.cwd(), 'uploads', 'customs-requests');

async function fetchFileRowsForRequest(pool, requestId) {
  const [rows] = await pool.query(
    `SELECT id, stored_name, preview_stored_name
     FROM customs_request_files
     WHERE request_id = ? AND deleted_at IS NULL`,
    [requestId],
  );
  return rows;
}

async function deleteFilesFromDisk(uploadRoot, fileRows) {
  for (const row of fileRows) {
    await unlinkIfExists(uploadRoot, row.stored_name);
    await unlinkIfExists(uploadRoot, row.preview_stored_name);
  }
}

/**
 * Мягкое удаление заявки + файлы с диска (только админка).
 */
async function deleteCustomsRequestWithFiles(pool, requestId, uploadRoot = DEFAULT_UPLOAD_ROOT) {
  const id = Number(requestId);
  if (!Number.isFinite(id) || id <= 0) {
    return { ok: false, error: 'VALIDATION_ERROR' };
  }

  const [reqRows] = await pool.query(
    `SELECT id FROM customs_requests WHERE id = ? AND deleted_at IS NULL LIMIT 1`,
    [id],
  );
  if (!reqRows.length) {
    return { ok: false, error: 'NOT_FOUND' };
  }

  const fileRows = await fetchFileRowsForRequest(pool, id);
  await deleteFilesFromDisk(uploadRoot, fileRows);

  await pool.query(
    `UPDATE customs_request_files
     SET deleted_at = CURRENT_TIMESTAMP(3), updated_at = CURRENT_TIMESTAMP(3)
     WHERE request_id = ? AND deleted_at IS NULL`,
    [id],
  );

  try {
    await pool.query(`DELETE FROM customs_request_upload_batch WHERE request_id = ?`, [id]);
  } catch (e) {
    if (e.code !== 'ER_NO_SUCH_TABLE') throw e;
  }

  const [result] = await pool.query(
    `UPDATE customs_requests
     SET deleted_at = CURRENT_TIMESTAMP(3), updated_at = CURRENT_TIMESTAMP(3)
     WHERE id = ? AND deleted_at IS NULL`,
    [id],
  );

  return {
    ok: result.affectedRows > 0,
    deletedFiles: fileRows.length,
  };
}

/**
 * Автоочистка: только status=closed старше retentionMonths.
 */
async function purgeExpiredClosedRequests(pool, retentionMonths, uploadRoot = DEFAULT_UPLOAD_ROOT) {
  const months = Math.max(1, Math.min(120, Number(retentionMonths) || 6));
  const [rows] = await pool.query(
    `SELECT id
     FROM customs_requests
     WHERE deleted_at IS NULL
       AND status = 'closed'
       AND updated_at < DATE_SUB(NOW(3), INTERVAL ? MONTH)
     ORDER BY updated_at ASC
     LIMIT 50`,
    [months],
  );

  let deleted = 0;
  let filesRemoved = 0;
  for (const row of rows) {
    const r = await deleteCustomsRequestWithFiles(pool, row.id, uploadRoot);
    if (r.ok) {
      deleted += 1;
      filesRemoved += r.deletedFiles || 0;
    }
  }
  return { deleted, filesRemoved, scanned: rows.length, retentionMonths: months };
}

module.exports = {
  deleteCustomsRequestWithFiles,
  purgeExpiredClosedRequests,
  deleteFilesFromDisk,
  DEFAULT_UPLOAD_ROOT,
};
