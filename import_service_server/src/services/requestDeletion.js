const fs = require('fs/promises');
const path = require('path');
const { unlinkIfExists } = require('../util/imagePreview');
const {
  CHAT_UPLOAD_ROOT,
  chatAttachmentDiskPath,
} = require('./chatAttachmentStorage');

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

function collectChatStoredNamesFromJson(value) {
  let parsed = value;
  if (typeof value === 'string') {
    try {
      parsed = JSON.parse(value);
    } catch {
      return [];
    }
  }
  if (!parsed) return [];

  let list = [];
  if (Array.isArray(parsed)) {
    list = parsed;
  } else if (Array.isArray(parsed.attachments)) {
    list = parsed.attachments;
  }

  const names = [];
  for (const item of list) {
    if (!item || typeof item !== 'object') continue;
    const raw = String(
      item.storedName || item.stored_name || item.fileUrl || item.file_url || '',
    ).trim();
    if (!raw) continue;
    const fromFiles = /(?:\/api)?\/customs-requests\/files\/([^/?#]+)/i.exec(raw);
    if (fromFiles) {
      const name = decodeURIComponent(fromFiles[1]);
      if (/^r\d+_[\w.-]+$/i.test(name)) {
        names.push(name);
        continue;
      }
    }
    const fromPathFiles = /(?:\/api)?\/customs-requests\/files\/([^/?#]+)/i.exec(raw);
    if (fromPathFiles) {
      names.push(decodeURIComponent(fromPathFiles[1]));
      continue;
    }
    const fromPath = /(?:\/api)?\/chat-attachments\/([^/?#]+)/i.exec(raw);
    if (fromPath) {
      names.push(decodeURIComponent(fromPath[1]));
      continue;
    }
    if (/^r\d+_[\w.-]+$/i.test(raw)) {
      names.push(raw);
    }
  }
  return names;
}

async function unlinkChatAttachment(storedName) {
  const diskPath = chatAttachmentDiskPath(storedName);
  if (!diskPath) return false;
  try {
    await fs.unlink(diskPath);
    return true;
  } catch (e) {
    if (e && e.code === 'ENOENT') return false;
    throw e;
  }
}

/**
 * Удалить вложения чата с диска + soft-delete сообщений заявки.
 * Диск: по attachments_json и по маске имени r{requestId}_* (сироты upload).
 */
async function deleteChatForRequest(pool, requestId) {
  const id = Number(requestId);
  if (!Number.isFinite(id) || id <= 0) {
    return { chatMessagesSoftDeleted: 0, chatFilesRemoved: 0 };
  }

  const storedNames = new Set();
  try {
    const [msgRows] = await pool.query(
      `SELECT attachments_json
       FROM customs_request_messages
       WHERE request_id = ?`,
      [id],
    );
    for (const row of msgRows) {
      for (const name of collectChatStoredNamesFromJson(row.attachments_json)) {
        storedNames.add(name);
      }
    }
  } catch (e) {
    if (e.code !== 'ER_NO_SUCH_TABLE') throw e;
    return { chatMessagesSoftDeleted: 0, chatFilesRemoved: 0 };
  }

  try {
    const entries = await fs.readdir(CHAT_UPLOAD_ROOT);
    const prefix = `r${id}_`;
    for (const name of entries) {
      if (name.startsWith(prefix)) {
        storedNames.add(name);
      }
    }
  } catch (e) {
    if (e.code !== 'ENOENT') throw e;
  }

  let chatFilesRemoved = 0;
  for (const name of storedNames) {
    if (await unlinkChatAttachment(name)) {
      chatFilesRemoved += 1;
    }
  }

  let chatMessagesSoftDeleted = 0;
  try {
    const [result] = await pool.query(
      `UPDATE customs_request_messages
       SET deleted_at = CURRENT_TIMESTAMP(3), updated_at = CURRENT_TIMESTAMP(3)
       WHERE request_id = ? AND deleted_at IS NULL`,
      [id],
    );
    chatMessagesSoftDeleted = Number(result.affectedRows) || 0;
  } catch (e) {
    if (e.code !== 'ER_NO_SUCH_TABLE') throw e;
  }

  return { chatMessagesSoftDeleted, chatFilesRemoved };
}

/**
 * Мягкое удаление заявки + файлы заявки + чат/вложения чата с диска.
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

  const chat = await deleteChatForRequest(pool, id);

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
    chatMessagesSoftDeleted: chat.chatMessagesSoftDeleted,
    chatFilesRemoved: chat.chatFilesRemoved,
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
  let chatFilesRemoved = 0;
  let chatMessagesSoftDeleted = 0;
  for (const row of rows) {
    const r = await deleteCustomsRequestWithFiles(pool, row.id, uploadRoot);
    if (r.ok) {
      deleted += 1;
      filesRemoved += r.deletedFiles || 0;
      chatFilesRemoved += r.chatFilesRemoved || 0;
      chatMessagesSoftDeleted += r.chatMessagesSoftDeleted || 0;
    }
  }
  return {
    deleted,
    filesRemoved,
    chatFilesRemoved,
    chatMessagesSoftDeleted,
    scanned: rows.length,
    retentionMonths: months,
  };
}

module.exports = {
  deleteCustomsRequestWithFiles,
  purgeExpiredClosedRequests,
  deleteChatForRequest,
  deleteFilesFromDisk,
  DEFAULT_UPLOAD_ROOT,
};
