const fs = require('fs/promises');
const path = require('path');
const { randomUUID } = require('crypto');
const { verifyIntegrationBearer } = require('../util/integrationAuth');
const { timingSafeEqualString } = require('../util/security');
const {
  CUSTOMS_REQUEST_SELECT,
  toCustomsRequestDto,
  financeItemsToJsonPayload,
  stringArrayToJsonPayload,
  deliveredDocsToJsonPayload,
} = require('../util/customsRequestDto');

const REQUEST_STATUSES = ['new', 'in_progress', 'in_transit', 'delivered'];
const REQUIRED_DOCUMENT_TYPES = [
  'passport_front',
  'passport_registration',
  'inn',
  'snils',
  'contract',
  'payment_check',
  'title_doc',
  'car_front_photo',
  'car_back_photo',
];

const UPLOAD_ROOT = path.join(process.cwd(), 'uploads', 'customs-requests');

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

function looksLikeHttpUrl(v) {
  return /^https?:\/\//i.test(String(v || '').trim());
}

function looksLikeApiFileUrl(v) {
  return /^\/api\/customs-requests\/files\/[a-zA-Z0-9._-]+$/i.test(String(v || '').trim());
}

function validateFileItem(file) {
  const hasFileUrl = normalize(file.fileUrl).length > 0;
  if (!hasFileUrl) {
    throw new Error(
      `VALIDATION_ERROR: для файла ${normalize(file.fileName) || normalize(file.docType)} нужен fileUrl`,
    );
  }
  if (!(looksLikeHttpUrl(file.fileUrl) || looksLikeApiFileUrl(file.fileUrl))) {
    throw new Error(`VALIDATION_ERROR: некорректный fileUrl для ${normalize(file.docType)}`);
  }
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

  if (!Array.isArray(body.files) || body.files.length === 0) {
    throw new Error('VALIDATION_ERROR: files должен быть непустым массивом');
  }

  for (const item of body.files) {
    validateFileItem(item);
  }

  const providedTypes = new Set(body.files.map((item) => normalize(item.docType)));
  for (const requiredType of REQUIRED_DOCUMENT_TYPES) {
    if (!providedTypes.has(requiredType)) {
      throw new Error(
        `VALIDATION_ERROR: обязательный файл ${requiredType} отсутствует в массиве files`,
      );
    }
  }
}

async function ensureUploadDir() {
  await fs.mkdir(UPLOAD_ROOT, { recursive: true });
}

async function prepareFileForDb(file) {
  const fileUrl = normalize(file.fileUrl);
  const storedName = deriveStoredNameFromFileUrl(fileUrl);
  return {
    originalName: sanitizeFileName(file.fileName || 'remote-file'),
    storedName,
    fileSizeBytes: 0,
    mimeType: normalize(file.mimeType) || 'application/octet-stream',
    fileUrl,
  };
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

  const listDtoOptions = { includeFiles: false, mergeVehicleFiles: false };
  const detailDtoOptions = { includeFiles: true, mergeVehicleFiles: true };

  fastify.post(
    '/customs-requests/upload',
    { onRequest: [fastify.authenticate] },
    async (request, reply) => {
      const mp = await request.file();
      if (!mp) {
        return reply.code(400).send({ error: 'VALIDATION_ERROR', message: 'Нужен multipart файл' });
      }

      const docType = normalize(mp.fields?.docType?.value || request.query.docType || 'uploaded_file');
      const originalName = sanitizeFileName(mp.filename || 'upload.bin');
      const ext = path.extname(originalName);
      const storedName = `${randomUUID()}${ext}`;
      const filePath = path.join(UPLOAD_ROOT, storedName);

      const chunks = [];
      for await (const chunk of mp.file) {
        chunks.push(chunk);
      }
      const buf = Buffer.concat(chunks);
      if (!buf.length) {
        return reply.code(400).send({ error: 'VALIDATION_ERROR', message: 'Пустой файл' });
      }
      await fs.writeFile(filePath, buf);

      const mimeType = normalize(mp.mimetype) || 'application/octet-stream';
      const fileUrl = `/api/customs-requests/files/${storedName}`;

      return reply.code(201).send({
        ok: true,
        file: {
          docType: docType || 'uploaded_file',
          fileName: originalName,
          mimeType,
          fileSizeBytes: buf.length,
          fileUrl,
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
            'files',
          ],
          properties: {
            legalEntityName: { type: 'string', minLength: 1, maxLength: 255 },
            legalEmail: { type: 'string', format: 'email', maxLength: 255 },
            legalPhone: { type: 'string', minLength: 1, maxLength: 30 },
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
            files: {
              type: 'array',
              minItems: 1,
              items: {
                type: 'object',
                required: ['docType', 'fileName'],
                properties: {
                  docType: { type: 'string', minLength: 1, maxLength: 64 },
                  fileName: { type: 'string', minLength: 1, maxLength: 255 },
                  mimeType: { type: 'string', minLength: 1, maxLength: 128 },
                  fileUrl: { type: 'string', minLength: 1, maxLength: 1024 },
                },
              },
            },
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

      const conn = await fastify.pool.getConnection();
      try {
        await conn.beginTransaction();

        const [insertResult] = await conn.query(
          `INSERT INTO customs_requests
             (external_1c_id, manager_external_1c_id, legal_entity_name, legal_email, legal_phone,
              individual_full_name, individual_phone, individual_snils, car_make, car_model, vin,
              has_sunroof, has_all_wheel_drive, imported_last_12_months, owns_other_cars, comment_text, is_test, status)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
          [
            null,
            null,
            normalize(request.body.legalEntityName),
            normalize(request.body.legalEmail),
            normalize(request.body.legalPhone),
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
            toFlag(request.body.isTest),
            'new',
          ],
        );

        const requestId = insertResult.insertId;
        for (const file of request.body.files) {
          const saved = await prepareFileForDb(file);
          await conn.query(
            `INSERT INTO customs_request_files
               (request_id, doc_type, original_name, stored_name, mime_type, file_size_bytes, file_url)
             VALUES (?, ?, ?, ?, ?, ?, ?)`,
            [
              requestId,
              normalize(file.docType),
              saved.originalName,
              saved.storedName,
              saved.mimeType,
              saved.fileSizeBytes,
              saved.fileUrl,
            ],
          );
        }

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
      schema: {
        body: {
          type: 'object',
          required: ['external1cId'],
          properties: {
            external1cId: { type: 'string', minLength: 1, maxLength: 255 },
            status: { type: 'string', enum: REQUEST_STATUSES },
            ownerFullName: { type: 'string', maxLength: 255 },
            carMake: { type: 'string', maxLength: 255 },
            carModel: { type: 'string', maxLength: 255 },
            vin: { type: 'string', maxLength: 32 },
            engineSpec: { type: 'string', maxLength: 255 },
            engineVolume: { type: 'string', maxLength: 128 },
            statusSinceDateLabel: { type: 'string', maxLength: 255 },
            statusSubType: { type: 'string', maxLength: 128 },
            financeItems: { type: 'array' },
            vehiclePhotoUrls: { type: 'array' },
            deliveredDocuments: { type: 'array' },
          },
        },
      },
    },
    async (request, reply) => {
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
      if (b.statusSinceDateLabel !== undefined) {
        fields.push('status_since_date_label = ?');
        values.push(normalize(b.statusSinceDateLabel) || null);
      }
      if (b.statusSubType !== undefined) {
        fields.push('status_sub_type = ?');
        values.push(normalize(b.statusSubType) || null);
      }
      if (b.financeItems !== undefined) {
        fields.push('finance_items_json = ?');
        values.push(financeItemsToJsonPayload(b.financeItems));
      }
      if (b.vehiclePhotoUrls !== undefined) {
        fields.push('vehicle_photo_urls_json = ?');
        values.push(stringArrayToJsonPayload(b.vehiclePhotoUrls));
      }
      if (b.deliveredDocuments !== undefined) {
        fields.push('delivered_documents_json = ?');
        values.push(deliveredDocsToJsonPayload(b.deliveredDocuments));
      }

      if (!fields.length) {
        return reply.code(400).send({ error: 'VALIDATION_ERROR', message: 'Нет полей для обновления' });
      }

      const id = data.row.id;
      values.push(id);
      const [result] = await fastify.pool.query(
        `UPDATE customs_requests SET ${fields.join(', ')} WHERE id = ? AND deleted_at IS NULL`,
        values,
      );
      if (!result.affectedRows) {
        return reply.code(404).send({ error: 'NOT_FOUND' });
      }

      const updated = await fetchRequestById(fastify.pool, id);
      return reply.send({
        ok: true,
        item: toCustomsRequestDto(fastify, request, updated.row, updated.files, detailDtoOptions),
      });
    },
  );

  fastify.post(
    '/integration/customs-requests/link-1c',
    {
      preHandler: verifyIntegrationBearer,
      schema: {
        body: {
          type: 'object',
          required: ['requestId', 'external1cId', 'managerExternal1cId'],
          properties: {
            requestId: { type: 'integer', minimum: 1 },
            external1cId: { type: 'string', minLength: 1, maxLength: 255 },
            managerExternal1cId: { type: 'string', minLength: 1, maxLength: 255 },
          },
        },
      },
    },
    async (request, reply) => {
      const requestId = Number(request.body.requestId);
      const external1cId = normalize(request.body.external1cId);
      const managerExternal1cId = normalize(request.body.managerExternal1cId);

      const [result] = await fastify.pool.query(
        `UPDATE customs_requests
         SET external_1c_id = ?, manager_external_1c_id = ?, status = 'in_progress'
         WHERE id = ? AND deleted_at IS NULL`,
        [external1cId, managerExternal1cId, requestId],
      );
      if (!result.affectedRows) {
        return reply.code(404).send({ error: 'NOT_FOUND', message: 'Заявка не найдена' });
      }

      const data = await fetchRequestById(fastify.pool, requestId);
      return reply.send({
        ok: true,
        item: toCustomsRequestDto(fastify, request, data.row, data.files, detailDtoOptions),
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

  fastify.post(
    '/customs-requests/:id/files',
    {
      onRequest: [fastify.authenticate],
      schema: {
        body: {
          type: 'object',
          required: ['files'],
          properties: {
            files: {
              type: 'array',
              minItems: 1,
              items: {
                type: 'object',
                required: ['docType', 'fileName'],
                properties: {
                  docType: { type: 'string', minLength: 1, maxLength: 64 },
                  fileName: { type: 'string', minLength: 1, maxLength: 255 },
                  mimeType: { type: 'string', minLength: 1, maxLength: 128 },
                  fileUrl: { type: 'string', minLength: 1, maxLength: 1024 },
                },
              },
            },
          },
        },
      },
    },
    async (request, reply) => {
      const id = Number(request.params.id);
      if (!Number.isFinite(id) || id <= 0) {
        return reply.code(400).send({ error: 'VALIDATION_ERROR', message: 'Некорректный id' });
      }

      const [requestRows] = await fastify.pool.query(
        'SELECT id FROM customs_requests WHERE id = ? AND deleted_at IS NULL LIMIT 1',
        [id],
      );
      if (!requestRows.length) {
        return reply.code(404).send({ error: 'NOT_FOUND' });
      }

      for (const file of request.body.files) {
        validateFileItem(file);
        const saved = await prepareFileForDb(file);
        await fastify.pool.query(
          `INSERT INTO customs_request_files
             (request_id, doc_type, original_name, stored_name, mime_type, file_size_bytes, file_url)
           VALUES (?, ?, ?, ?, ?, ?, ?)`,
          [
            id,
            normalize(file.docType),
            saved.originalName,
            saved.storedName,
            saved.mimeType,
            saved.fileSizeBytes,
            saved.fileUrl,
          ],
        );
      }

      const data = await fetchRequestById(fastify.pool, id);
      return reply.send(
        toCustomsRequestDto(fastify, request, data.row, data.files, detailDtoOptions),
      );
    },
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
