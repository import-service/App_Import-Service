const fs = require('fs/promises');
const path = require('path');
const { randomUUID } = require('crypto');
const { verifyIntegrationBearer } = require('../util/integrationAuth');
const { timingSafeEqualString } = require('../util/security');
const {
  CUSTOMS_REQUEST_SELECT,
  toCustomsRequestDto,
  moneyAmountToJsonPayload,
  MONEY_AMOUNT_SCHEMA,
  resolveLegalInnFromBody,
} = require('../util/customsRequestDto');
const { isDemoApplicantName } = require('../services/demoFlow');
const {
  DEAL_TYPES,
  normalizeDocType,
  normalizeStatusSubType,
  suggestedStatusForSubType,
  isKnownStatusSubType,
} = require('../constants/customsCatalog');
const { notifyStateChangedFrom1C } = require('../services/pushNotifications');
const {
  storageKeyForRequest,
  upsertRequestFile,
} = require('../util/requestFileStorage');
const { recordUploadAndMaybeSync } = require('../services/uploadBatchSync');

const REQUEST_STATUSES = [
  'new',
  'on_review',
  'in_progress',
  'in_transit',
  'delivered',
  'closed',
  'cancelled',
];
const UPLOAD_ROOT = path.join(process.cwd(), 'uploads', 'customs-requests');

const STATE_FORBIDDEN_KEYS = [
  'files',
  'unsigned',
  'signingFiles',
  'financeItems',
  'vehiclePhotoUrls',
  'deliveredDocuments',
  'statusSinceDateLabel',
];

const STATE_BODY_SCHEMA = {
  type: 'object',
  required: ['external1cId'],
  properties: {
    external1cId: { type: 'string', minLength: 1, maxLength: 255 },
    status: { type: 'string', enum: REQUEST_STATUSES },
    statusSubType: { type: 'string', maxLength: 128 },
    statusSubTypeDateTime: { type: 'string', maxLength: 64 },
    dealType: { type: 'string', enum: DEAL_TYPES, maxLength: 32 },
    ownerFullName: { type: 'string', maxLength: 255 },
    carMake: { type: 'string', maxLength: 255 },
    carModel: { type: 'string', maxLength: 255 },
    vin: { type: 'string', maxLength: 32 },
    engineSpec: { type: 'string', maxLength: 255 },
    engineVolume: { type: 'string', maxLength: 128 },
    advancePayment: MONEY_AMOUNT_SCHEMA,
    actualPayment: MONEY_AMOUNT_SCHEMA,
    managerExternal1cId: { type: 'string', maxLength: 255 },
    managerFullName: { type: 'string', maxLength: 255 },
  },
};

function multipartFieldValue(fields, name) {
  const f = fields?.[name];
  if (!f) return '';
  return String(f.value ?? '').trim();
}

function authenticateUserOrIntegrationBearer(fastify) {
  return async function authenticateUserOrIntegration(request, reply) {
    const header = request.headers.authorization || '';
    const match = /^Bearer\s+(.+)$/i.exec(header);
    const token = match ? match[1].trim() : '';
    const expected = String(fastify.config.integrationBearerToken || '').trim();
    if (expected && token && timingSafeEqualString(token, expected)) {
      return;
    }
    await fastify.authenticate(request, reply);
  };
}

function normalize(v) {
  return String(v ?? '').trim();
}

function toFlag(v) {
  return v ? 1 : 0;
}

function sanitizeFileName(fileName) {
  return normalize(fileName).replace(/[^a-zA-Z0-9._-]/g, '_') || 'file.bin';
}

function deriveStoredNameFromFileUrl(fileUrl) {
  const raw = normalize(fileUrl);
  if (!raw) {
    return `${randomUUID()}.bin`;
  }
  try {
    if (/^https?:\/\//i.test(raw)) {
      const u = new URL(raw);
      const base = path.basename(u.pathname || '');
      const safe = sanitizeFileName(base);
      if (safe && safe !== 'file.bin') {
        return safe;
      }
      return `${randomUUID()}.bin`;
    }
  } catch {
    // ignore URL parse failures, fallback below
  }
  const base = path.basename(raw);
  const safe = sanitizeFileName(base);
  if (safe && safe !== 'file.bin') {
    return safe;
  }
  return `${randomUUID()}.bin`;
}

function validateCreateBody(body) {
  const requiredFields = [
    'legalEntityName',
    'legalEmail',
    'legalPhone',
    'individualFullName',
    'individualPhone',
    'individualSnils',
    'carMake',
    'carModel',
    'vin',
  ];

  for (const field of requiredFields) {
    if (!normalize(body[field])) {
      throw new Error(`VALIDATION_ERROR: обязательное поле ${field} не заполнено`);
    }
  }

  resolveLegalInnFromBody(body, { required: true });
}

function rejectDeprecatedStateFields(body, reply) {
  for (const key of STATE_FORBIDDEN_KEYS) {
    if (body[key] !== undefined) {
      reply.code(400).send({
        error: 'VALIDATION_ERROR',
        message: `Поле ${key} не поддерживается в state`,
      });
      return true;
    }
  }
  return false;
}

async function ensureUploadDir() {
  await fs.mkdir(UPLOAD_ROOT, { recursive: true });
}

async function fetchRequestById(pool, id) {
  const [rows] = await pool.query(
    `SELECT ${CUSTOMS_REQUEST_SELECT}
     FROM customs_requests
     WHERE id = ? AND deleted_at IS NULL
     LIMIT 1`,
    [id],
  );

  if (!rows.length) {
    return null;
  }

  const row = rows[0];
  const [fileRows] = await pool.query(
    `SELECT id, doc_type, original_name, stored_name, mime_type, file_size_bytes, file_url, created_at, updated_at
     FROM customs_request_files
     WHERE request_id = ? AND deleted_at IS NULL
     ORDER BY id ASC`,
    [id],
  );

  return { row, files: fileRows };
}

async function fetchRequestByExternal1cId(pool, external1cId) {
  const [rows] = await pool.query(
    `SELECT ${CUSTOMS_REQUEST_SELECT}
     FROM customs_requests
     WHERE external_1c_id = ? AND deleted_at IS NULL
     LIMIT 1`,
    [external1cId],
  );
  if (!rows.length) return null;
  const row = rows[0];
  const [fileRows] = await pool.query(
    `SELECT id, doc_type, original_name, stored_name, mime_type, file_size_bytes, file_url, created_at, updated_at
     FROM customs_request_files
     WHERE request_id = ? AND deleted_at IS NULL
     ORDER BY id ASC`,
    [row.id],
  );
  return { row, files: fileRows };
}

module.exports = async function customsRequestsRoutes(fastify) {
  await ensureUploadDir();

  const listDtoOptions = { includeFiles: false };
  const detailDtoOptions = { includeFiles: true };

  fastify.post(
    '/customs-requests/upload',
    { onRequest: [authenticateUserOrIntegrationBearer(fastify)] },
    async (request, reply) => {
      const mp = await request.file();
      if (!mp) {
        return reply.code(400).send({ error: 'VALIDATION_ERROR', message: 'Нужен multipart: file' });
      }

      const fields = mp.fields || {};
      const docType = normalizeDocType(multipartFieldValue(fields, 'docType'));
      const uploadIndex = Number(multipartFieldValue(fields, 'uploadIndex'));
      const uploadTotal = Number(multipartFieldValue(fields, 'uploadTotal'));
      const external1cId = multipartFieldValue(fields, 'external1cId');
      const requestIdRaw = multipartFieldValue(fields, 'requestId');

      if (!docType) {
        return reply.code(400).send({ error: 'VALIDATION_ERROR', message: 'docType обязателен' });
      }

      const chunks = [];
      for await (const chunk of mp.file) {
        chunks.push(chunk);
      }
      const buf = Buffer.concat(chunks);
      if (!buf.length) {
        return reply.code(400).send({ error: 'VALIDATION_ERROR', message: 'Пустой файл' });
      }

      let row = null;
      let source = 'user';
      if (external1cId) {
        const data = await fetchRequestByExternal1cId(fastify.pool, external1cId);
        if (!data) {
          return reply.code(404).send({ error: 'NOT_FOUND', message: 'Заявка не найдена' });
        }
        row = data.row;
        source = 'integration';
      } else {
        const requestId = Number(requestIdRaw);
        if (!Number.isFinite(requestId) || requestId <= 0) {
          return reply.code(400).send({
            error: 'VALIDATION_ERROR',
            message: 'Нужен external1cId (1С) или requestId (МП)',
          });
        }
        const data = await fetchRequestById(fastify.pool, requestId);
        if (!data) {
          return reply.code(404).send({ error: 'NOT_FOUND' });
        }
        row = data.row;
      }

      const storageKey = storageKeyForRequest(row);
      const saved = await upsertRequestFile(
        fastify.pool,
        UPLOAD_ROOT,
        row.id,
        storageKey,
        docType,
        buf,
        normalize(mp.mimetype) || 'application/octet-stream',
      );

      let batchInfo = { batchComplete: false };
      try {
        batchInfo = await recordUploadAndMaybeSync(fastify, {
          requestId: row.id,
          docType,
          uploadIndex,
          uploadTotal,
          source,
          requestLike: request,
        });
      } catch (e) {
        return reply.code(400).send({
          error: 'VALIDATION_ERROR',
          message: e.message || 'Ошибка батча upload',
        });
      }

      return reply.code(201).send({
        ok: true,
        batchComplete: batchInfo.batchComplete,
        file: {
          docType: saved.docType,
          mimeType: saved.mimeType,
          fileSizeBytes: saved.fileSizeBytes,
          fileUrl: saved.fileUrl,
          replaced: saved.replaced,
        },
      });
    },
  );

  fastify.post(
    '/customs-requests',
    {
      onRequest: [fastify.authenticate],
      schema: {
        body: {
          type: 'object',
          required: [
            'legalEntityName',
            'legalEmail',
            'legalPhone',
            'individualFullName',
            'individualPhone',
            'individualSnils',
            'carMake',
            'carModel',
            'vin',
          ],
          properties: {
            legalEntityName: { type: 'string', minLength: 1, maxLength: 255 },
            legalEmail: { type: 'string', format: 'email', maxLength: 255 },
            legalPhone: { type: 'string', minLength: 1, maxLength: 30 },
            legalInn: { type: 'string', minLength: 10, maxLength: 12 },
            inn: { type: 'string', minLength: 10, maxLength: 12 },
            individualFullName: { type: 'string', minLength: 1, maxLength: 255 },
            individualPhone: { type: 'string', minLength: 1, maxLength: 30 },
            individualSnils: { type: 'string', minLength: 1, maxLength: 32 },
            carMake: { type: 'string', minLength: 1, maxLength: 255 },
            carModel: { type: 'string', minLength: 1, maxLength: 255 },
            vin: { type: 'string', minLength: 1, maxLength: 32 },
            hasSunroof: { type: 'boolean' },
            hasAllWheelDrive: { type: 'boolean' },
            importedLast12Months: { type: 'boolean' },
            ownsOtherCars: { type: 'boolean' },
            commentText: { type: 'string', maxLength: 5000 },
            isTest: { type: 'boolean' },
          },
        },
      },
    },
    async (request, reply) => {
      try {
        validateCreateBody(request.body);
      } catch (e) {
        return reply.code(400).send({ error: 'VALIDATION_ERROR', message: e.message });
      }

      const legalInn = resolveLegalInnFromBody(request.body, { required: true });

      const conn = await fastify.pool.getConnection();
      try {
        await conn.beginTransaction();

        const [insertResult] = await conn.query(
          `INSERT INTO customs_requests
             (external_1c_id, manager_external_1c_id, legal_entity_name, legal_email, legal_phone, legal_inn,
              individual_full_name, individual_phone, individual_snils, car_make, car_model, vin,
              has_sunroof, has_all_wheel_drive, imported_last_12_months, owns_other_cars, comment_text, is_test, status)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
          [
            null,
            null,
            normalize(request.body.legalEntityName),
            normalize(request.body.legalEmail),
            normalize(request.body.legalPhone),
            legalInn,
            normalize(request.body.individualFullName),
            normalize(request.body.individualPhone),
            normalize(request.body.individualSnils),
            normalize(request.body.carMake),
            normalize(request.body.carModel),
            normalize(request.body.vin),
            toFlag(request.body.hasSunroof),
            toFlag(request.body.hasAllWheelDrive),
            toFlag(request.body.importedLast12Months),
            toFlag(request.body.ownsOtherCars),
            normalize(request.body.commentText) || null,
            toFlag(request.body.isTest) ||
              (fastify.config.demoFlow?.enabled &&
              isDemoApplicantName(request.body.individualFullName)
                ? 1
                : 0),
            'new',
          ],
        );

        const requestId = insertResult.insertId;

        await conn.commit();

        const created = await fetchRequestById(fastify.pool, requestId);
        return reply
          .code(201)
          .send(
            toCustomsRequestDto(fastify, request, created.row, created.files, detailDtoOptions),
          );
      } catch (e) {
        await conn.rollback();
        fastify.log.error(e);
        return reply.code(500).send({ error: 'INTERNAL_ERROR' });
      } finally {
        conn.release();
      }
    },
  );

  fastify.get(
    '/customs-requests',
    { onRequest: [fastify.authenticate] },
    async (request, reply) => {
      const limit = Math.min(Math.max(Number(request.query.limit) || 20, 1), 100);
      const offset = Math.max(Number(request.query.offset) || 0, 0);
      const status = normalize(request.query.status);
      const isTestQ = normalize(request.query.isTest).toLowerCase();
      const where = ['deleted_at IS NULL'];
      const args = [];
      if (status) {
        where.push('status = ?');
        args.push(status);
      }
      if (isTestQ === 'true' || isTestQ === '1') {
        where.push('is_test = 1');
      } else if (isTestQ === 'false' || isTestQ === '0') {
        where.push('is_test = 0');
      }
      args.push(limit, offset);

      const [rows] = await fastify.pool.query(
        `SELECT ${CUSTOMS_REQUEST_SELECT}
         FROM customs_requests
         WHERE ${where.join(' AND ')}
         ORDER BY id DESC
         LIMIT ? OFFSET ?`,
        args,
      );

      const items = rows.map((row) =>
        toCustomsRequestDto(fastify, request, row, [], listDtoOptions),
      );
      return reply.send({ items, limit, offset });
    },
  );

  fastify.get(
    '/customs-requests/:id',
    { onRequest: [fastify.authenticate] },
    async (request, reply) => {
      const id = Number(request.params.id);
      if (!Number.isFinite(id) || id <= 0) {
        return reply.code(400).send({ error: 'VALIDATION_ERROR', message: 'Некорректный id' });
      }

      const data = await fetchRequestById(fastify.pool, id);
      if (!data) {
        return reply.code(404).send({ error: 'NOT_FOUND' });
      }

      return reply.send(
        toCustomsRequestDto(fastify, request, data.row, data.files, detailDtoOptions),
      );
    },
  );

  fastify.patch(
    '/customs-requests/:id',
    {
      onRequest: [fastify.authenticate],
      schema: {
        body: {
          type: 'object',
          properties: {
            legalEntityName: { type: 'string', minLength: 1, maxLength: 255 },
            legalEmail: { type: 'string', format: 'email', maxLength: 255 },
            legalPhone: { type: 'string', minLength: 1, maxLength: 30 },
            legalInn: { type: 'string', minLength: 10, maxLength: 12 },
            inn: { type: 'string', minLength: 10, maxLength: 12 },
            individualFullName: { type: 'string', minLength: 1, maxLength: 255 },
            individualPhone: { type: 'string', minLength: 1, maxLength: 30 },
            individualSnils: { type: 'string', minLength: 1, maxLength: 32 },
            carMake: { type: 'string', minLength: 1, maxLength: 255 },
            carModel: { type: 'string', minLength: 1, maxLength: 255 },
            vin: { type: 'string', minLength: 1, maxLength: 32 },
            hasSunroof: { type: 'boolean' },
            hasAllWheelDrive: { type: 'boolean' },
            importedLast12Months: { type: 'boolean' },
            ownsOtherCars: { type: 'boolean' },
            commentText: { type: 'string', maxLength: 5000 },
          },
          minProperties: 1,
        },
      },
    },
    async (request, reply) => {
      const id = Number(request.params.id);
      if (!Number.isFinite(id) || id <= 0) {
        return reply.code(400).send({ error: 'VALIDATION_ERROR', message: 'Некорректный id' });
      }

      let legalInnPatch;
      try {
        legalInnPatch = resolveLegalInnFromBody(request.body, { required: false });
      } catch (e) {
        return reply.code(400).send({ error: 'VALIDATION_ERROR', message: e.message });
      }

      const fields = [];
      const values = [];

      const map = [
        ['legalEntityName', 'legal_entity_name'],
        ['legalEmail', 'legal_email'],
        ['legalPhone', 'legal_phone'],
        ['individualFullName', 'individual_full_name'],
        ['individualPhone', 'individual_phone'],
        ['individualSnils', 'individual_snils'],
        ['carMake', 'car_make'],
        ['carModel', 'car_model'],
        ['vin', 'vin'],
        ['commentText', 'comment_text'],
      ];

      for (const [bodyKey, dbKey] of map) {
        if (request.body[bodyKey] !== undefined) {
          fields.push(`${dbKey} = ?`);
          values.push(normalize(request.body[bodyKey]) || null);
        }
      }

      if (legalInnPatch !== undefined) {
        fields.push('legal_inn = ?');
        values.push(legalInnPatch);
      }

      if (request.body.hasSunroof !== undefined) {
        fields.push('has_sunroof = ?');
        values.push(toFlag(request.body.hasSunroof));
      }
      if (request.body.hasAllWheelDrive !== undefined) {
        fields.push('has_all_wheel_drive = ?');
        values.push(toFlag(request.body.hasAllWheelDrive));
      }
      if (request.body.importedLast12Months !== undefined) {
        fields.push('imported_last_12_months = ?');
        values.push(toFlag(request.body.importedLast12Months));
      }
      if (request.body.ownsOtherCars !== undefined) {
        fields.push('owns_other_cars = ?');
        values.push(toFlag(request.body.ownsOtherCars));
      }

      if (!fields.length) {
        return reply.code(400).send({ error: 'VALIDATION_ERROR', message: 'Нет полей для обновления' });
      }

      values.push(id);
      const [result] = await fastify.pool.query(
        `UPDATE customs_requests
         SET ${fields.join(', ')}
         WHERE id = ? AND deleted_at IS NULL`,
        values,
      );

      if (!result.affectedRows) {
        return reply.code(404).send({ error: 'NOT_FOUND' });
      }

      const data = await fetchRequestById(fastify.pool, id);
      return reply.send(
        toCustomsRequestDto(fastify, request, data.row, data.files, detailDtoOptions),
      );
    },
  );

  fastify.post(
    '/integration/customs-requests/state',
    {
      preHandler: verifyIntegrationBearer,
      schema: { body: STATE_BODY_SCHEMA },
    },
    async (request, reply) => {
      if (rejectDeprecatedStateFields(request.body, reply)) {
        return;
      }

      const ext = normalize(request.body.external1cId);
      if (!ext) {
        return reply.code(400).send({ error: 'VALIDATION_ERROR', message: 'external1cId пустой' });
      }

      const data = await fetchRequestByExternal1cId(fastify.pool, ext);
      if (!data) {
        return reply.code(404).send({ error: 'NOT_FOUND', message: 'Заявка с таким external1cId не найдена' });
      }

      const b = request.body;
      const fields = [];
      const values = [];

      if (b.status !== undefined) {
        fields.push('status = ?');
        values.push(b.status);
      }
      if (b.ownerFullName !== undefined) {
        const v = normalize(b.ownerFullName);
        fields.push('owner_full_name = ?');
        values.push(v || null);
      }
      if (b.carMake !== undefined) {
        const v = normalize(b.carMake);
        if (v) {
          fields.push('car_make = ?');
          values.push(v);
        }
      }
      if (b.carModel !== undefined) {
        const v = normalize(b.carModel);
        if (v) {
          fields.push('car_model = ?');
          values.push(v);
        }
      }
      if (b.vin !== undefined) {
        const v = normalize(b.vin);
        if (v) {
          fields.push('vin = ?');
          values.push(v);
        }
      }
      if (b.engineSpec !== undefined) {
        fields.push('engine_spec = ?');
        values.push(normalize(b.engineSpec) || null);
      }
      if (b.engineVolume !== undefined) {
        fields.push('engine_volume = ?');
        values.push(normalize(b.engineVolume) || null);
      }
      if (b.statusSubType !== undefined) {
        const sub = normalizeStatusSubType(b.statusSubType);
        if (sub && !isKnownStatusSubType(sub)) {
          return reply.code(400).send({
            error: 'VALIDATION_ERROR',
            message: `Неизвестный statusSubType: ${sub}`,
          });
        }
        fields.push('status_sub_type = ?');
        values.push(sub || null);
        if (b.status === undefined && sub) {
          const suggested = suggestedStatusForSubType(sub);
          if (suggested) {
            fields.push('status = ?');
            values.push(suggested);
          }
        }
      }
      if (b.statusSubTypeDateTime !== undefined) {
        const dt = normalize(b.statusSubTypeDateTime);
        fields.push('status_sub_type_datetime = ?');
        values.push(dt || null);
      }
      if (b.dealType !== undefined) {
        fields.push('deal_type = ?');
        values.push(normalize(b.dealType) || null);
      }
      if (b.advancePayment !== undefined) {
        fields.push('advance_payment_json = ?');
        values.push(moneyAmountToJsonPayload(b.advancePayment));
      }
      if (b.actualPayment !== undefined) {
        fields.push('actual_payment_json = ?');
        values.push(moneyAmountToJsonPayload(b.actualPayment));
      }
      if (b.managerExternal1cId !== undefined) {
        const managerExternal1cId = normalize(b.managerExternal1cId);
        fields.push('manager_external_1c_id = ?');
        values.push(managerExternal1cId || null);
        if (
          b.status === undefined &&
          managerExternal1cId &&
          (data.row.status === 'new' || data.row.status === 'on_review')
        ) {
          fields.push('status = ?');
          values.push('in_progress');
        }
      }
      if (b.managerFullName !== undefined) {
        fields.push('manager_full_name = ?');
        values.push(normalize(b.managerFullName) || null);
      }

      const id = data.row.id;

      if (!fields.length) {
        return reply.code(400).send({ error: 'VALIDATION_ERROR', message: 'Нет полей для обновления' });
      }

      if (fields.length) {
        values.push(id);
        const [result] = await fastify.pool.query(
          `UPDATE customs_requests SET ${fields.join(', ')} WHERE id = ? AND deleted_at IS NULL`,
          values,
        );
        if (!result.affectedRows) {
          return reply.code(404).send({ error: 'NOT_FOUND' });
        }
      }

      const updated = await fetchRequestById(fastify.pool, id);
      notifyStateChangedFrom1C(fastify, {
        requestId: id,
        external1cId: updated.row.external_1c_id,
        previousStatus: data.row.status,
        previousStatusSubType: data.row.status_sub_type,
        status: updated.row.status,
        statusSubType: updated.row.status_sub_type,
      }).catch((e) => {
        fastify.log.warn({ requestId: id, err: e.message }, 'push notify state failed');
      });
      return reply.send({
        ok: true,
        item: toCustomsRequestDto(fastify, request, updated.row, updated.files, detailDtoOptions),
      });
    },
  );

  fastify.post(
    '/integration/customs-requests/purge-test',
    { preHandler: verifyIntegrationBearer },
    async (request, reply) => {
      const [result] = await fastify.pool.query('DELETE FROM customs_requests WHERE is_test = 1');
      const n = result.affectedRows != null ? Number(result.affectedRows) : 0;
      return reply.send({ ok: true, deletedRows: n });
    },
  );

  fastify.post(
    '/integration/customs-requests/demo-reset-latest',
    { preHandler: verifyIntegrationBearer },
    async (_request, reply) => {
      const [rows] = await fastify.pool.query(
        `SELECT id
         FROM customs_requests
         WHERE individual_full_name = 'Тестов Тест Тестович'
           AND deleted_at IS NULL
         ORDER BY id DESC
         LIMIT 1`,
      );
      if (!rows.length) {
        return reply.send({ ok: true, deleted: false, reason: 'NO_ACTIVE_DEMO_REQUEST' });
      }
      const id = Number(rows[0].id);
      await fastify.pool.query(
        `UPDATE customs_requests
         SET deleted_at = CURRENT_TIMESTAMP(3), updated_at = CURRENT_TIMESTAMP(3)
         WHERE id = ? AND deleted_at IS NULL`,
        [id],
      );
      return reply.send({ ok: true, deleted: true, requestId: id });
    },
  );

  fastify.delete(
    '/customs-requests/:id',
    { onRequest: [fastify.authenticate] },
    async (request, reply) => {
      const id = Number(request.params.id);
      if (!Number.isFinite(id) || id <= 0) {
        return reply.code(400).send({ error: 'VALIDATION_ERROR', message: 'Некорректный id' });
      }

      const [result] = await fastify.pool.query(
        `UPDATE customs_requests
         SET deleted_at = CURRENT_TIMESTAMP(3)
         WHERE id = ? AND deleted_at IS NULL`,
        [id],
      );
      if (!result.affectedRows) {
        return reply.code(404).send({ error: 'NOT_FOUND' });
      }
      return reply.send({ ok: true });
    },
  );

  fastify.post('/customs-requests/:id/files', { onRequest: [fastify.authenticate] }, async (_request, reply) =>
    reply.code(410).send({
      error: 'GONE',
      message:
        'Устарело. Используйте POST /api/customs-requests/upload с requestId, docType, file, uploadIndex, uploadTotal.',
    }),
  );

  fastify.delete(
    '/customs-requests/:id/files/:fileId',
    { onRequest: [fastify.authenticate] },
    async (request, reply) => {
      const id = Number(request.params.id);
      const fileId = Number(request.params.fileId);
      if (!Number.isFinite(id) || id <= 0 || !Number.isFinite(fileId) || fileId <= 0) {
        return reply.code(400).send({ error: 'VALIDATION_ERROR', message: 'Некорректный id' });
      }

      const [result] = await fastify.pool.query(
        `UPDATE customs_request_files
         SET deleted_at = CURRENT_TIMESTAMP(3)
         WHERE id = ? AND request_id = ? AND deleted_at IS NULL`,
        [fileId, id],
      );
      if (!result.affectedRows) {
        return reply.code(404).send({ error: 'NOT_FOUND' });
      }
      return reply.send({ ok: true });
    },
  );

  fastify.get(
    '/customs-requests/files/:storedName',
    { onRequest: [authenticateUserOrIntegrationBearer(fastify)] },
    async (request, reply) => {
      const storedName = sanitizeFileName(request.params.storedName);
      const filePath = path.join(UPLOAD_ROOT, storedName);

      try {
        const [rows] = await fastify.pool.query(
          `SELECT mime_type
           FROM customs_request_files
           WHERE stored_name = ? AND deleted_at IS NULL
           LIMIT 1`,
          [storedName],
        );
        if (!rows.length) {
          return reply.code(404).send({ error: 'NOT_FOUND' });
        }

        const stat = await fs.stat(filePath);
        if (!stat.isFile()) {
          return reply.code(404).send({ error: 'NOT_FOUND' });
        }

        const mimeType = rows[0].mime_type || 'application/octet-stream';
        return reply.type(mimeType).send(await fs.readFile(filePath));
      } catch (e) {
        if (e.code === 'ENOENT') {
          return reply.code(404).send({ error: 'NOT_FOUND' });
        }
        fastify.log.error(e);
        return reply.code(500).send({ error: 'INTERNAL_ERROR' });
      }
    },
  );
};
