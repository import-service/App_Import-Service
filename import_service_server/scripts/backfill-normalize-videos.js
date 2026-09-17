/**
 * Перекодировать уже лежащие видео заявок в безопасный H.264 Baseline + AAC.
 * На VPS из корня API (нужен ffmpeg/ffprobe в PATH):
 *   node scripts/backfill-normalize-videos.js
 * Dry-run:
 *   node scripts/backfill-normalize-videos.js --dry-run
 * Force все (даже «уже safe»):
 *   node scripts/backfill-normalize-videos.js --force
 */
require('dotenv').config();

const fs = require('fs/promises');
const path = require('path');
const mysql = require('mysql2/promise');
const {
  normalizeVideoBuffer,
  ffprobeJson,
  needsVideoNormalize,
} = require('../src/services/videoNormalize');
const { isVideoDocType } = require('../src/constants/uploadLimits');
const { buildFileUrl } = require('../src/util/requestFileStorage');

const UPLOAD_ROOT = path.join(process.cwd(), 'uploads', 'customs-requests');
const dryRun = process.argv.includes('--dry-run');
const force = process.argv.includes('--force');

async function main() {
  const pool = await mysql.createPool({
    host: process.env.MYSQL_HOST || '127.0.0.1',
    port: Number(process.env.MYSQL_PORT || 3306),
    user: process.env.MYSQL_USER,
    password: process.env.MYSQL_PASSWORD,
    database: process.env.MYSQL_DATABASE,
    waitForConnections: true,
    connectionLimit: 2,
  });

  const [rows] = await pool.query(
    `SELECT id, request_id, doc_type, original_name, stored_name, mime_type, file_size_bytes, file_url
     FROM customs_request_files
     WHERE deleted_at IS NULL
       AND (
         doc_type LIKE 'svh_car_video\\_%'
         OR doc_type = 'transit_archive_video'
         OR doc_type LIKE '%\\_video'
         OR mime_type LIKE 'video/%'
       )
     ORDER BY id ASC`,
  );

  console.log(`candidates=${rows.length} dryRun=${dryRun} force=${force}`);
  let normalized = 0;
  let skipped = 0;
  let failed = 0;

  for (const row of rows) {
    const storedName = String(row.stored_name || '');
    const filePath = path.join(UPLOAD_ROOT, storedName);
    if (!isVideoDocType(row.doc_type) && !String(row.mime_type || '').startsWith('video/')) {
      skipped += 1;
      continue;
    }

    let buffer;
    try {
      buffer = await fs.readFile(filePath);
    } catch (e) {
      console.warn(`missing id=${row.id} ${storedName}: ${e.code || e.message}`);
      skipped += 1;
      continue;
    }

    try {
      if (!force) {
        try {
          const probe = await ffprobeJson(filePath);
          if (!needsVideoNormalize(probe)) {
            console.log(`skip id=${row.id} already_safe ${storedName}`);
            skipped += 1;
            continue;
          }
        } catch (_) {
          // ffprobe fail → попробуем normalize
        }
      }

      if (dryRun) {
        console.log(`would_normalize id=${row.id} ${storedName} bytes=${buffer.length}`);
        normalized += 1;
        continue;
      }

      const result = await normalizeVideoBuffer(buffer, { force: true, log: console });
      if (!result.normalized) {
        console.log(`skip id=${row.id} reason=${result.reason} ${storedName}`);
        skipped += 1;
        continue;
      }

      const base = storedName.replace(/\.[^.]+$/, '');
      const newStored = `${base}.mp4`;
      const newPath = path.join(UPLOAD_ROOT, newStored);
      await fs.writeFile(newPath, result.buffer);
      if (newStored !== storedName) {
        await fs.unlink(filePath).catch(() => {});
      }

      const displayName = String(row.original_name || 'video.mp4').replace(/\.[^.]+$/, '') + '.mp4';
      const fileUrl = buildFileUrl(newStored);
      await pool.query(
        `UPDATE customs_request_files
         SET original_name = ?, stored_name = ?, mime_type = ?, file_size_bytes = ?, file_url = ?,
             updated_at = CURRENT_TIMESTAMP(3)
         WHERE id = ?`,
        [displayName, newStored, 'video/mp4', result.buffer.length, fileUrl, row.id],
      );
      console.log(
        `ok id=${row.id} ${storedName} -> ${newStored} ${buffer.length}=>${result.buffer.length}`,
      );
      normalized += 1;
    } catch (e) {
      console.error(`fail id=${row.id} ${storedName}: ${e.message || e}`);
      failed += 1;
    }
  }

  console.log(JSON.stringify({ normalized, skipped, failed, dryRun, force }));
  await pool.end();
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
