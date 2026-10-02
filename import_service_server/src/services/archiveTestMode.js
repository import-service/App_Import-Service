const crypto = require('crypto');
const fs = require('fs/promises');
const path = require('path');
const bcrypt = require('bcrypt');
const { v4: uuidv4 } = require('uuid');
const {
  deleteCustomsRequestWithFiles,
  deleteOrgChatForOrganization,
  DEFAULT_UPLOAD_ROOT,
} = require('./requestDeletion');
const {
  CHAT_UPLOAD_ROOT,
  chatAttachmentDiskPath,
} = require('./chatAttachmentStorage');

const TEST_ORG_LOGIN_PREFIX = '__archive_test_org_';
const TEST_ORG_ID1C_PREFIX = 'ARCHIVE_TEST_ORG_';

function daysAgo(days) {
  return new Date(Date.now() - days * 24 * 60 * 60 * 1000);
}

function sqlDateTime(d) {
  return d.toISOString().slice(0, 23).replace('T', ' ');
}

async function ensureTestOrg(pool, index, passwordHash) {
  const login = `${TEST_ORG_LOGIN_PREFIX}${index}`;
  const id1c = `${TEST_ORG_ID1C_PREFIX}${index}`;
  const [existing] = await pool.query(
    `SELECT id FROM organizations WHERE login = ? LIMIT 1`,
    [login],
  );
  if (existing.length) {
    const id = Number(existing[0].id);
    await pool.query(
      `UPDATE organizations
       SET deleted_at = NULL,
           company_name = ?,
           id_1c = ?,
           password_hash = ?,
           updated_at = NOW(3)
       WHERE id = ?`,
      [`Архив-тест Org ${index}`, id1c, passwordHash, id],
    );
    return id;
  }
  const [ins] = await pool.query(
    `INSERT INTO organizations
       (id_1c, login, role, password_hash, org_type, company_name, inn, phone)
     VALUES (?, ?, 'user', ?, 'ООО', ?, ?, ?)`,
    [
      id1c,
      login,
      passwordHash,
      `Архив-тест Org ${index}`,
      `770000000${index}`,
      `+7900000000${index}`,
    ],
  );
  return Number(ins.insertId);
}

async function writeTinyFile(absPath, text) {
  await fs.mkdir(path.dirname(absPath), { recursive: true });
  await fs.writeFile(absPath, Buffer.from(text, 'utf8'));
}

async function addRequestFile(pool, uploadRoot, requestId, docType, label, at = null) {
  await fs.mkdir(uploadRoot, { recursive: true });
  await fs.mkdir(CHAT_UPLOAD_ROOT, { recursive: true });
  const stored = `${requestId}_${docType}_${Date.now()}.txt`;
  const abs = path.join(uploadRoot, stored);
  const body = `archive-test ${label} ${requestId} ${docType}\n`;
  await writeTinyFile(abs, body);
  const fileUrl = `/api/customs-requests/files/${stored}`;
  const [ins] = await pool.query(
    `INSERT INTO customs_request_files
       (request_id, doc_type, original_name, stored_name, mime_type,
        file_size_bytes, file_url, upload_source)
     VALUES (?, ?, ?, ?, 'text/plain', ?, ?, 'archive-test')`,
    [requestId, docType, `${docType}.txt`, stored, Buffer.byteLength(body), fileUrl],
  );
  if (at) {
    const ts = sqlDateTime(at);
    await pool.query(
      `UPDATE customs_request_files
       SET created_at = ?, updated_at = ?
       WHERE id = ?`,
      [ts, ts, ins.insertId],
    );
  }
  return stored;
}

async function addRequestChat(pool, requestId, text, createdAt, withAttachment) {
  let attachmentsJson = null;
  if (withAttachment) {
    const name = `r${requestId}_chat_${Date.now()}.txt`;
    const disk = chatAttachmentDiskPath(name);
    if (disk) {
      await writeTinyFile(disk, `chat attach ${requestId}`);
      attachmentsJson = JSON.stringify([
        {
          storedName: name,
          fileUrl: `/api/chat-attachments/${name}`,
          mimeType: 'text/plain',
          fileName: 'note.txt',
        },
      ]);
    }
  }
  await pool.query(
    `INSERT INTO customs_request_messages
       (request_id, author_type, direction, client_message_id, text_content,
        attachments_json, created_at)
     VALUES (?, 'app_user', 'to_1c', ?, ?, ?, ?)`,
    [requestId, uuidv4(), text, attachmentsJson, sqlDateTime(createdAt)],
  );
}

async function addOrgChat(pool, organizationId, text, createdAt, withAttachment) {
  let attachmentsJson = null;
  if (withAttachment) {
    const name = `o${organizationId}_chat_${Date.now()}.txt`;
    const disk = chatAttachmentDiskPath(name);
    if (disk) {
      await writeTinyFile(disk, `org chat attach ${organizationId}`);
      attachmentsJson = JSON.stringify([
        {
          storedName: name,
          fileUrl: `/api/chat-attachments/${name}`,
          mimeType: 'text/plain',
          fileName: 'org-note.txt',
        },
      ]);
    }
  }
  try {
    await pool.query(
      `INSERT INTO organization_messages
         (organization_id, author_type, direction, client_message_id, text_content,
          attachments_json, created_at)
       VALUES (?, 'app_user', 'to_1c', ?, ?, ?, ?)`,
      [organizationId, uuidv4(), text, attachmentsJson, sqlDateTime(createdAt)],
    );
  } catch (e) {
    if (e.code !== 'ER_NO_SUCH_TABLE') throw e;
  }
}

async function addSession(pool, organizationId, createdAt) {
  await pool.query(
    `INSERT INTO user_sessions (user_id, jti, expires_at, created_at)
     VALUES (?, ?, DATE_ADD(NOW(3), INTERVAL 7 DAY), ?)`,
    [organizationId, uuidv4(), sqlDateTime(createdAt)],
  );
}

async function insertTestRequest(pool, {
  organizationId,
  status,
  createdAt,
  updatedAt,
  vinSuffix,
  ownerLabel,
  external1cId,
}) {
  const vin = `TESTVIN${String(vinSuffix).padStart(10, '0')}`.slice(0, 17);
  const [ins] = await pool.query(
    `INSERT INTO customs_requests
       (organization_id, external_1c_id, legal_entity_name, legal_email, legal_phone, legal_inn,
        individual_full_name, individual_phone, individual_snils, individual_inn,
        owner_full_name, car_make, car_model, vin, comment_text, is_test, status,
        created_at, updated_at)
     VALUES (?, ?, ?, 'archive-test@example.com', '+79001112233', '7701234567',
             ?, '+79001112233', '000-000-000 00', '123456789012',
             ?, 'Toyota', 'Camry', ?, ?, 1, ?, ?, ?)`,
    [
      organizationId,
      external1cId || null,
      `Архив-тест ЮЛ ${vinSuffix}`,
      `Архив Тест ${ownerLabel}`,
      `Архив Тест ${ownerLabel}`,
      vin,
      `seed:${ownerLabel}`,
      status,
      sqlDateTime(createdAt),
      sqlDateTime(updatedAt),
    ],
  );
  return Number(ins.insertId);
}

/**
 * Удалить все тестовые заявки архивации и тестовые org.
 */
async function cleanupArchiveTestMode(pool, uploadRoot = DEFAULT_UPLOAD_ROOT) {
  const [reqRows] = await pool.query(
    `SELECT id FROM customs_requests WHERE is_test = 1`,
  );
  let deletedRequests = 0;
  for (const row of reqRows) {
    const r = await deleteCustomsRequestWithFiles(pool, row.id, uploadRoot);
    if (r.ok || r.error === 'NOT_FOUND') {
      // hard-delete leftover soft-deleted test rows so seed stays clean
      await pool.query(`DELETE FROM customs_requests WHERE id = ?`, [row.id]);
      deletedRequests += 1;
    }
  }
  // leftover soft-deleted test requests
  await pool.query(`DELETE FROM customs_requests WHERE is_test = 1`);

  const [orgRows] = await pool.query(
    `SELECT id FROM organizations
     WHERE login LIKE ? OR id_1c LIKE ?`,
    [`${TEST_ORG_LOGIN_PREFIX}%`, `${TEST_ORG_ID1C_PREFIX}%`],
  );
  let deletedOrgs = 0;
  for (const row of orgRows) {
    const orgId = Number(row.id);
    await deleteOrgChatForOrganization(pool, orgId);
    try {
      await pool.query(`DELETE FROM user_sessions WHERE user_id = ?`, [orgId]);
    } catch (e) {
      if (e.code !== 'ER_NO_SUCH_TABLE') throw e;
    }
    try {
      await pool.query(`DELETE FROM organization_messages WHERE organization_id = ?`, [orgId]);
    } catch (e) {
      if (e.code !== 'ER_NO_SUCH_TABLE') throw e;
    }
    await pool.query(`DELETE FROM organizations WHERE id = ?`, [orgId]);
    deletedOrgs += 1;
  }

  return { deletedRequests, deletedOrgs };
}

/**
 * Сгенерировать новый набор тестовых заявок (предварительно чистит старые).
 */
async function seedArchiveTestMode(pool, uploadRoot = DEFAULT_UPLOAD_ROOT) {
  await cleanupArchiveTestMode(pool, uploadRoot);

  const passwordHash = await bcrypt.hash(`archive-test-${crypto.randomBytes(4).toString('hex')}`, 8);
  const org1 = await ensureTestOrg(pool, 1, passwordHash);
  const org2 = await ensureTestOrg(pool, 2, passwordHash);
  const org3 = await ensureTestOrg(pool, 3, passwordHash);

  const old = daysAgo(60);
  const mid = daysAgo(45);
  const recent = daysAgo(3);
  const veryRecent = daysAgo(1);

  const created = [];

  // 1. closed + старые + файлы — попадает при всех фильтрах
  {
    const id = await insertTestRequest(pool, {
      organizationId: org1,
      status: 'closed',
      createdAt: old,
      updatedAt: mid,
      vinSuffix: 1,
      ownerLabel: 'eligible-base',
      external1cId: `ARCHIVE_TEST_EXT_1`,
    });
    await addRequestFile(pool, uploadRoot, id, 'passport_front', 'eligible', mid);
    await addRequestFile(pool, uploadRoot, id, 'invoice', 'eligible', mid);
    await addRequestChat(pool, id, 'старый чат', daysAgo(40), true);
    created.push({ id, tag: 'eligible-base', organizationId: org1 });
  }

  // 2. closed + свежий чат — отсекается checkChatMessages
  {
    const id = await insertTestRequest(pool, {
      organizationId: org1,
      status: 'closed',
      createdAt: old,
      updatedAt: mid,
      vinSuffix: 2,
      ownerLabel: 'recent-chat',
      external1cId: `ARCHIVE_TEST_EXT_2`,
    });
    await addRequestFile(pool, uploadRoot, id, 'passport_front', 'chat', mid);
    await addRequestChat(pool, id, 'свежий чат', recent, false);
    created.push({ id, tag: 'recent-chat', organizationId: org1 });
  }

  // 3. closed + свежий файл — отсекается checkFiles
  {
    const id = await insertTestRequest(pool, {
      organizationId: org1,
      status: 'closed',
      createdAt: old,
      updatedAt: mid,
      vinSuffix: 3,
      ownerLabel: 'recent-file',
      external1cId: `ARCHIVE_TEST_EXT_3`,
    });
    await addRequestFile(pool, uploadRoot, id, 'contract', 'recent', recent);
    created.push({ id, tag: 'recent-file', organizationId: org1 });
  }

  // 4. closed + свежий updated_at — отсекается checkRequestUpdated
  {
    const id = await insertTestRequest(pool, {
      organizationId: org1,
      status: 'closed',
      createdAt: old,
      updatedAt: veryRecent,
      vinSuffix: 4,
      ownerLabel: 'recent-updated',
      external1cId: `ARCHIVE_TEST_EXT_4`,
    });
    await addRequestFile(pool, uploadRoot, id, 'snils', 'updated', mid);
    created.push({ id, tag: 'recent-updated', organizationId: org1 });
  }

  // 5. closed + свежий вход org — отсекается checkOrgSessions (отдельная org)
  {
    const id = await insertTestRequest(pool, {
      organizationId: org2,
      status: 'closed',
      createdAt: old,
      updatedAt: mid,
      vinSuffix: 5,
      ownerLabel: 'recent-session',
      external1cId: `ARCHIVE_TEST_EXT_5`,
    });
    await addRequestFile(pool, uploadRoot, id, 'inn', 'session', mid);
    await addSession(pool, org2, recent);
    created.push({ id, tag: 'recent-session', organizationId: org2 });
  }

  // 6. не closed — отсекается requireClosed
  {
    const id = await insertTestRequest(pool, {
      organizationId: org1,
      status: 'in_progress',
      createdAt: old,
      updatedAt: mid,
      vinSuffix: 6,
      ownerLabel: 'not-closed',
      external1cId: `ARCHIVE_TEST_EXT_6`,
    });
    await addRequestFile(pool, uploadRoot, id, 'passport_registration', 'open', mid);
    created.push({ id, tag: 'not-closed', organizationId: org1 });
  }

  // 7. closed, создана недавно — отсекается archiveBefore (по умолчанию ~30 дн. назад)
  {
    const id = await insertTestRequest(pool, {
      organizationId: org3,
      status: 'closed',
      createdAt: daysAgo(10),
      updatedAt: daysAgo(10),
      vinSuffix: 7,
      ownerLabel: 'created-recent',
      external1cId: `ARCHIVE_TEST_EXT_7`,
    });
    await addRequestFile(pool, uploadRoot, id, 'car_front_photo', 'newish', daysAgo(10));
    created.push({ id, tag: 'created-recent', organizationId: org3 });
  }

  // 8. ещё одна eligible с файлами для org3 + общий чат
  {
    const id = await insertTestRequest(pool, {
      organizationId: org3,
      status: 'closed',
      createdAt: old,
      updatedAt: mid,
      vinSuffix: 8,
      ownerLabel: 'eligible-org3',
      external1cId: `ARCHIVE_TEST_EXT_8`,
    });
    await addRequestFile(pool, uploadRoot, id, 'payment_check', 'eligible3', mid);
    await addRequestChat(pool, id, 'старый чат org3', daysAgo(50), true);
    created.push({ id, tag: 'eligible-org3', organizationId: org3 });
  }

  // 9. closed без файлов — eligible, маленький размер
  {
    const id = await insertTestRequest(pool, {
      organizationId: org3,
      status: 'closed',
      createdAt: old,
      updatedAt: mid,
      vinSuffix: 9,
      ownerLabel: 'no-files',
      external1cId: `ARCHIVE_TEST_EXT_9`,
    });
    created.push({ id, tag: 'no-files', organizationId: org3 });
  }

  await addOrgChat(pool, org1, 'общий чат org1 (старый)', daysAgo(50), true);
  await addOrgChat(pool, org3, 'общий чат org3 (старый)', daysAgo(55), false);

  return {
    ok: true,
    organizations: [
      { id: org1, login: `${TEST_ORG_LOGIN_PREFIX}1` },
      { id: org2, login: `${TEST_ORG_LOGIN_PREFIX}2` },
      { id: org3, login: `${TEST_ORG_LOGIN_PREFIX}3` },
    ],
    requests: created,
    count: created.length,
  };
}

module.exports = {
  TEST_ORG_LOGIN_PREFIX,
  TEST_ORG_ID1C_PREFIX,
  seedArchiveTestMode,
  cleanupArchiveTestMode,
};
