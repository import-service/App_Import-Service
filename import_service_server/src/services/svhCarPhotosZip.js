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
const SVH_CAR_PHOTOS_ZIP_DOC_TYPE = 'svh_car_photos_zip';

function isSvhCarGalleryDocType(docType) {
  return /^svh_car_photo_\d+$/.test(normalizeDocType(docType));
}

function isSvhCarVideoDocType(docType) {
  const c = normalizeDocType(docType);
  if (!/^svh_car_video_\d+$/.test(c)) return false;
  const n = Number(c.replace(/^svh_car_video_/, ''));
  return Number.isInteger(n) && n >= 1 && n <= 3;
}

function isSvhCarMediaDocType(docType) {
  return isSvhCarGalleryDocType(docType) || isSvhCarVideoDocType(docType);
}

function changedIncludesSvhCarGallery(changedDocTypes) {
  return (changedDocTypes || []).some(isSvhCarMediaDocType);
}

function gallerySortKey(docType) {
  const c = normalizeDocType(docType);
  const photo = /^svh_car_photo_(\d+)$/.exec(c);
  if (photo) return { kind: 0, n: Number(photo[1]) || 0 };
  const video = /^svh_car_video_(\d+)$/.exec(c);
  if (video) return { kind: 1, n: Number(video[1]) || 0 };
  return { kind: 9, n: 0 };
}

async function loadSvhCarMediaRows(pool, requestId) {
  const [rows] = await pool.query(
    `SELECT id, doc_type, original_name, stored_name, mime_type, file_url
     FROM customs_request_files
     WHERE request_id = ? AND deleted_at IS NULL
       AND (
         doc_type REGEXP '^svh_car_photo_[0-9]+$'
         OR doc_type REGEXP '^svh_car_video_[0-9]+$'
       )
     ORDER BY id ASC`,
    [requestId],
  );
  return rows.slice().sort((a, b) => {
    const ka = gallerySortKey(a.doc_type);
    const kb = gallerySortKey(b.doc_type);
    if (ka.kind !== kb.kind) return ka.kind - kb.kind;
    if (ka.n !== kb.n) return ka.n - kb.n;
    return Number(a.id) - Number(b.id);
  });
}

/** @deprecated use loadSvhCarMediaRows */
async function loadSvhCarPhotoRows(pool, requestId) {
  return loadSvhCarMediaRows(pool, requestId);
}

async function buildSvhCarPhotosZipBuffer(pool, requestId) {
  const rows = await loadSvhCarMediaRows(pool, requestId);
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
    const code = normalizeDocType(row.doc_type);
    const prefix = isSvhCarVideoDocType(code) ? 'video' : 'photo';
    const baseName =
      String(row.original_name || '').trim() ||
      `${code}.${isSvhCarVideoDocType(code) ? 'mp4' : 'jpg'}`;
    const safeName = baseName.replace(/[\\/:*?"<>|]/g, '_');
    zip.file(`${prefix}_${String(added + 1).padStart(2, '0')}_${safeName}`, buf);
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
 * Пересобрать ZIP галереи СВХ (фото + видео), сохранить как svh_car_photos_zip.
 */
async function rebuildAndStoreSvhCarPhotosZip(fastify, requestId) {
  const [reqRows] = await fastify.pool.query(
    `SELECT id, external_1c_id FROM customs_requests
     WHERE id = ? AND deleted_at IS NULL LIMIT 1`,
    [requestId],
  );
  const req = reqRows[0];
  if (!req) {
    return { ok: false, error: 'NOT_FOUND' };
  }

  const { buffer, count } = await buildSvhCarPhotosZipBuffer(fastify.pool, requestId);
  if (!buffer || count < 1) {
    await removeExistingSlotFiles(
      fastify.pool,
      UPLOAD_ROOT,
      requestId,
      SVH_CAR_PHOTOS_ZIP_DOC_TYPE,
    );
    return { ok: true, count: 0, cleared: true };
  }

  const storageKey = storageKeyForRequest(req);
  await removeExistingSlotFiles(
    fastify.pool,
    UPLOAD_ROOT,
    requestId,
    SVH_CAR_PHOTOS_ZIP_DOC_TYPE,
  );
  const saved = await insertFileRow(
    fastify.pool,
    UPLOAD_ROOT,
    requestId,
    storageKey,
    SVH_CAR_PHOTOS_ZIP_DOC_TYPE,
    buffer,
    'application/zip',
    `svh_car_media_${requestId}.zip`,
    {
      sourceFileName: `svh_car_media_${requestId}.zip`,
      sourceMimeType: 'application/zip',
      uploadSource: 'system',
    },
  );

  return {
    ok: true,
    count,
    file: {
      docType: SVH_CAR_PHOTOS_ZIP_DOC_TYPE,
      fileName: saved.fileName,
      mimeType: saved.mimeType,
      fileUrl: saved.fileUrl,
    },
  };
}

module.exports = {
  SVH_CAR_PHOTOS_ZIP_DOC_TYPE,
  isSvhCarGalleryDocType,
  isSvhCarVideoDocType,
  isSvhCarMediaDocType,
  changedIncludesSvhCarGallery,
  buildSvhCarPhotosZipBuffer,
  rebuildAndStoreSvhCarPhotosZip,
  loadSvhCarPhotoRows,
  loadSvhCarMediaRows,
};
