const fs = require('fs/promises');
const path = require('path');
const JSZip = require('jszip');
const { normalizeDocType } = require('../constants/customsCatalog');
const {
  storageKeyForRequest,
  removeExistingSlotFiles,
  insertFileRow,
} = require('../util/requestFileStorage');

const UPLOAD_ROOT = path.join(process.cwd(), 'uploads', 'customs-requests');
const TRANSIT_ARCHIVE_PHOTOS_ZIP_DOC_TYPE = 'transit_archive_photos_zip';

function isTransitArchivePhotoDocType(docType) {
  return /^transit_archive_photo_\d+$/.test(normalizeDocType(docType));
}

function changedIncludesTransitArchivePhotos(changedDocTypes) {
  return (changedDocTypes || []).some(isTransitArchivePhotoDocType);
}

async function loadTransitArchivePhotoRows(pool, requestId) {
  const [rows] = await pool.query(
    `SELECT id, doc_type, original_name, stored_name, mime_type, file_url
     FROM customs_request_files
     WHERE request_id = ? AND deleted_at IS NULL
       AND doc_type REGEXP '^transit_archive_photo_[0-9]+$'
     ORDER BY CAST(SUBSTRING(doc_type, 24) AS UNSIGNED) ASC, id ASC`,
    [requestId],
  );
  return rows;
}

async function buildTransitArchivePhotosZipBuffer(pool, requestId) {
  const rows = await loadTransitArchivePhotoRows(pool, requestId);
  if (!rows.length) {
    return { buffer: null, count: 0, rows: [] };
  }
  const zip = new JSZip();
  let added = 0;
  for (const row of rows) {
    const stored = String(row.stored_name || '').trim();
    if (!stored) continue;
    const abs = path.join(UPLOAD_ROOT, stored);
    let buf;
    try {
      // eslint-disable-next-line no-await-in-loop
      buf = await fs.readFile(abs);
    } catch {
      continue;
    }
    const baseName =
      String(row.original_name || '').trim() ||
      `${normalizeDocType(row.doc_type)}.jpg`;
    const safeName = baseName.replace(/[\\/:*?"<>|]/g, '_');
    zip.file(`${String(added + 1).padStart(2, '0')}_${safeName}`, buf);
    added += 1;
  }
  if (!added) {
    return { buffer: null, count: 0, rows };
  }
  const buffer = await zip.generateAsync({
    type: 'nodebuffer',
    compression: 'DEFLATE',
    compressionOptions: { level: 6 },
  });
  return { buffer, count: added, rows };
}

/**
 * Пересобрать ZIP архива транзита, сохранить как transit_archive_photos_zip.
 */
async function rebuildAndStoreTransitArchivePhotosZip(fastify, requestId) {
  const [reqRows] = await fastify.pool.query(
    `SELECT id, external_1c_id FROM customs_requests
     WHERE id = ? AND deleted_at IS NULL LIMIT 1`,
    [requestId],
  );
  const req = reqRows[0];
  if (!req) {
    return { ok: false, error: 'NOT_FOUND' };
  }

  const { buffer, count } = await buildTransitArchivePhotosZipBuffer(
    fastify.pool,
    requestId,
  );
  if (!buffer || count < 1) {
    await removeExistingSlotFiles(
      fastify.pool,
      UPLOAD_ROOT,
      requestId,
      TRANSIT_ARCHIVE_PHOTOS_ZIP_DOC_TYPE,
    );
    return { ok: true, count: 0, cleared: true };
  }

  const storageKey = storageKeyForRequest(req);
  await removeExistingSlotFiles(
    fastify.pool,
    UPLOAD_ROOT,
    requestId,
    TRANSIT_ARCHIVE_PHOTOS_ZIP_DOC_TYPE,
  );
  const saved = await insertFileRow(
    fastify.pool,
    UPLOAD_ROOT,
    requestId,
    storageKey,
    TRANSIT_ARCHIVE_PHOTOS_ZIP_DOC_TYPE,
    buffer,
    'application/zip',
    `transit_archive_photos_${requestId}.zip`,
    {
      sourceFileName: `transit_archive_photos_${requestId}.zip`,
      sourceMimeType: 'application/zip',
      uploadSource: 'system',
    },
  );

  return {
    ok: true,
    count,
    file: {
      docType: TRANSIT_ARCHIVE_PHOTOS_ZIP_DOC_TYPE,
      fileName: saved.fileName,
      mimeType: saved.mimeType,
      fileUrl: saved.fileUrl,
    },
  };
}

module.exports = {
  TRANSIT_ARCHIVE_PHOTOS_ZIP_DOC_TYPE,
  isTransitArchivePhotoDocType,
  changedIncludesTransitArchivePhotos,
  buildTransitArchivePhotosZipBuffer,
  rebuildAndStoreTransitArchivePhotosZip,
  loadTransitArchivePhotoRows,
};
