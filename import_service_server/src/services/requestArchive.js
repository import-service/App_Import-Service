const fs = require('fs/promises');
const path = require('path');
const JSZip = require('jszip');
const {
  CUSTOMS_REQUEST_FILE_SELECT,
} = require('../util/requestFileStorage');
const {
  CHAT_UPLOAD_ROOT,
  chatAttachmentDiskPath,
} = require('./chatAttachmentStorage');
const {
  deleteChatForRequest,
  deleteFilesFromDisk,
  collectChatStoredNamesFromJson,
  DEFAULT_UPLOAD_ROOT,
} = require('./requestDeletion');

const MAX_PERIOD_DAYS = 93;
const KIND = 'request-archive';

function toIso(value) {
  if (!value) return null;
  try {
    return new Date(value).toISOString();
  } catch {
    return null;
  }
}

function rowToPlain(row) {
  const o = {};
  for (const [k, v] of Object.entries(row || {})) {
    if (v instanceof Date) o[k] = v.toISOString();
    else if (Buffer.isBuffer(v)) o[k] = v.toString('utf8');
    else o[k] = v;
  }
  return o;
}

function parseDateOnly(raw) {
  const s = String(raw || '').trim();
  if (!/^\d{4}-\d{2}-\d{2}$/.test(s)) return null;
  const d = new Date(`${s}T00:00:00.000Z`);
  if (Number.isNaN(d.getTime())) return null;
  return s;
}

function assertPeriod(periodFrom, periodTo) {
  const from = parseDateOnly(periodFrom);
  const to = parseDateOnly(periodTo);
  if (!from || !to) {
    const e = new Error('VALIDATION_ERROR');
    e.code = 'VALIDATION_ERROR';
    e.messageRu = 'Нужны даты periodFrom и periodTo (YYYY-MM-DD)';
    throw e;
  }
  const fromMs = Date.parse(`${from}T00:00:00.000Z`);
  const toMs = Date.parse(`${to}T00:00:00.000Z`);
  if (toMs < fromMs) {
    const e = new Error('VALIDATION_ERROR');
    e.code = 'VALIDATION_ERROR';
    e.messageRu = 'periodTo раньше periodFrom';
    throw e;
  }
  const days = Math.round((toMs - fromMs) / 86400000) + 1;
  if (days > MAX_PERIOD_DAYS) {
    const e = new Error('VALIDATION_ERROR');
    e.code = 'VALIDATION_ERROR';
    e.messageRu = 'Период не больше 3 месяцев';
    throw e;
  }
  return { from, to };
}

async function listRequestsInPeriod(pool, periodFrom, periodTo) {
  const { from, to } = assertPeriod(periodFrom, periodTo);
  const [rows] = await pool.query(
    `SELECT DISTINCT r.id, r.vin, r.car_make, r.car_model, r.owner_full_name,
            r.organization_id, r.status, r.archived_at, r.archive_purged_at
     FROM customs_requests r
     LEFT JOIN customs_request_messages m
       ON m.request_id = r.id AND m.deleted_at IS NULL
     WHERE r.deleted_at IS NULL
       AND r.archive_purged_at IS NULL
       AND (
         (r.created_at >= ? AND r.created_at < DATE_ADD(?, INTERVAL 1 DAY))
         OR (r.updated_at >= ? AND r.updated_at < DATE_ADD(?, INTERVAL 1 DAY))
         OR (m.created_at >= ? AND m.created_at < DATE_ADD(?, INTERVAL 1 DAY))
       )
     ORDER BY r.id ASC`,
    [from, to, from, to, from, to],
  );
  return rows.map((row) => ({
    id: Number(row.id),
    vin: row.vin || '',
    carMake: row.car_make || '',
    carModel: row.car_model || '',
    ownerFullName: row.owner_full_name || '',
    organizationId: Number(row.organization_id) || null,
    status: row.status,
    alreadyArchived: Boolean(row.archived_at),
  }));
}

async function addDiskFileToZip(zip, zipPath, diskPath) {
  try {
    const buf = await fs.readFile(diskPath);
    zip.file(zipPath, buf);
    return true;
  } catch (e) {
    if (e && e.code === 'ENOENT') return false;
    throw e;
  }
}

async function packRequest(zip, pool, requestId, uploadRoot) {
  const id = Number(requestId);
  const folder = `requests/${id}`;
  const [reqRows] = await pool.query(
    `SELECT * FROM customs_requests WHERE id = ? LIMIT 1`,
    [id],
  );
  if (!reqRows.length) return { files: 0, messages: 0 };

  const [fileRows] = await pool.query(
    `SELECT ${CUSTOMS_REQUEST_FILE_SELECT}
     FROM customs_request_files
     WHERE request_id = ? AND deleted_at IS NULL
     ORDER BY id ASC`,
    [id],
  );
  let msgRows = [];
  try {
    const [m] = await pool.query(
      `SELECT * FROM customs_request_messages
       WHERE request_id = ? AND deleted_at IS NULL
       ORDER BY id ASC`,
      [id],
    );
    msgRows = m;
  } catch (e) {
    if (e.code !== 'ER_NO_SUCH_TABLE') throw e;
  }

  zip.file(`${folder}/meta.json`, JSON.stringify(rowToPlain(reqRows[0]), null, 2));
  zip.file(`${folder}/files.json`, JSON.stringify(fileRows.map(rowToPlain), null, 2));
  zip.file(`${folder}/messages.json`, JSON.stringify(msgRows.map(rowToPlain), null, 2));

  let filesPacked = 0;
  for (const f of fileRows) {
    if (f.stored_name) {
      const ok = await addDiskFileToZip(
        zip,
        `${folder}/files/${f.stored_name}`,
        path.join(uploadRoot, f.stored_name),
      );
      if (ok) filesPacked += 1;
    }
    if (f.preview_stored_name) {
      await addDiskFileToZip(
        zip,
        `${folder}/files/${f.preview_stored_name}`,
        path.join(uploadRoot, f.preview_stored_name),
      );
    }
  }

  const chatNames = new Set();
  for (const m of msgRows) {
    for (const name of collectChatStoredNamesFromJson(m.attachments_json)) {
      chatNames.add(name);
    }
  }
  try {
    const entries = await fs.readdir(CHAT_UPLOAD_ROOT);
    const prefix = `r${id}_`;
    for (const name of entries) {
      if (name.startsWith(prefix)) chatNames.add(name);
    }
  } catch (e) {
    if (e.code !== 'ENOENT') throw e;
  }
  for (const name of chatNames) {
    const disk = chatAttachmentDiskPath(name);
    if (!disk) continue;
    await addDiskFileToZip(zip, `${folder}/chat-files/${name}`, disk);
  }

  return { files: filesPacked, messages: msgRows.length };
}

async function buildExportZip(pool, {
  periodFrom,
  periodTo,
  archivedByName,
  archiveLocation,
  adminUserId,
  adminLogin,
  uploadRoot = DEFAULT_UPLOAD_ROOT,
}) {
  const name = String(archivedByName || '').trim();
  if (!name) {
    const e = new Error('VALIDATION_ERROR');
    e.code = 'VALIDATION_ERROR';
    e.messageRu = 'Нужно ФИО (archivedByName)';
    throw e;
  }
  const { from, to } = assertPeriod(periodFrom, periodTo);
  const items = await listRequestsInPeriod(pool, from, to);
  if (!items.length) {
    const e = new Error('NOT_FOUND');
    e.code = 'NOT_FOUND';
    e.messageRu = 'За период нет заявок для архива';
    throw e;
  }

  const zip = new JSZip();
  const archivedAt = new Date().toISOString();
  const ids = items.map((x) => x.id);
  const zipFileName = `request-archive_${from}_${to}.zip`;
  const locRaw = String(archiveLocation || '').trim();
  const loc = locRaw || zipFileName;
  const manifest = {
    version: 1,
    kind: KIND,
    periodFrom: from,
    periodTo: to,
    archivedByName: name,
    archiveLocation: loc,
    archivedAt,
    adminLogin: adminLogin || null,
    requests: items,
  };
  zip.file('manifest.json', JSON.stringify(manifest, null, 2));

  for (const item of items) {
    await packRequest(zip, pool, item.id, uploadRoot);
  }

  const [ins] = await pool.query(
    `INSERT INTO request_archives
      (period_from, period_to, archived_by_name, archive_location,
       admin_user_id, admin_login, request_ids_json, request_count, zip_file_name)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
    [
      from,
      to,
      name,
      loc,
      adminUserId || null,
      adminLogin || null,
      JSON.stringify(ids),
      ids.length,
      zipFileName,
    ],
  );
  const archiveId = ins.insertId;

  await pool.query(
    `UPDATE customs_requests
     SET archived_at = NOW(3),
         archive_id = ?,
         archived_by_name = ?,
         archive_location = ?
     WHERE id IN (${ids.map(() => '?').join(',')})
       AND deleted_at IS NULL`,
    [archiveId, name, loc, ...ids],
  );

  const buffer = await zip.generateAsync({
    type: 'nodebuffer',
    compression: 'DEFLATE',
    compressionOptions: { level: 6 },
  });
  return { buffer, zipFileName, archiveId, requestCount: ids.length, manifest };
}

async function listArchives(pool, limit = 50) {
  const take = Math.min(Math.max(Number(limit) || 50, 1), 200);
  const [rows] = await pool.query(
    `SELECT id, period_from, period_to, archived_by_name, archive_location,
            admin_login, request_ids_json, request_count, zip_file_name, created_at
     FROM request_archives
     ORDER BY id DESC
     LIMIT ?`,
    [take],
  );
  return rows.map((row) => ({
    id: Number(row.id),
    periodFrom: row.period_from,
    periodTo: row.period_to,
    archivedByName: row.archived_by_name,
    archiveLocation: row.archive_location,
    adminLogin: row.admin_login,
    requestIds: Array.isArray(row.request_ids_json)
      ? row.request_ids_json
      : (() => {
        try { return JSON.parse(row.request_ids_json || '[]'); } catch { return []; }
      })(),
    requestCount: Number(row.request_count) || 0,
    zipFileName: row.zip_file_name,
    createdAt: toIso(row.created_at),
  }));
}

function parseManifest(zip) {
  const file = zip.file('manifest.json');
  if (!file) {
    const e = new Error('VALIDATION_ERROR');
    e.code = 'VALIDATION_ERROR';
    e.messageRu = 'В ZIP нет manifest.json';
    throw e;
  }
  return file.async('string').then((raw) => {
    let parsed;
    try {
      parsed = JSON.parse(raw);
    } catch {
      const e = new Error('VALIDATION_ERROR');
      e.code = 'VALIDATION_ERROR';
      e.messageRu = 'Некорректный manifest.json';
      throw e;
    }
    if (parsed.kind !== KIND) {
      const e = new Error('VALIDATION_ERROR');
      e.code = 'VALIDATION_ERROR';
      e.messageRu = 'Это не архив заявок Import Service';
      throw e;
    }
    return parsed;
  });
}

async function previewZip(buffer) {
  const zip = await JSZip.loadAsync(buffer);
  const manifest = await parseManifest(zip);
  return {
    periodFrom: manifest.periodFrom,
    periodTo: manifest.periodTo,
    archivedByName: manifest.archivedByName,
    archiveLocation: manifest.archiveLocation,
    archivedAt: manifest.archivedAt,
    requests: Array.isArray(manifest.requests) ? manifest.requests : [],
  };
}

async function writeZipFileToDisk(zip, zipPath, destAbs) {
  const entry = zip.file(zipPath);
  if (!entry) return false;
  const buf = await entry.async('nodebuffer');
  await fs.mkdir(path.dirname(destAbs), { recursive: true });
  await fs.writeFile(destAbs, buf);
  return true;
}

async function restoreOneRequest(pool, zip, requestId, uploadRoot) {
  const id = Number(requestId);
  const folder = `requests/${id}`;
  const metaFile = zip.file(`${folder}/meta.json`);
  if (!metaFile) {
    return { id, ok: false, error: 'NO_META' };
  }
  const meta = JSON.parse(await metaFile.async('string'));
  const orgId = Number(meta.organization_id);
  if (!orgId) {
    return { id, ok: false, error: 'NO_ORGANIZATION' };
  }
  const [orgRows] = await pool.query(
    `SELECT id FROM organizations WHERE id = ? AND deleted_at IS NULL LIMIT 1`,
    [orgId],
  );
  if (!orgRows.length) {
    return { id, ok: false, error: 'ORGANIZATION_MISSING' };
  }

  const [existing] = await pool.query(
    `SELECT id FROM customs_requests WHERE id = ? LIMIT 1`,
    [id],
  );

  if (!existing.length) {
    await pool.query(
      `INSERT INTO customs_requests (id, organization_id,
        legal_entity_name, legal_email, legal_phone, legal_inn,
        individual_full_name, individual_phone, individual_snils,
        car_make, car_model, vin, status, created_at, updated_at, deleted_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, COALESCE(?, NOW(3)), NOW(3), NULL)`,
      [
        id,
        orgId,
        meta.legal_entity_name || '—',
        meta.legal_email || 'archive@local',
        meta.legal_phone || '—',
        meta.legal_inn || '',
        meta.individual_full_name || '—',
        meta.individual_phone || '—',
        meta.individual_snils || '—',
        meta.car_make || '',
        meta.car_model || '',
        meta.vin || '',
        meta.status || 'closed',
        meta.created_at || null,
      ],
    );
  }

  await pool.query(
    `UPDATE customs_requests SET
       deleted_at = NULL,
       archive_purged_at = NULL,
       owner_full_name = COALESCE(?, owner_full_name),
       car_make = COALESCE(?, car_make),
       car_model = COALESCE(?, car_model),
       vin = COALESCE(?, vin),
       legal_entity_name = COALESCE(?, legal_entity_name),
       legal_email = COALESCE(?, legal_email),
       legal_phone = COALESCE(?, legal_phone),
       individual_full_name = COALESCE(?, individual_full_name),
       individual_phone = COALESCE(?, individual_phone),
       individual_snils = COALESCE(?, individual_snils),
       comment_text = COALESCE(?, comment_text),
       manager_full_name = COALESCE(?, manager_full_name),
       external_1c_id = COALESCE(external_1c_id, ?),
       updated_at = NOW(3)
     WHERE id = ?`,
    [
      meta.owner_full_name || null,
      meta.car_make || null,
      meta.car_model || null,
      meta.vin || null,
      meta.legal_entity_name || null,
      meta.legal_email || null,
      meta.legal_phone || null,
      meta.individual_full_name || null,
      meta.individual_phone || null,
      meta.individual_snils || null,
      meta.comment_text || null,
      meta.manager_full_name || null,
      meta.external_1c_id || null,
      id,
    ],
  );

  let filesJson = [];
  const filesEntry = zip.file(`${folder}/files.json`);
  if (filesEntry) {
    filesJson = JSON.parse(await filesEntry.async('string')) || [];
  }
  for (const f of filesJson) {
    const stored = String(f.stored_name || '').trim();
    if (!stored) continue;
    await writeZipFileToDisk(zip, `${folder}/files/${stored}`, path.join(uploadRoot, stored));
    if (f.preview_stored_name) {
      await writeZipFileToDisk(
        zip,
        `${folder}/files/${f.preview_stored_name}`,
        path.join(uploadRoot, f.preview_stored_name),
      );
    }
    const [have] = await pool.query(
      `SELECT id FROM customs_request_files WHERE request_id = ? AND stored_name = ? LIMIT 1`,
      [id, stored],
    );
    if (have.length) {
      await pool.query(
        `UPDATE customs_request_files SET deleted_at = NULL, updated_at = NOW(3)
         WHERE id = ?`,
        [have[0].id],
      );
    } else {
      await pool.query(
        `INSERT INTO customs_request_files
          (request_id, doc_type, original_name, stored_name, preview_stored_name,
           mime_type, file_size_bytes, file_url, preview_url,
           source_file_name, source_mime_type, upload_source)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        [
          id,
          f.doc_type || 'uploaded_file',
          f.original_name || stored,
          stored,
          f.preview_stored_name || null,
          f.mime_type || 'application/octet-stream',
          Number(f.file_size_bytes) || 0,
          f.file_url || `/api/customs-requests/files/${stored}`,
          f.preview_url || null,
          f.source_file_name || null,
          f.source_mime_type || null,
          f.upload_source || 'archive-import',
        ],
      );
    }
  }

  const chatFolder = zip.folder(`${folder}/chat-files`);
  if (chatFolder) {
    const tasks = [];
    chatFolder.forEach((rel) => {
      const base = path.basename(String(rel || ''));
      if (!base || !/^r\d+_[\w.-]+$/i.test(base)) return;
      const dest = chatAttachmentDiskPath(base);
      if (!dest) return;
      tasks.push(writeZipFileToDisk(zip, `${folder}/chat-files/${rel}`, dest));
    });
    await Promise.all(tasks);
  }

  let messages = [];
  const msgEntry = zip.file(`${folder}/messages.json`);
  if (msgEntry) {
    messages = JSON.parse(await msgEntry.async('string')) || [];
  }
  for (const m of messages) {
    const cid = m.client_message_id || null;
    const mid = m.message_1c_id || null;
    if (cid) {
      const [ex] = await pool.query(
        `SELECT id FROM customs_request_messages WHERE client_message_id = ? LIMIT 1`,
        [cid],
      );
      if (ex.length) {
        await pool.query(
          `UPDATE customs_request_messages SET deleted_at = NULL WHERE id = ?`,
          [ex[0].id],
        );
        continue;
      }
    }
    if (mid) {
      const [ex] = await pool.query(
        `SELECT id FROM customs_request_messages WHERE message_1c_id = ? LIMIT 1`,
        [mid],
      );
      if (ex.length) {
        await pool.query(
          `UPDATE customs_request_messages SET deleted_at = NULL WHERE id = ?`,
          [ex[0].id],
        );
        continue;
      }
    }
    try {
      await pool.query(
        `INSERT INTO customs_request_messages
          (request_id, author_type, user_id, direction, client_message_id, message_1c_id,
           text_content, attachments_json, delivery_status, created_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, COALESCE(?, NOW(3)))`,
        [
          id,
          m.author_type || 'app_user',
          m.user_id || null,
          m.direction || 'to_1c',
          cid,
          mid,
          m.text_content || '',
          typeof m.attachments_json === 'string'
            ? m.attachments_json
            : (m.attachments_json ? JSON.stringify(m.attachments_json) : null),
          m.delivery_status || null,
          m.created_at || null,
        ],
      );
    } catch (e) {
      if (e.code !== 'ER_DUP_ENTRY') throw e;
    }
  }

  return { id, ok: true };
}

async function importFromZip(pool, buffer, selectedIds, uploadRoot = DEFAULT_UPLOAD_ROOT) {
  const zip = await JSZip.loadAsync(buffer);
  const manifest = await parseManifest(zip);
  const allIds = (manifest.requests || []).map((r) => Number(r.id)).filter((n) => n > 0);
  const want = Array.isArray(selectedIds) && selectedIds.length
    ? selectedIds.map(Number).filter((n) => n > 0)
    : allIds;
  const allowed = new Set(allIds);
  const results = [];
  for (const id of want) {
    if (!allowed.has(id)) {
      results.push({ id, ok: false, error: 'NOT_IN_ARCHIVE' });
      continue;
    }
    results.push(await restoreOneRequest(pool, zip, id, uploadRoot));
  }
  return {
    archivedByName: manifest.archivedByName,
    archiveLocation: manifest.archiveLocation,
    restored: results.filter((r) => r.ok).length,
    results,
  };
}

async function purgeMarkedArchivedRequests(pool, uploadRoot = DEFAULT_UPLOAD_ROOT) {
  const [rows] = await pool.query(
    `SELECT id FROM customs_requests
     WHERE deleted_at IS NULL
       AND archived_at IS NOT NULL
       AND archive_purged_at IS NULL
     ORDER BY id ASC
     LIMIT 80`,
  );
  let purged = 0;
  let filesRemoved = 0;
  let chatFilesRemoved = 0;
  let chatMessagesSoftDeleted = 0;
  for (const row of rows) {
    const id = Number(row.id);
    const fileRows = await pool.query(
      `SELECT id, stored_name, preview_stored_name
       FROM customs_request_files
       WHERE request_id = ? AND deleted_at IS NULL`,
      [id],
    ).then(([r]) => r);
    await deleteFilesFromDisk(uploadRoot, fileRows);
    const chat = await deleteChatForRequest(pool, id);
    await pool.query(
      `UPDATE customs_request_files
       SET deleted_at = CURRENT_TIMESTAMP(3), updated_at = CURRENT_TIMESTAMP(3)
       WHERE request_id = ? AND deleted_at IS NULL`,
      [id],
    );
    await pool.query(
      `UPDATE customs_requests
       SET archive_purged_at = NOW(3), updated_at = NOW(3)
       WHERE id = ? AND deleted_at IS NULL`,
      [id],
    );
    purged += 1;
    filesRemoved += fileRows.length;
    chatFilesRemoved += chat.chatFilesRemoved || 0;
    chatMessagesSoftDeleted += chat.chatMessagesSoftDeleted || 0;
  }
  return { purged, filesRemoved, chatFilesRemoved, chatMessagesSoftDeleted, scanned: rows.length };
}

module.exports = {
  MAX_PERIOD_DAYS,
  KIND,
  assertPeriod,
  listRequestsInPeriod,
  buildExportZip,
  listArchives,
  previewZip,
  importFromZip,
  purgeMarkedArchivedRequests,
};
