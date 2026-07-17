/**
 * Развернуть существующие .rar/.zip на диске в отдельные файлы X_1..X_N (или X, если внутри один).
 * source_file_name у всех детей = имя архива → админка группирует их в карусель.
 *   node scripts/backfill-extract-archives.js
 *   node scripts/backfill-extract-archives.js --dry-run
 */
require('dotenv').config();

const fs = require('fs/promises');
const path = require('path');
const mysql = require('mysql2/promise');
const { maybeExtractAllFromArchive } = require('../src/util/archiveExtract');
const { resolveFileKind } = require('../src/util/fileKindDetect');
const { ensureDisplayFileName } = require('../src/util/displayFileName');
const {
  buildStoredFileName,
  buildPreviewStoredName,
  buildFileUrl,
} = require('../src/util/requestFileStorage');
const {
  generateImagePreviewBuffer,
  writePreviewFile,
  unlinkIfExists,
} = require('../src/util/imagePreview');

const UPLOAD_ROOT = path.join(process.cwd(), 'uploads', 'customs-requests');
const dryRun = process.argv.includes('--dry-run');

function storageKeyFromStored(storedName) {
  const idx = String(storedName).indexOf('__');
  return idx > 0 ? String(storedName).slice(0, idx) : 'unknown';
}

async function main() {
  const pool = await mysql.createPool({
    host: process.env.MYSQL_HOST || '127.0.0.1',
    port: Number(process.env.MYSQL_PORT || 3306),
    user: process.env.MYSQL_USER,
    password: process.env.MYSQL_PASSWORD,
    database: process.env.MYSQL_DATABASE,
    waitForConnections: true,
    connectionLimit: 4,
  });

  const [rows] = await pool.query(
    `SELECT id, request_id, doc_type, original_name, stored_name, preview_stored_name,
            mime_type, source_file_name, source_mime_type, upload_source
     FROM customs_request_files
     WHERE deleted_at IS NULL
       AND (
         stored_name LIKE '%.rar'
         OR stored_name LIKE '%.zip'
         OR mime_type IN ('application/vnd.rar', 'application/x-rar-compressed', 'application/zip')
       )
     ORDER BY id ASC`,
  );

  console.log(`candidates=${rows.length} dryRun=${dryRun}`);
  let fixed = 0;
  let created = 0;
  let skipped = 0;
  let failed = 0;

  for (const row of rows) {
    const storedName = String(row.stored_name || '');
    const filePath = path.join(UPLOAD_ROOT, storedName);
    let buffer;
    try {
      buffer = await fs.readFile(filePath);
    } catch (e) {
      console.warn(`skip id=${row.id} missing ${storedName}: ${e.code || e.message}`);
      skipped += 1;
      continue;
    }

    let items;
    try {
      items = await maybeExtractAllFromArchive(buffer, { docType: row.doc_type });
    } catch (e) {
      console.warn(`skip id=${row.id} extract error: ${e.message || e}`);
      skipped += 1;
      continue;
    }
    if (!items.length) {
      console.log(`keep id=${row.id} ${storedName} (no image/pdf inside)`);
      skipped += 1;
      continue;
    }

    const storageKey = storageKeyFromStored(storedName);
    const dt = String(row.doc_type);
    const archiveName = row.original_name || row.source_file_name || storedName;
    const single = items.length === 1;

    console.log(
      `explode id=${row.id} ${storedName} → ${items.length} файл(ов) (dt=${dt})`,
    );

    if (dryRun) {
      fixed += 1;
      created += items.length;
      continue;
    }

    try {
      // Удаляем исходный архив (файл + превью) и саму строку.
      await unlinkIfExists(UPLOAD_ROOT, storedName);
      if (row.preview_stored_name) {
        await unlinkIfExists(UPLOAD_ROOT, row.preview_stored_name);
      }
      await pool.query(
        `UPDATE customs_request_files SET deleted_at = CURRENT_TIMESTAMP(3) WHERE id = ?`,
        [row.id],
      );

      for (let i = 0; i < items.length; i += 1) {
        const item = items[i];
        const childDocType = single ? dt : `${dt}_${i + 1}`;
        const kind = resolveFileKind({
          buffer: item.buffer,
          clientFileName: item.fileName,
          mimeType: item.mimeType,
        });
        const childStored = buildStoredFileName(storageKey, childDocType, kind.ext);
        const childUrl = buildFileUrl(childStored);
        const displayName = ensureDisplayFileName({
          docType: childDocType,
          mimeType: kind.mimeType,
          storedName: childStored,
          clientFileName: item.fileName,
        });

        let previewStoredName = null;
        let previewUrl = null;
        // eslint-disable-next-line no-await-in-loop
        const previewBuffer = await generateImagePreviewBuffer(
          item.buffer,
          kind.mimeType,
          childDocType,
        );
        if (previewBuffer) {
          previewStoredName = buildPreviewStoredName(storageKey, childDocType);
          previewUrl = buildFileUrl(previewStoredName);
        }

        // eslint-disable-next-line no-await-in-loop
        await fs.writeFile(path.join(UPLOAD_ROOT, childStored), item.buffer);
        if (previewBuffer && previewStoredName) {
          // eslint-disable-next-line no-await-in-loop
          await writePreviewFile(UPLOAD_ROOT, previewStoredName, previewBuffer);
        }
        // eslint-disable-next-line no-await-in-loop
        await pool.query(
          `INSERT INTO customs_request_files
             (request_id, doc_type, original_name, source_file_name, source_mime_type, upload_source,
              stored_name, preview_stored_name, mime_type, file_size_bytes, file_url, preview_url)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
          [
            row.request_id,
            childDocType,
            displayName,
            archiveName,
            row.source_mime_type || row.mime_type || null,
            row.upload_source || null,
            childStored,
            previewStoredName,
            kind.mimeType,
            item.buffer.length,
            childUrl,
            previewUrl,
          ],
        );
        created += 1;
      }
      fixed += 1;
    } catch (e) {
      failed += 1;
      console.error(`fail id=${row.id}:`, e.message || e);
    }
  }

  console.log(`done archives=${fixed} filesCreated=${created} skipped=${skipped} failed=${failed}`);
  await pool.end();
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
