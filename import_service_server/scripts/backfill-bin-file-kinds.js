/**
 * One-shot: переименовать .bin / octet-stream по magic bytes (jpeg/png/pdf/…).
 * Запуск на VPS из корня API:
 *   node scripts/backfill-bin-file-kinds.js
 * Dry-run:
 *   node scripts/backfill-bin-file-kinds.js --dry-run
 */
require('dotenv').config();

const fs = require('fs/promises');
const path = require('path');
const mysql = require('mysql2/promise');
const { resolveFileKind } = require('../src/util/fileKindDetect');
const { ensureDisplayFileName } = require('../src/util/displayFileName');
const { generateImagePreviewBuffer, writePreviewFile, unlinkIfExists } = require('../src/util/imagePreview');

const UPLOAD_ROOT = path.join(process.cwd(), 'uploads', 'customs-requests');
const dryRun = process.argv.includes('--dry-run');

function buildPreviewStoredName(storedName) {
  const ext = path.extname(storedName);
  const base = ext ? storedName.slice(0, -ext.length) : storedName;
  if (base.endsWith('_preview')) return `${base}.jpg`;
  return `${base}_preview.jpg`;
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
            mime_type, file_url, preview_url, file_size_bytes
     FROM customs_request_files
     WHERE deleted_at IS NULL
       AND (
         stored_name LIKE '%.bin'
         OR mime_type IS NULL
         OR mime_type = ''
         OR mime_type = 'application/octet-stream'
       )
     ORDER BY id ASC`,
  );

  console.log(`candidates=${rows.length} dryRun=${dryRun}`);
  let fixed = 0;
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

    const kind = resolveFileKind({
      buffer,
      clientFileName: row.original_name || storedName,
      mimeType: row.mime_type,
    });

    if (kind.detectedFrom === 'fallback' || kind.ext === '.bin') {
      console.log(`keep id=${row.id} ${storedName} (${kind.mimeType})`);
      skipped += 1;
      continue;
    }

    const newStored =
      storedName.toLowerCase().endsWith('.bin')
        ? `${storedName.slice(0, -4)}${kind.ext}`
        : storedName.replace(/\.[^.]+$/, kind.ext);
    const newFileUrl = `/api/customs-requests/files/${newStored}`;
    const displayName = ensureDisplayFileName({
      docType: row.doc_type,
      mimeType: kind.mimeType,
      storedName: newStored,
      clientFileName: row.original_name,
    });

    let previewStoredName = row.preview_stored_name || null;
    let previewUrl = row.preview_url || null;
    const previewBuffer = await generateImagePreviewBuffer(
      buffer,
      kind.mimeType,
      row.doc_type,
    );
    if (previewBuffer) {
      previewStoredName = buildPreviewStoredName(newStored);
      previewUrl = `/api/customs-requests/files/${previewStoredName}`;
    }

    console.log(
      `fix id=${row.id} ${storedName} → ${newStored} mime=${kind.mimeType} from=${kind.detectedFrom}` +
        (previewStoredName ? ` preview=${previewStoredName}` : ''),
    );

    if (!dryRun) {
      try {
        if (newStored !== storedName) {
          await fs.rename(filePath, path.join(UPLOAD_ROOT, newStored));
        }
        if (previewBuffer && previewStoredName) {
          if (row.preview_stored_name && row.preview_stored_name !== previewStoredName) {
            await unlinkIfExists(UPLOAD_ROOT, row.preview_stored_name);
          }
          await writePreviewFile(UPLOAD_ROOT, previewStoredName, previewBuffer);
        }
        await pool.query(
          `UPDATE customs_request_files
           SET original_name = ?, stored_name = ?, mime_type = ?,
               file_url = ?, preview_stored_name = ?, preview_url = ?,
               file_size_bytes = ?, updated_at = CURRENT_TIMESTAMP(3)
           WHERE id = ?`,
          [
            displayName,
            newStored,
            kind.mimeType,
            newFileUrl,
            previewStoredName,
            previewUrl,
            buffer.length,
            row.id,
          ],
        );
        fixed += 1;
      } catch (e) {
        failed += 1;
        console.error(`fail id=${row.id}:`, e.message || e);
        // best-effort rollback rename
        if (newStored !== storedName) {
          try {
            await fs.rename(path.join(UPLOAD_ROOT, newStored), filePath);
          } catch {
            /* ignore */
          }
        }
      }
    } else {
      fixed += 1;
    }
  }

  console.log(`done fixed=${fixed} skipped=${skipped} failed=${failed}`);
  await pool.end();
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
