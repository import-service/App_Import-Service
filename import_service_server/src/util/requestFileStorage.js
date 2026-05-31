const fs = require('fs/promises');
const path = require('path');
const { normalizeDocType } = require('../constants/customsCatalog');

function normalize(v) {
  return String(v ?? '').trim();
}

function sanitizeStorageKey(key) {
  return normalize(key).replace(/[^a-zA-Z0-9._-]/g, '_') || 'unknown';
}

function extensionFromFilename(filename, mimeType) {
  const base = normalize(filename);
  const ext = path.extname(base);
  if (ext && ext.length <= 12) return ext.toLowerCase();
  const mt = normalize(mimeType).toLowerCase();
  if (mt === 'application/pdf') return '.pdf';
  if (mt === 'image/jpeg' || mt === 'image/jpg') return '.jpg';
  if (mt === 'image/png') return '.png';
  if (mt === 'video/mp4') return '.mp4';
  return '.bin';
}

/** Имя файла на диске: {storageKey}__{docType}.{ext} */
function buildStoredFileName(storageKey, docType, ext) {
  const safeKey = sanitizeStorageKey(storageKey);
  const safeDoc = normalizeDocType(docType) || 'uploaded_file';
  const safeExt = ext.startsWith('.') ? ext : `.${ext}`;
  return `${safeKey}__${safeDoc}${safeExt}`;
}

function buildFileUrl(storedName) {
  return `/api/customs-requests/files/${storedName}`;
}

function storageKeyForRequest(row) {
  if (row.external_1c_id) {
    return sanitizeStorageKey(row.external_1c_id);
  }
  return `r${row.id}`;
}

/**
 * Сохранить/перезаписать файл заявки по docType.
 * @returns {{ storedName, fileUrl, mimeType, fileSizeBytes, docType, replaced: boolean }}
 */
async function upsertRequestFile(pool, uploadRoot, requestId, storageKey, docType, buffer, mimeType) {
  const dt = normalizeDocType(docType);
  if (!dt) {
    throw new Error('VALIDATION_ERROR: docType обязателен');
  }

  const ext = extensionFromFilename('', mimeType);
  const storedName = buildStoredFileName(storageKey, dt, ext);
  const filePath = path.join(uploadRoot, storedName);
  await fs.writeFile(filePath, buffer);

  const fileUrl = buildFileUrl(storedName);
  const fileSizeBytes = buffer.length;

  const [existing] = await pool.query(
    `SELECT id, stored_name
     FROM customs_request_files
     WHERE request_id = ? AND doc_type = ? AND deleted_at IS NULL
     LIMIT 1`,
    [requestId, dt],
  );

  let replaced = false;
  if (existing.length) {
    replaced = true;
    const oldStored = existing[0].stored_name;
    if (oldStored && oldStored !== storedName) {
      try {
        await fs.unlink(path.join(uploadRoot, oldStored));
      } catch {
        // ignore missing old file
      }
    }
    await pool.query(
      `UPDATE customs_request_files
       SET original_name = ?, stored_name = ?, mime_type = ?, file_size_bytes = ?, file_url = ?,
           updated_at = CURRENT_TIMESTAMP(3)
       WHERE id = ?`,
      [storedName, storedName, mimeType, fileSizeBytes, fileUrl, existing[0].id],
    );
  } else {
    await pool.query(
      `INSERT INTO customs_request_files
         (request_id, doc_type, original_name, stored_name, mime_type, file_size_bytes, file_url)
       VALUES (?, ?, ?, ?, ?, ?, ?)`,
      [requestId, dt, storedName, storedName, mimeType, fileSizeBytes, fileUrl],
    );
  }

  return {
    storedName,
    fileUrl,
    mimeType,
    fileSizeBytes,
    docType: dt,
    replaced,
  };
}

/** После create в 1С: r{id}__* → {external1cId}__* */
async function renameRequestFilesToExternal1cId(pool, uploadRoot, requestId, external1cId) {
  const newKey = sanitizeStorageKey(external1cId);
  const oldKey = `r${requestId}`;

  const [fileRows] = await pool.query(
    `SELECT id, doc_type, stored_name, mime_type
     FROM customs_request_files
     WHERE request_id = ? AND deleted_at IS NULL`,
    [requestId],
  );

  for (const row of fileRows) {
    const dt = row.doc_type;
    const ext = extensionFromFilename(row.stored_name, row.mime_type);
    const newStored = buildStoredFileName(newKey, dt, ext);
    const oldPath = path.join(uploadRoot, row.stored_name);
    const newPath = path.join(uploadRoot, newStored);

    if (row.stored_name !== newStored) {
      try {
        await fs.rename(oldPath, newPath);
      } catch (e) {
        if (e.code === 'ENOENT') {
          continue;
        }
        throw e;
      }
    }

    const fileUrl = buildFileUrl(newStored);
    await pool.query(
      `UPDATE customs_request_files
       SET stored_name = ?, original_name = ?, file_url = ?, updated_at = CURRENT_TIMESTAMP(3)
       WHERE id = ?`,
      [newStored, newStored, fileUrl, row.id],
    );
  }

  return { oldKey, newKey, count: fileRows.length };
}

module.exports = {
  sanitizeStorageKey,
  buildStoredFileName,
  buildFileUrl,
  storageKeyForRequest,
  upsertRequestFile,
  renameRequestFilesToExternal1cId,
  extensionFromFilename,
};
