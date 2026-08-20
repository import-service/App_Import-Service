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

const RECENT_ACTIVITY_DAYS = 30;
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

function assertArchiveBefore(archiveBefore) {
  const date = parseDateOnly(archiveBefore);
  if (!date) {
    const e = new Error('VALIDATION_ERROR');
    e.code = 'VALIDATION_ERROR';
    e.messageRu = 'Нужна дата archiveBefore (YYYY-MM-DD)';
    throw e;
  }
  return date;
}

function formatLabelDate(value) {
  const d = value instanceof Date ? value : new Date(value);
  if (Number.isNaN(d.getTime())) return '00_00_00';
  const day = String(d.getUTCDate()).padStart(2, '0');
  const month = String(d.getUTCMonth() + 1).padStart(2, '0');
  const year = String(d.getUTCFullYear()).slice(-2);
  return `${day}_${month}_${year}`;
}

function buildZipFileName(minCreatedAt, maxClosedAt) {
  const from = formatLabelDate(minCreatedAt);
  const to = formatLabelDate(maxClosedAt);
  return `${from}-to-${to}.zip`;
}

/** Закрытые заявки, созданные до archiveBefore, без активности за RECENT_ACTIVITY_DAYS. */
async function listRequestsEligibleForArchive(pool, archiveBefore) {
  const before = assertArchiveBefore(archiveBefore);
  const [rows] = await pool.query(
    `SELECT r.id, r.vin, r.car_make, r.car_model, r.owner_full_name,
            r.organization_id, r.status, r.created_at, r.updated_at, r.archived_at,
            o.company_name AS organization_name
     FROM customs_requests r
     INNER JOIN organizations o
       ON o.id = r.organization_id AND o.deleted_at IS NULL
     WHERE r.deleted_at IS NULL
       AND r.archive_purged_at IS NULL
       AND r.status = 'closed'
       AND r.created_at < DATE_ADD(?, INTERVAL 1 DAY)
       AND r.updated_at < DATE_SUB(NOW(3), INTERVAL ? DAY)
       AND NOT EXISTS (
         SELECT 1 FROM customs_request_messages m
         WHERE m.request_id = r.id AND m.deleted_at IS NULL
           AND m.created_at >= DATE_SUB(NOW(3), INTERVAL ? DAY)
       )
       AND NOT EXISTS (
         SELECT 1 FROM customs_request_files f
         WHERE f.request_id = r.id AND f.deleted_at IS NULL
           AND (
             f.created_at >= DATE_SUB(NOW(3), INTERVAL ? DAY)
             OR f.updated_at >= DATE_SUB(NOW(3), INTERVAL ? DAY)
           )
       )
       AND NOT EXISTS (
         SELECT 1 FROM user_sessions us
         WHERE us.user_id = r.organization_id
           AND us.created_at >= DATE_SUB(NOW(3), INTERVAL ? DAY)
       )
     ORDER BY r.organization_id ASC, r.id ASC`,
    [
      before,
      RECENT_ACTIVITY_DAYS,
      RECENT_ACTIVITY_DAYS,
      RECENT_ACTIVITY_DAYS,
      RECENT_ACTIVITY_DAYS,
      RECENT_ACTIVITY_DAYS,
    ],
  );
  return rows.map((row) => ({
    id: Number(row.id),
    vin: row.vin || '',
    carMake: row.car_make || '',
    carModel: row.car_model || '',
    ownerFullName: row.owner_full_name || '',
    organizationId: Number(row.organization_id) || null,
    organizationName: row.organization_name || '',
    status: row.status,
    createdAt: toIso(row.created_at),
    updatedAt: toIso(row.updated_at),
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

async function packOrgChat(zip, pool, organizationId) {
  const orgId = Number(organizationId);
  if (!orgId) return { messages: 0 };
  const folder = `organizations/${orgId}`;
  let msgRows = [];
  try {
    const [m] = await pool.query(
      `SELECT * FROM organization_messages
       WHERE organization_id = ? AND deleted_at IS NULL
       ORDER BY id ASC`,
      [orgId],
    );
    msgRows = m;
  } catch (e) {
    if (e.code !== 'ER_NO_SUCH_TABLE') throw e;
    return { messages: 0 };
  }

  zip.file(`${folder}/messages.json`, JSON.stringify(msgRows.map(rowToPlain), null, 2));

  const chatNames = new Set();
  for (const m of msgRows) {
    for (const name of collectOrgChatStoredNamesFromJson(m.attachments_json)) {
      chatNames.add(name);
    }
  }
  try {
    const entries = await fs.readdir(CHAT_UPLOAD_ROOT);
    const prefix = `o${orgId}_`;
    for (const name of entries) {
      if (name.startsWith(prefix)) chatNames.add(name);
    }
  } catch (e) {
    if (e.code !== 'ENOENT') throw e;
  }
  for (const name of chatNames) {
    const disk = chatAttachmentDiskPath(name);
    if (!disk) continue;
    await addDiskFileToZip(zip, `${folder}/org-chat-files/${name}`, disk);
  }
  return { messages: msgRows.length };
}

function collectOrgChatStoredNamesFromJson(value) {
  const names = collectChatStoredNamesFromJson(value);
  return names.filter((n) => /^o\d+_/i.test(n));
}

async function purgeOneRequestAfterArchive(pool, requestId, uploadRoot) {
  const id = Number(requestId);
  const [fileRows] = await pool.query(
    `SELECT id, stored_name, preview_stored_name
     FROM customs_request_files
     WHERE request_id = ? AND deleted_at IS NULL`,
    [id],
  );
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
  return {
    filesRemoved: fileRows.length,
    chatFilesRemoved: chat.chatFilesRemoved || 0,
    chatMessagesSoftDeleted: chat.chatMessagesSoftDeleted || 0,
  };
}

async function buildArchiveZip(pool, {
  archiveBefore,
  archivedByName,
  archiveLocation,
  adminUserId,
  adminLogin,
  uploadRoot = DEFAULT_UPLOAD_ROOT,
  purgeFromServer = true,
}) {
  const before = assertArchiveBefore(archiveBefore);
  const name = String(archivedByName || '').trim();
  if (!name) {
    const e = new Error('VALIDATION_ERROR');
    e.code = 'VALIDATION_ERROR';
    e.messageRu = 'Нужно ФИО (archivedByName)';
    throw e;
  }

  const items = await listRequestsEligibleForArchive(pool, before);
  if (!items.length) {
    const e = new Error('NOT_FOUND');
    e.code = 'NOT_FOUND';
    e.messageRu = 'Нет подходящих закрытых заявок для архива';
    throw e;
  }

  const minCreated = items.reduce(
    (min, x) => (min == null || new Date(x.createdAt) < new Date(min) ? x.createdAt : min),
    null,
  );
  const maxClosed = items.reduce(
    (max, x) => (max == null || new Date(x.updatedAt) > new Date(max) ? x.updatedAt : max),
    null,
  );

  const zipFileName = buildZipFileName(minCreated, maxClosed);
  const periodLabel = zipFileName.replace(/\.zip$/i, '');
  const locRaw = String(archiveLocation || '').trim();
  const loc = locRaw || zipFileName;
  const archivedAt = new Date().toISOString();
  const ids = items.map((x) => x.id);
  const orgIds = [...new Set(items.map((x) => x.organizationId).filter(Boolean))];

  const orgChats = [];
  for (const orgId of orgIds) {
    const item = items.find((x) => x.organizationId === orgId);
    orgChats.push({
      organizationId: orgId,
      organizationName: item?.organizationName || `Org #${orgId}`,
    });
  }

  const manifest = {
    version: 2,
    kind: KIND,
    archiveBefore: before,
    periodLabel,
    periodFrom: minCreated ? String(minCreated).slice(0, 10) : before,
    periodTo: maxClosed ? String(maxClosed).slice(0, 10) : before,
    archivedByName: name,
    archiveLocation: loc,
    archivedAt,
    adminLogin: adminLogin || null,
    orgChats,
    requests: items,
  };

  const zip = new JSZip();
  zip.file('manifest.json', JSON.stringify(manifest, null, 2));

  for (const item of items) {
    await packRequest(zip, pool, item.id, uploadRoot);
  }
  for (const orgId of orgIds) {
    const packed = await packOrgChat(zip, pool, orgId);
    const entry = orgChats.find((o) => o.organizationId === orgId);
    if (entry) entry.messageCount = packed.messages;
  }

  const [ins] = await pool.query(
    `INSERT INTO request_archives
      (period_from, period_to, archived_by_name, archive_location,
       admin_user_id, admin_login, request_ids_json, request_count, zip_file_name)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
    [
      manifest.periodFrom,
      manifest.periodTo,
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

  let purged = 0;
  let filesRemoved = 0;
  if (purgeFromServer) {
    for (const id of ids) {
      const r = await purgeOneRequestAfterArchive(pool, id, uploadRoot);
      purged += 1;
      filesRemoved += r.filesRemoved || 0;
    }
  }

  const buffer = await zip.generateAsync({
    type: 'nodebuffer',
    compression: 'DEFLATE',
    compressionOptions: { level: 6 },
  });

  return {
    buffer,
    zipFileName,
    archiveId,
    requestCount: ids.length,
    orgCount: orgIds.length,
    purged,
    filesRemoved,
    manifest,
  };
}

/** @deprecated используйте buildArchiveZip */
async function buildExportZip(pool, opts) {
  if (opts.archiveBefore) {
    return buildArchiveZip(pool, opts);
  }
  return buildArchiveZip(pool, {
    ...opts,
    archiveBefore: opts.periodTo || opts.periodFrom,
  });
}

/** @deprecated используйте listRequestsEligibleForArchive */
async function listRequestsInPeriod(pool, periodFrom, periodTo) {
  return listRequestsEligibleForArchive(pool, periodTo || periodFrom);
}

function groupManifestOrganizations(manifest) {
  const orgMap = new Map();
  const orgChatMeta = new Map(
    (manifest.orgChats || []).map((o) => [Number(o.organizationId), o]),
  );
  for (const r of manifest.requests || []) {
    const oid = Number(r.organizationId);
    if (!oid) continue;
    if (!orgMap.has(oid)) {
      const chatMeta = orgChatMeta.get(oid);
      orgMap.set(oid, {
        organizationId: oid,
        organizationName: r.organizationName || chatMeta?.organizationName || `Org #${oid}`,
        orgChat: {
          available: Boolean(chatMeta || manifest.version >= 2),
          messageCount: Number(chatMeta?.messageCount) || 0,
        },
        requests: [],
      });
    }
    orgMap.get(oid).requests.push(r);
  }
  return [...orgMap.values()];
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
    periodLabel: row.zip_file_name
      ? String(row.zip_file_name).replace(/\.zip$/i, '')
      : null,
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
  const organizations = groupManifestOrganizations(manifest);
  return {
    periodLabel: manifest.periodLabel || null,
    periodFrom: manifest.periodFrom,
    periodTo: manifest.periodTo,
    archiveBefore: manifest.archiveBefore || null,
    archivedByName: manifest.archivedByName,
    archiveLocation: manifest.archiveLocation,
    archivedAt: manifest.archivedAt,
    organizations,
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
       archived_at = NULL,
       archive_id = NULL,
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

async function restoreOrgChat(pool, zip, organizationId) {
  const orgId = Number(organizationId);
  if (!orgId) return { organizationId: orgId, ok: false, error: 'NO_ORG' };
  const folder = `organizations/${orgId}`;
  const msgEntry = zip.file(`${folder}/messages.json`);
  if (!msgEntry) {
    return { organizationId: orgId, ok: false, error: 'NO_ORG_CHAT' };
  }

  const [orgRows] = await pool.query(
    `SELECT id FROM organizations WHERE id = ? AND deleted_at IS NULL LIMIT 1`,
    [orgId],
  );
  if (!orgRows.length) {
    return { organizationId: orgId, ok: false, error: 'ORGANIZATION_MISSING' };
  }

  const chatFolder = zip.folder(`${folder}/org-chat-files`);
  if (chatFolder) {
    const tasks = [];
    chatFolder.forEach((rel) => {
      const base = path.basename(String(rel || ''));
      if (!base || !/^o\d+_[\w.-]+$/i.test(base)) return;
      const dest = chatAttachmentDiskPath(base);
      if (!dest) return;
      tasks.push(writeZipFileToDisk(zip, `${folder}/org-chat-files/${rel}`, dest));
    });
    await Promise.all(tasks);
  }

  const messages = JSON.parse(await msgEntry.async('string')) || [];
  let restored = 0;
  for (const m of messages) {
    const cid = m.client_message_id || null;
    const mid = m.message_1c_id || null;
    if (cid) {
      const [ex] = await pool.query(
        `SELECT id FROM organization_messages WHERE client_message_id = ? LIMIT 1`,
        [cid],
      );
      if (ex.length) {
        await pool.query(
          `UPDATE organization_messages SET deleted_at = NULL WHERE id = ?`,
          [ex[0].id],
        );
        restored += 1;
        continue;
      }
    }
    if (mid) {
      const [ex] = await pool.query(
        `SELECT id FROM organization_messages WHERE message_1c_id = ? LIMIT 1`,
        [mid],
      );
      if (ex.length) {
        await pool.query(
          `UPDATE organization_messages SET deleted_at = NULL WHERE id = ?`,
          [ex[0].id],
        );
        restored += 1;
        continue;
      }
    }
    try {
      await pool.query(
        `INSERT INTO organization_messages
          (organization_id, author_type, user_id, direction, client_message_id, message_1c_id,
           text_content, attachments_json, delivery_status, created_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, COALESCE(?, NOW(3)))`,
        [
          orgId,
          m.author_type || 'manager_1c',
          m.user_id || null,
          m.direction || 'from_1c',
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
      restored += 1;
    } catch (e) {
      if (e.code !== 'ER_DUP_ENTRY') throw e;
    }
  }
  return { organizationId: orgId, ok: true, restored };
}

async function importFromZip(
  pool,
  buffer,
  selectedIds,
  orgChatOrgIds = [],
  uploadRoot = DEFAULT_UPLOAD_ROOT,
) {
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

  const allOrgIds = (manifest.orgChats || [])
    .map((o) => Number(o.organizationId))
    .filter((n) => n > 0);
  const wantOrg = Array.isArray(orgChatOrgIds) && orgChatOrgIds.length
    ? orgChatOrgIds.map(Number).filter((n) => n > 0)
    : [];
  const orgResults = [];
  for (const orgId of wantOrg) {
    if (allOrgIds.length && !allOrgIds.includes(orgId)) {
      orgResults.push({ organizationId: orgId, ok: false, error: 'NOT_IN_ARCHIVE' });
      continue;
    }
    orgResults.push(await restoreOrgChat(pool, zip, orgId));
  }

  return {
    archivedByName: manifest.archivedByName,
    archiveLocation: manifest.archiveLocation,
    periodLabel: manifest.periodLabel || null,
    restored: results.filter((r) => r.ok).length,
    orgChatsRestored: orgResults.filter((r) => r.ok).length,
    results,
    orgChatResults: orgResults,
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
    const r = await purgeOneRequestAfterArchive(pool, id, uploadRoot);
    purged += 1;
    filesRemoved += r.filesRemoved || 0;
    chatFilesRemoved += r.chatFilesRemoved || 0;
    chatMessagesSoftDeleted += r.chatMessagesSoftDeleted || 0;
  }
  return {
    purged,
    filesRemoved,
    chatFilesRemoved,
    chatMessagesSoftDeleted,
    scanned: rows.length,
  };
}

module.exports = {
  RECENT_ACTIVITY_DAYS,
  KIND,
  assertArchiveBefore,
  listRequestsEligibleForArchive,
  listRequestsInPeriod,
  buildArchiveZip,
  buildExportZip,
  listArchives,
  previewZip,
  importFromZip,
  purgeMarkedArchivedRequests,
  groupManifestOrganizations,
};
