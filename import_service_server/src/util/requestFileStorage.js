const fs = require('fs/promises');
const path = require('path');
const { normalizeDocType } = require('../constants/customsCatalog');
const { ensureDisplayFileName } = require('./displayFileName');
const { resolveFileKind } = require('./fileKindDetect');
const { generateImagePreviewBuffer, writePreviewFile, unlinkIfExists } = require('./imagePreview');
const { maybeExtractAllFromArchive } = require('./archiveExtract');

function normalize(v) {
  return String(v ?? '').trim();
}

function escapeRegExp(s) {
  return String(s).replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

function sanitizeStorageKey(key) {
  return normalize(key).replace(/[^a-zA-Z0-9._-]/g, '_') || 'unknown';
}

function extensionFromFilename(filename, mimeType) {
  const kind = resolveFileKind({
    buffer: null,
    clientFileName: filename,
    mimeType,
  });
  return kind.ext;
}

/** Имя файла на диске: {storageKey}__{docType}.{ext} */
function buildStoredFileName(storageKey, docType, ext) {
  const safeKey = sanitizeStorageKey(storageKey);
  const safeDoc = normalizeDocType(docType) || 'uploaded_file';
  const safeExt = ext.startsWith('.') ? ext : `.${ext}`;
  return `${safeKey}__${safeDoc}${safeExt}`;
}

function buildPreviewStoredName(storageKey, docType) {
  return buildStoredFileName(storageKey, `${normalizeDocType(docType)}_preview`, '.jpg');
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

const CUSTOMS_REQUEST_FILE_SELECT = `
  id, doc_type, original_name, source_file_name, source_mime_type, upload_source,
  stored_name, preview_stored_name, mime_type,
  file_size_bytes, file_url, preview_url, created_at, updated_at
`.replace(/\s+/g, ' ');

/**
 * Сохранить/перезаписать файл заявки по docType.
 * @param {object} [meta]
 * @param {string} [meta.sourceFileName] — имя как пришло в upload
 * @param {string} [meta.sourceMimeType] — mime как пришёл (до детекта)
 * @param {string} [meta.uploadSource] — integration | user | demo
 */
/** Удалить (soft) старые файлы слота dt и его номерные X_1..X_N (при повторной загрузке архива). */
async function removeExistingSlotFiles(pool, uploadRoot, requestId, dt) {
  const [rows] = await pool.query(
    `SELECT id, stored_name, preview_stored_name, doc_type
     FROM customs_request_files
     WHERE request_id = ? AND deleted_at IS NULL
       AND (doc_type = ? OR doc_type LIKE ?)`,
    [requestId, dt, `${dt.replace(/[%_]/g, '\\$&')}\\_%`],
  );
  const childRe = new RegExp(`^${escapeRegExp(dt)}_\\d+$`);
  const ids = [];
  for (const row of rows) {
    if (row.doc_type !== dt && !childRe.test(row.doc_type)) continue;
    if (row.stored_name) await unlinkIfExists(uploadRoot, row.stored_name);
    if (row.preview_stored_name) await unlinkIfExists(uploadRoot, row.preview_stored_name);
    ids.push(row.id);
  }
  if (ids.length) {
    await pool.query(
      `UPDATE customs_request_files SET deleted_at = CURRENT_TIMESTAMP(3)
       WHERE id IN (${ids.map(() => '?').join(',')})`,
      ids,
    );
  }
}

/** Записать один файл на диск + превью + вставить строку в БД. */
async function insertFileRow(
  pool,
  uploadRoot,
  requestId,
  storageKey,
  childDocType,
  buffer,
  mimeType,
  clientFileName,
  { sourceFileName, sourceMimeType, uploadSource },
) {
  const kind = resolveFileKind({
    buffer,
    clientFileName: sourceFileName || clientFileName,
    mimeType,
  });
  const effectiveMime = kind.mimeType;
  const storedName = buildStoredFileName(storageKey, childDocType, kind.ext);
  await fs.writeFile(path.join(uploadRoot, storedName), buffer);

  const fileUrl = buildFileUrl(storedName);
  const displayFileName = ensureDisplayFileName({
    docType: childDocType,
    mimeType: effectiveMime,
    storedName,
    clientFileName: clientFileName || sourceFileName,
  });

  let previewStoredName = null;
  let previewUrl = null;
  const previewBuffer = await generateImagePreviewBuffer(buffer, effectiveMime, childDocType);
  if (previewBuffer) {
    previewStoredName = buildPreviewStoredName(storageKey, childDocType);
    await writePreviewFile(uploadRoot, previewStoredName, previewBuffer);
    previewUrl = buildFileUrl(previewStoredName);
  }

  await pool.query(
    `INSERT INTO customs_request_files
       (request_id, doc_type, original_name, source_file_name, source_mime_type, upload_source,
        stored_name, preview_stored_name, mime_type, file_size_bytes, file_url, preview_url)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
    [
      requestId,
      childDocType,
      displayFileName,
      sourceFileName,
      sourceMimeType,
      uploadSource,
      storedName,
      previewStoredName,
      effectiveMime,
      buffer.length,
      fileUrl,
      previewUrl,
    ],
  );

  return {
    storedName,
    fileName: displayFileName,
    fileUrl,
    previewStoredName,
    previewUrl,
    mimeType: effectiveMime,
    fileSizeBytes: buffer.length,
    docType: childDocType,
    detectedFrom: kind.detectedFrom,
    sourceFileName,
    sourceMimeType,
    uploadSource,
  };
}

/**
 * Развернуть архив в отдельные файлы X_1..X_N (или X, если внутри один файл).
 * source_file_name у всех детей = имя архива → админка группирует их в карусель.
 */
async function storeExplodedArchive(
  pool,
  uploadRoot,
  requestId,
  storageKey,
  dt,
  items,
  archiveName,
  { sourceMimeType, uploadSource },
) {
  await removeExistingSlotFiles(pool, uploadRoot, requestId, dt);
  const single = items.length === 1;
  const saved = [];
  for (let i = 0; i < items.length; i += 1) {
    const item = items[i];
    const childDocType = single ? dt : `${dt}_${i + 1}`;
    // eslint-disable-next-line no-await-in-loop
    const row = await insertFileRow(
      pool,
      uploadRoot,
      requestId,
      storageKey,
      childDocType,
      item.buffer,
      item.mimeType,
      item.fileName,
      { sourceFileName: archiveName || null, sourceMimeType, uploadSource },
    );
    saved.push(row);
  }
  const first = saved[0];
  return {
    ...first,
    replaced: true,
    exploded: true,
    count: saved.length,
    childDocTypes: saved.map((s) => s.docType),
  };
}

async function upsertRequestFile(
  pool,
  uploadRoot,
  requestId,
  storageKey,
  docType,
  buffer,
  mimeType,
  clientFileName,
  meta = {},
) {
  const dt = normalizeDocType(docType);
  if (!dt) {
    throw new Error('VALIDATION_ERROR: docType обязателен');
  }

  const sourceFileName =
    normalize(meta.sourceFileName != null ? meta.sourceFileName : clientFileName) || null;
  const sourceMimeType = normalize(meta.sourceMimeType) || null;
  const uploadSource = normalize(meta.uploadSource) || null;

  const extractedAll = await maybeExtractAllFromArchive(buffer, { docType: dt });
  if (extractedAll.length) {
    const archiveName = normalize(clientFileName) || sourceFileName;
    return storeExplodedArchive(pool, uploadRoot, requestId, storageKey, dt, extractedAll, archiveName, {
      sourceMimeType,
      uploadSource,
    });
  }

  const workingBuffer = buffer;
  const workingClientName = clientFileName;
  const workingMime = mimeType;

  const kind = resolveFileKind({
    buffer: workingBuffer,
    clientFileName: sourceFileName || workingClientName,
    mimeType: workingMime,
  });
  const effectiveMime = kind.mimeType;
  const ext = kind.ext;
  const storedName = buildStoredFileName(storageKey, dt, ext);
  const filePath = path.join(uploadRoot, storedName);
  await fs.writeFile(filePath, workingBuffer);

  const fileUrl = buildFileUrl(storedName);
  const fileSizeBytes = workingBuffer.length;
  const displayFileName = ensureDisplayFileName({
    docType: dt,
    mimeType: effectiveMime,
    storedName,
    clientFileName: workingClientName || sourceFileName,
  });

  let previewStoredName = null;
  let previewUrl = null;
  const previewBuffer = await generateImagePreviewBuffer(workingBuffer, effectiveMime, dt);
  if (previewBuffer) {
    previewStoredName = buildPreviewStoredName(storageKey, dt);
    await writePreviewFile(uploadRoot, previewStoredName, previewBuffer);
    previewUrl = buildFileUrl(previewStoredName);
  }

  const [existing] = await pool.query(
    `SELECT id, stored_name, preview_stored_name
     FROM customs_request_files
     WHERE request_id = ? AND doc_type = ? AND deleted_at IS NULL
     LIMIT 1`,
    [requestId, dt],
  );

  let replaced = false;
  if (existing.length) {
    replaced = true;
    const oldStored = existing[0].stored_name;
    const oldPreview = existing[0].preview_stored_name;
    if (oldStored && oldStored !== storedName) {
      await unlinkIfExists(uploadRoot, oldStored);
    }
    if (oldPreview && oldPreview !== previewStoredName) {
      await unlinkIfExists(uploadRoot, oldPreview);
    }
    await pool.query(
      `UPDATE customs_request_files
       SET original_name = ?, source_file_name = ?, source_mime_type = ?, upload_source = ?,
           stored_name = ?, preview_stored_name = ?, mime_type = ?,
           file_size_bytes = ?, file_url = ?, preview_url = ?,
           updated_at = CURRENT_TIMESTAMP(3)
       WHERE id = ?`,
      [
        displayFileName,
        sourceFileName,
        sourceMimeType,
        uploadSource,
        storedName,
        previewStoredName,
        effectiveMime,
        fileSizeBytes,
        fileUrl,
        previewUrl,
        existing[0].id,
      ],
    );
  } else {
    await pool.query(
      `INSERT INTO customs_request_files
         (request_id, doc_type, original_name, source_file_name, source_mime_type, upload_source,
          stored_name, preview_stored_name, mime_type, file_size_bytes, file_url, preview_url)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        requestId,
        dt,
        displayFileName,
        sourceFileName,
        sourceMimeType,
        uploadSource,
        storedName,
        previewStoredName,
        effectiveMime,
        fileSizeBytes,
        fileUrl,
        previewUrl,
      ],
    );
  }

  return {
    storedName,
    fileName: displayFileName,
    fileUrl,
    previewStoredName,
    previewUrl,
    mimeType: effectiveMime,
    fileSizeBytes,
    docType: dt,
    replaced,
    detectedFrom: kind.detectedFrom,
    sourceFileName,
    sourceMimeType,
    uploadSource,
  };
}

/** После create в 1С: r{id}__* → {external1cId}__* */
async function renameRequestFilesToExternal1cId(pool, uploadRoot, requestId, external1cId) {
  const newKey = sanitizeStorageKey(external1cId);

  const [fileRows] = await pool.query(
    `SELECT id, doc_type, stored_name, preview_stored_name, mime_type, original_name
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

    let newPreviewStored = row.preview_stored_name;
    let newPreviewUrl = null;
    if (row.preview_stored_name) {
      newPreviewStored = buildPreviewStoredName(newKey, dt);
      const oldPreviewPath = path.join(uploadRoot, row.preview_stored_name);
      const newPreviewPath = path.join(uploadRoot, newPreviewStored);
      if (row.preview_stored_name !== newPreviewStored) {
        try {
          await fs.rename(oldPreviewPath, newPreviewPath);
        } catch (e) {
          if (e.code !== 'ENOENT') throw e;
        }
      }
      newPreviewUrl = buildFileUrl(newPreviewStored);
    }

    const fileUrl = buildFileUrl(newStored);
    const displayFileName = ensureDisplayFileName({
      docType: dt,
      mimeType: row.mime_type,
      storedName: newStored,
      clientFileName: row.original_name,
    });
    await pool.query(
      `UPDATE customs_request_files
       SET stored_name = ?, original_name = ?, file_url = ?,
           preview_stored_name = ?, preview_url = ?,
           updated_at = CURRENT_TIMESTAMP(3)
       WHERE id = ?`,
      [newStored, displayFileName, fileUrl, newPreviewStored, newPreviewUrl, row.id],
    );
  }

  return { newKey, count: fileRows.length };
}

module.exports = {
  sanitizeStorageKey,
  buildStoredFileName,
  buildPreviewStoredName,
  buildFileUrl,
  storageKeyForRequest,
  upsertRequestFile,
  renameRequestFilesToExternal1cId,
  extensionFromFilename,
  CUSTOMS_REQUEST_FILE_SELECT,
};
